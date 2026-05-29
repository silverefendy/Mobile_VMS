import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../config/app_config.dart';
import '../../core/connectivity/connectivity_service.dart';
import '../../core/errors/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../../core/qr/qr_validation_service.dart';
import '../../core/resilience/pending_operation_queue.dart';
import '../../domain/models/operation_models.dart';
import '../../domain/repositories/operations_repository.dart';

enum ScanState {
  idle,
  scanning,
  resolving,
  awaitingConfirmation,
  processing,
  cooldown,
  success,
  error,
  queued,
}

class ScanCoordinator extends ChangeNotifier {
  ScanCoordinator(
    this._repo,
    this._connectivityService,
    this._qrValidationService,
  );

  final OperationsRepository _repo;
  final ConnectivityService _connectivityService;
  final QrValidationService _qrValidationService;

  final Queue<DateTime> _recentScanWindow = Queue<DateTime>();
  final Map<String, DateTime> _recentCodes = {};
  final PendingOperationQueue _retryQueue = PendingOperationQueue();

  ScanState state = ScanState.idle;
  String feedback = 'Arahkan ke QR code';
  bool torchOn = false;
  ScanResolution? pendingConfirmation;

  bool _isProcessing = false;
  DateTime? _lastProcessAt;

  bool get isBusy =>
      _isProcessing ||
      state == ScanState.resolving ||
      state == ScanState.awaitingConfirmation ||
      state == ScanState.processing ||
      state == ScanState.cooldown;
  int get pendingRetryCount => _retryQueue.length;

  void toggleTorch() {
    torchOn = !torchOn;
    notifyListeners();
  }

  void handleCameraError([String? message]) {
    state = ScanState.error;
    feedback = message ?? 'Kamera gagal membaca QR, coba lagi';
    notifyListeners();
  }

  void resetAfterResult() {
    if (state == ScanState.success ||
        state == ScanState.error ||
        state == ScanState.queued) {
      state = ScanState.scanning;
      feedback = 'Siap scan berikutnya';
      pendingConfirmation = null;
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
        now.difference(_lastProcessAt!).inMilliseconds < 900) {
      return;
    }

    final lastAt = _recentCodes[rawCode];
    if (lastAt != null && now.difference(lastAt).inMilliseconds < 1200) {
      return;
    }
    _recentCodes[rawCode] = now;

    _recentScanWindow.add(now);
    while (_recentScanWindow.isNotEmpty &&
        now.difference(_recentScanWindow.first).inMinutes > 2) {
      _recentScanWindow.removeFirst();
    }

    _isProcessing = true;
    state = ScanState.resolving;
    feedback = 'Membaca aksi dari backend...';
    pendingConfirmation = null;
    notifyListeners();

    try {
      if (AppConfig.enableOfflineQueue &&
          !await _connectivityService.isOnline()) {
        state = ScanState.error;
        feedback = 'Offline - aksi scan harus dikonfirmasi backend terlebih dahulu';
        HapticFeedback.vibrate();
        notifyListeners();
        return;
      }

      final resolution = await _repo.resolveScanAction(rawCode: rawCode);
      pendingConfirmation = resolution;
      state = ScanState.awaitingConfirmation;
      feedback = 'Konfirmasi aksi ${resolution.nextAction}';
      AppLogger.event('scan_action_resolved', payload: {
        'entity': resolution.entityType.name,
        'action': resolution.nextAction,
      });
      notifyListeners();
    } on AppException catch (e) {
      state = ScanState.error;
      feedback = e.message.isEmpty ? 'Gagal membaca aksi scan' : e.message;
      HapticFeedback.vibrate();
      notifyListeners();
    } catch (_) {
      state = ScanState.error;
      feedback = 'Terjadi kesalahan, coba lagi';
      HapticFeedback.vibrate();
      notifyListeners();
    } finally {
      _isProcessing = false;
      _lastProcessAt = DateTime.now();
      notifyListeners();
    }
  }

  void cancelPendingScan() {
    final rawCode = pendingConfirmation?.rawCode;
    if (rawCode != null) _recentCodes.remove(rawCode);
    pendingConfirmation = null;
    state = ScanState.scanning;
    feedback = 'Scan dibatalkan';
    _lastProcessAt = DateTime.now();
    notifyListeners();
  }

  Future<void> confirmPendingScan() async {
    final resolution = pendingConfirmation;
    if (resolution == null || _isProcessing) return;

    _isProcessing = true;
    state = ScanState.processing;
    feedback = 'Menjalankan ${resolution.nextAction}...';
    notifyListeners();

    try {
      final result = await _repo.executeScanAction(resolution: resolution);
      _lastProcessAt = DateTime.now();
      AppLogger.event('scan_action_executed', payload: {
        'outcome': result.type.name,
        'action': resolution.nextAction,
        'entity': resolution.entityType.name,
      });

      if (result.type == ScanOutcomeType.success) {
        state = ScanState.success;
        feedback = result.message;
        HapticFeedback.heavyImpact();
        await SystemSound.play(SystemSoundType.click);
        _recentCodes.remove(resolution.rawCode);
      } else {
        state = ScanState.error;
        feedback = result.message;
        HapticFeedback.vibrate();
      }
    } catch (_) {
      _lastProcessAt = DateTime.now();
      state = ScanState.error;
      feedback = 'Terjadi kesalahan, coba lagi';
      HapticFeedback.vibrate();
    } finally {
      pendingConfirmation = null;
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> retryPending() async {
    if (!await _connectivityService.isOnline()) return;
    while (!_retryQueue.isEmpty) {
      final op = _retryQueue.dequeue();
      if (op == null) return;
      final rawCode = op.payload['rawCode']?.toString();
      final nextAction = op.payload['action']?.toString();
      if (rawCode == null || nextAction == null || nextAction.isEmpty) continue;
      pendingConfirmation = ScanResolution(
        rawCode: rawCode,
        entityType: ScanEntityType.unknown,
        currentStatus: '',
        nextAction: nextAction,
      );
      await confirmPendingScan();
    }
  }

  void setReady() {
    _isProcessing = false;
    state = ScanState.scanning;
    feedback = 'Arahkan ke QR code';
    pendingConfirmation = null;
    notifyListeners();
  }
}
