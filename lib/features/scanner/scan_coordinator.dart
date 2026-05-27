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

class ScanCoordinator extends ChangeNotifier {
  ScanCoordinator(this._repo, this._connectivityService, this._qrValidationService);
  final OperationsRepository _repo;
  final ConnectivityService _connectivityService;
  final QrValidationService _qrValidationService;

  final Queue<DateTime> _recentScanWindow = Queue<DateTime>();
  final Map<String, DateTime> _recentCodes = {};
  final PendingOperationQueue _retryQueue = PendingOperationQueue();

  ScanState state = ScanState.idle;
  String feedback = 'Align QR inside the frame';
  bool torchOn = false;
  ScanAction action = ScanAction.checkIn;
  DateTime? _lastProcessAt;

  bool get isBusy => state == ScanState.processing || state == ScanState.cooldown;
  int get pendingRetryCount => _retryQueue.length;

  void setAction(ScanAction next) {
    action = next;
    notifyListeners();
  }

  void toggleTorch() {
    torchOn = !torchOn;
    notifyListeners();
  }

  Future<void> onCodeDetected(String rawCode) async {
    final validation = _qrValidationService.validate(rawCode);
    if (!validation.isValid) {
      state = ScanState.error;
      feedback = validation.reason ?? 'Invalid QR';
      AppLogger.warn('qr_validation_failed', context: {'reason': feedback});
      notifyListeners();
      return;
    }
    final now = DateTime.now();
    if (isBusy) return;
    if (_lastProcessAt != null && now.difference(_lastProcessAt!).inMilliseconds < 900) return;

    final lastAt = _recentCodes[rawCode];
    if (lastAt != null && now.difference(lastAt).inSeconds < 4) {
      state = ScanState.error;
      feedback = 'Duplicate scan detected';
      notifyListeners();
      return;
    }
    _recentCodes[rawCode] = now;
    _recentScanWindow.add(now);
    while (_recentScanWindow.isNotEmpty && now.difference(_recentScanWindow.first).inMinutes > 2) {
      _recentScanWindow.removeFirst();
    }

    state = ScanState.processing;
    feedback = 'Processing...';
    notifyListeners();

    if (AppConfig.enableOfflineQueue && !await _connectivityService.isOnline()) {
      _retryQueue.enqueue(PendingOperation(id: rawCode.hashCode.toString(), payload: {'rawCode': rawCode, 'action': action.name}, createdAt: DateTime.now()));
      state = ScanState.queued;
      feedback = 'Offline - scan queued (${_retryQueue.length})';
      notifyListeners();
      return;
    }

    await _process(rawCode, action);
  }

  Future<void> retryPending() async {
    if (!await _connectivityService.isOnline()) return;
    while (!_retryQueue.isEmpty) {
      final op = _retryQueue.dequeue();
      if (op == null) return;
      final actionName = (op.payload['action'] ?? ScanAction.checkIn.name).toString();
      final queuedAction = ScanAction.values.firstWhere((e) => e.name == actionName, orElse: () => ScanAction.checkIn);
      await _process(op.payload['rawCode'].toString(), queuedAction);
    }
  }

  Future<void> _process(String rawCode, ScanAction action) async {
    final result = await _repo.processScan(rawCode: rawCode, action: action);
    _lastProcessAt = DateTime.now();
    AppLogger.event('scan_processed', payload: {'outcome': result.type.name, 'action': action.name});

    if (result.type == ScanOutcomeType.success) {
      state = ScanState.success;
      feedback = result.message;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.click);
    } else {
      state = ScanState.error;
      feedback = result.message;
      HapticFeedback.vibrate();
    }
    notifyListeners();

    state = ScanState.cooldown;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    state = ScanState.scanning;
    feedback = 'Ready';
    notifyListeners();
  }

  void setReady() {
    state = ScanState.scanning;
    notifyListeners();
  }
}
