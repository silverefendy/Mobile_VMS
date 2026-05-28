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
    formats: [BarcodeFormat.qrCode],
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

      if (_hasResult(scan.state)) {
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

  Future<void> _showResultDialog(ScanCoordinator scan) async {
    if (_dialogShowing || !_hasResult(scan.state)) return;

    _dialogShowing = true;

    final capturedState = scan.state;
    final capturedMsg = scan.feedback;
    final capturedAction = scan.lastDetectedAction;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ResultDialog(
          state: capturedState,
          message: capturedMsg,
          detectedAction: capturedAction,
        ),
      );
    } finally {
      _dialogShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanCoordinator>();

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
                  'Scan QR — sistem otomatis memilih check-in / check-out',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),

          if (scan.state == ScanState.processing)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({
    required this.state,
    required this.message,
    this.detectedAction,
  });

  final ScanState state;
  final String message;
  final ScanAction? detectedAction;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
