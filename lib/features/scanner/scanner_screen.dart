import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../domain/models/operation_models.dart';
import 'scan_coordinator.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    autoStart: false,
  );

  bool _dialogShowing = false;
  bool _isProcessingScan = false;
  bool _cameraPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final coordinator = context.read<ScanCoordinator>();
      coordinator.setReady();
      await _safeStartCamera();
      await coordinator.retryPending();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _safeStopCamera();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_dialogShowing && !_isProcessingScan) {
        if (_cameraPaused) _safeStartCamera();
        if (mounted) context.read<ScanCoordinator>().setReady();
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _safeStopCamera();
    }
  }

  Future<void> _safeStopCamera() async {
    try {
      await _controller.stop();
    } catch (_) {
    } finally {
      _cameraPaused = true;
    }
  }

  Future<void> _safeStartCamera() async {
    if (!mounted) return;
    try {
      await _controller.start();
      _cameraPaused = false;
    } catch (_) {
      _cameraPaused = true;
    }
  }

  bool _hasResult(ScanState state) =>
      state == ScanState.success ||
      state == ScanState.error ||
      state == ScanState.queued;

  Future<void> _handleDetection(
    ScanCoordinator scan,
    BarcodeCapture capture,
  ) async {
    if (_isProcessingScan || _dialogShowing) return;

    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        raw = value;
        break;
      }
    }

    if (raw == null) return;

    _isProcessingScan = true;
    await _safeStopCamera();

    try {
      await scan.onCodeDetected(raw);

      if (!mounted) return;

      if (scan.state == ScanState.awaitingConfirmation &&
          scan.pendingConfirmation != null) {
        final confirmed = await _showConfirmationDialog(scan.pendingConfirmation!);
        if (!mounted) return;

        if (confirmed) {
          await scan.confirmPendingScan();
          if (!mounted) return;
          if (_hasResult(scan.state)) {
            await _showResultDialog(scan);
          }
        } else {
          scan.cancelPendingScan();
          _showSnackBar('Scan dibatalkan');
        }
      } else if (_hasResult(scan.state)) {
        await _showResultDialog(scan);
      }
    } finally {
      _isProcessingScan = false;

      if (mounted) {
        scan.resetAfterResult();
        await _safeStartCamera();
      }
    }
  }

  Future<bool> _showConfirmationDialog(ScanResolution resolution) async {
    if (_dialogShowing) return false;

    _dialogShowing = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ScanConfirmationDialog(resolution: resolution),
      );
      return confirmed ?? false;
    } finally {
      _dialogShowing = false;
    }
  }

  Future<void> _showResultDialog(ScanCoordinator scan) async {
    if (_dialogShowing || !_hasResult(scan.state)) return;

    _dialogShowing = true;

    final capturedState = scan.state;
    final capturedMsg = scan.feedback;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ResultDialog(
          state: capturedState,
          message: capturedMsg,
        ),
      );
      if (mounted) {
        _showSnackBar(capturedMsg, isError: capturedState != ScanState.success);
      }
    } finally {
      _dialogShowing = false;
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanCoordinator>();
    final isLoading =
        scan.state == ScanState.resolving || scan.state == ScanState.processing;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            useAppLifecycleState: false,
            onDetect: (capture) => _handleDetection(scan, capture),
            onDetectError: (_, __) {
              if (!_dialogShowing && mounted) {
                scan.handleCameraError();
              }
            },
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Kamera tidak tersedia: ${error.errorCode.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),

          const SizedBox.shrink(),

          if (scan.state == ScanState.idle || scan.state == ScanState.scanning)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Scan QR — aplikasi mengikuti next_action dari backend',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),

          if (isLoading)
            Container(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      scan.feedback,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanConfirmationDialog extends StatelessWidget {
  const _ScanConfirmationDialog({required this.resolution});

  final ScanResolution resolution;

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: Text(_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _contentRows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InfoRow(label: row.$1, value: row.$2),
              ),
            )
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('OK'),
        ),
      ],
    );
  }

  String get _title {
    final normalizedAction = resolution.nextAction.toUpperCase();
    final isOutbound = normalizedAction.contains('OUT');

    if (_isEmployeeAction) {
      return isOutbound ? 'Employee Check Out?' : 'Employee Check In?';
    }
    if (resolution.isVisitor) {
      return isOutbound ? 'Check Out Visitor?' : 'Check In Visitor?';
    }
    return 'Confirm Scan Action?';
  }

  bool get _isEmployeeAction =>
      resolution.isEmployee || resolution.nextAction.toUpperCase().startsWith('EMPLOYEE');

  List<(String, String)> get _contentRows {
    final status = _displayValue(resolution.currentStatus);
    if (_isEmployeeAction) {
      return [
        ('Nama', _displayValue(resolution.employeeName)),
        ('Status', status),
      ];
    }

    return [
      ('Nama', _displayValue(resolution.visitorName)),
      ('Perusahaan', _displayValue(resolution.company)),
      ('Tujuan', _displayValue(resolution.employeeName)),
      ('Status', status),
    ];
  }

  String _displayValue(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? '-' : normalized;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium,
        children: [
          TextSpan(
            text: '$label:\n',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({
    required this.state,
    required this.message,
  });

  final ScanState state;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: Text(state == ScanState.success ? 'Berhasil' : 'Gagal'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
