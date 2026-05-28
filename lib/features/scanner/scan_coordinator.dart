import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../config/app_config.dart';
import '../../core/connectivity/connectivity_service.dart';
import '../../core/logging/app_logger.dart';
import '../../core/qr/qr_validation_service.dart';
import '../../core/resilience/pending_operation_queue.dart';
import '../../domain/models/operation_models.dart';
import '../../domain/repositories/operations_repository.dart';

enum ScanState { idle, scanning, processing, cooldown, success, error, queued }

/// Apakah mode scanner otomatis (auto detect) atau manual
enum ScanMode { auto, manual }

class ScanCoordinator extends ChangeNotifier {
  ScanCoordinator(this._repo, this._connectivityService, this._qrValidationService);
  final OperationsRepository _repo;
  final ConnectivityService _connectivityService;
  final QrValidationService _qrValidationService;

  final Queue<DateTime> _recentScanWindow = Queue<DateTime>();
  // Cache per-code PER aksi agar tidak false-positive saat check-in lalu checkout
  final Map<String, Map<String, DateTime>> _recentCodes = {};
  final PendingOperationQueue _retryQueue = PendingOperationQueue();

  ScanState state = ScanState.idle;
  String feedback = 'Arahkan ke QR code';
  bool torchOn = false;

  /// Mode aktif: auto = sistem otomatis pilih check-in / check-out
  ScanMode scanMode = ScanMode.auto;

  /// Aksi manual (dipakai kalau scanMode == manual)
  ScanAction _manualAction = ScanAction.checkIn;
  ScanAction get action => _manualAction;

  /// Aksi yang dideteksi otomatis pada scan terakhir (untuk ditampilkan di UI)
  ScanAction? lastDetectedAction;

  bool get isBusy => state == ScanState.processing || state == ScanState.cooldown;
  int get pendingRetryCount => _retryQueue.length;

  void setScanMode(ScanMode mode) {
    scanMode = mode;
    notifyListeners();
  }

  void setAction(ScanAction next) {
    _manualAction = next;
    scanMode = ScanMode.manual;
    notifyListeners();
  }

  void toggleTorch() {
    torchOn = !torchOn;
    notifyListeners();
  }

  /// Reset state ke scanning setelah dialog ditutup oleh UI
  void resetAfterResult() {
    if (state == ScanState.success ||
        state == ScanState.error ||
        state == ScanState.queued) {
      state = ScanState.scanning;
      feedback = 'Siap scan berikutnya';
      notifyListeners();
    }
  }

  Future<void> onCodeDetected(String rawCode) async {
    final validation = _qrValidationService.validate(rawCode);
    if (!validation.isValid) {
      state = ScanState.error;
      feedback = validation.reason ?? 'QR tidak valid';
      AppLogger.warn('qr_validation_failed', context: {'reason': feedback});
      notifyListeners();
      return;
    }

    final now = DateTime.now();
    if (isBusy) return;
    if (_lastProcessAt != null &&
        now.difference(_lastProcessAt!).inMilliseconds < 900) return;

    // Duplicate check — per aksi, bukan global
    // Sehingga scan check-in lalu checkout tidak dianggap duplicate
    final codeCache = _recentCodes[rawCode];
    if (codeCache != null) {
      final actionKey = scanMode == ScanMode.auto ? 'auto' : _manualAction.name;
      final lastAt = codeCache[actionKey];
      if (lastAt != null && now.difference(lastAt).inSeconds < 3) {
        state = ScanState.error;
        feedback = 'Scan terlalu cepat, tunggu sebentar';
        notifyListeners();
        return;
      }
    }

    // Simpan ke cache dengan key aksi
    final actionKey = scanMode == ScanMode.auto ? 'auto' : _manualAction.name;
    _recentCodes.putIfAbsent(rawCode, () => {})[actionKey] = now;

    _recentScanWindow.add(now);
    while (_recentScanWindow.isNotEmpty &&
        now.difference(_recentScanWindow.first).inMinutes > 2) {
      _recentScanWindow.removeFirst();
    }

    state = ScanState.processing;
    feedback = 'Memproses...';
    notifyListeners();

    if (AppConfig.enableOfflineQueue && !await _connectivityService.isOnline()) {
      final offlineAction =
          scanMode == ScanMode.auto ? ScanAction.checkIn : _manualAction;
      _retryQueue.enqueue(PendingOperation(
        id: rawCode.hashCode.toString(),
        payload: {'rawCode': rawCode, 'action': offlineAction.name},
        createdAt: DateTime.now(),
      ));
      state = ScanState.queued;
      feedback = 'Offline - scan antri (${_retryQueue.length})';
      notifyListeners();
      return;
    }

    if (scanMode == ScanMode.auto) {
      await _processAuto(rawCode);
    } else {
      await _process(rawCode, _manualAction);
    }
  }

  /// Auto-detect: query status visitor dulu, lalu tentukan aksi yang tepat
  Future<void> _processAuto(String rawCode) async {
    try {
      final status = await _repo.getVisitorStatus(rawCode: rawCode);
      final detectedAction = _resolveAction(status);
      lastDetectedAction = detectedAction;
      notifyListeners();
      await _process(rawCode, detectedAction);
    } catch (e) {
      // Kalau gagal query status (misal QR karyawan), fallback ke checkIn
      await _process(rawCode, ScanAction.checkIn);
    }
  }

  /// Tentukan aksi berdasarkan status visitor dari backend
  ScanAction _resolveAction(String status) {
    switch (status) {
      case 'Registered':
      case 'Awaiting Approval':
      case 'Approved':
        return ScanAction.checkIn;
      case 'Completed':
        return ScanAction.checkOut;
      case 'Checked Out':
        return ScanAction.checkOut; // akan gagal di backend, pesan error akan jelas
      default:
        return ScanAction.checkIn;
    }
  }

  DateTime? _lastProcessAt;

  Future<void> retryPending() async {
    if (!await _connectivityService.isOnline()) return;
    while (!_retryQueue.isEmpty) {
      final op = _retryQueue.dequeue();
      if (op == null) return;
      final actionName =
          (op.payload['action'] ?? ScanAction.checkIn.name).toString();
      final queuedAction = ScanAction.values.firstWhere(
        (e) => e.name == actionName,
        orElse: () => ScanAction.checkIn,
      );
      await _process(op.payload['rawCode'].toString(), queuedAction);
    }
  }

  Future<void> _process(String rawCode, ScanAction resolvedAction) async {
    try {
      final result =
          await _repo.processScan(rawCode: rawCode, action: resolvedAction);
      _lastProcessAt = DateTime.now();
      AppLogger.event('scan_processed',
          payload: {'outcome': result.type.name, 'action': resolvedAction.name});

      if (result.type == ScanOutcomeType.success) {
        state = ScanState.success;
        feedback = result.message;
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);
        // Bersihkan cache kode ini agar scan berikutnya bisa langsung diproses
        _recentCodes.remove(rawCode);
      } else {
        state = ScanState.error;
        feedback = result.message;
        HapticFeedback.vibrate();
      }
    } catch (e) {
      _lastProcessAt = DateTime.now();
      state = ScanState.error;
      feedback = 'Terjadi kesalahan, coba lagi';
      HapticFeedback.vibrate();
    }
    notifyListeners();
    // Tidak lagi auto-reset ke scanning di sini.
    // UI yang akan panggil resetAfterResult() setelah dialog ditutup.
  }

  void setReady() {
    state = ScanState.scanning;
    feedback = 'Arahkan ke QR code';
    lastDetectedAction = null;
    notifyListeners();
  }
}
