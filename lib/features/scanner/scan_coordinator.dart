import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/models/operation_models.dart';
import '../../domain/repositories/operations_repository.dart';

enum ScanState { idle, scanning, processing, cooldown, success, error }

class ScanCoordinator extends ChangeNotifier {
  ScanCoordinator(this._repo);
  final OperationsRepository _repo;

  final Queue<DateTime> _recentScanWindow = Queue<DateTime>();
  final Map<String, DateTime> _recentCodes = {};

  ScanState state = ScanState.idle;
  String feedback = 'Align QR inside the frame';
  bool torchOn = false;
  ScanAction action = ScanAction.checkIn;
  DateTime? _lastProcessAt;

  bool get isBusy => state == ScanState.processing || state == ScanState.cooldown;

  void setAction(ScanAction next) {
    action = next;
    notifyListeners();
  }

  void toggleTorch() {
    torchOn = !torchOn;
    notifyListeners();
  }

  Future<void> onCodeDetected(String rawCode) async {
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

    final result = await _repo.processScan(rawCode: rawCode, action: action);
    _lastProcessAt = DateTime.now();

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
