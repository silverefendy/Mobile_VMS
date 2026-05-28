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

  /// Guard agar dialog tidak muncul dobel
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
    // Lifecycle-critical: explicitly release and reacquire the camera so Android
    // does not return to a frozen/black preview after backgrounding.
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
      // Ignore camera plugin races during navigation/lifecycle transitions.
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
          // Kamera
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

          // Viewfinder
          const _ScanViewfinder(),

          // Status bar bawah — hanya saat idle/scanning
          if (scan.state == ScanState.idle || scan.state == ScanState.scanning)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Scan QR — sistem otomatis memilih check-in / check-out',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),

          // Processing indicator
          if (scan.state == ScanState.processing)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Retry button
          if (scan.pendingRetryCount > 0)
            Positioned(
              bottom: 112,
              right: 16,
              child: FilledButton.icon(
                onPressed: () => scan.retryPending(),
                icon: const Icon(Icons.sync),
                label: Text('Retry ${scan.pendingRetryCount}'),
              ),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _TopBarButton(
                      icon: Icons.arrow_back,
                      onTap: () async {
                        await _safeStopCamera();
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                    const Spacer(),

                    const Text(
                      'Auto',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const Spacer(),
                    _TopBarButton(
                      icon: scan.torchOn
                          ? Icons.flash_on
                          : Icons.flash_off,
                      onTap: () async {
                        scan.toggleTorch();
                        await _controller.toggleTorch();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result Dialog
// ---------------------------------------------------------------------------

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
    final isSuccess = state == ScanState.success;
    final isQueued = state == ScanState.queued;

    final Color bgColor = isSuccess
        ? Colors.green.shade50
        : isQueued
            ? Colors.orange.shade50
            : Colors.red.shade50;
    final Color iconColor = isSuccess
        ? Colors.green.shade600
        : isQueued
            ? Colors.orange.shade600
            : Colors.red.shade600;
    final IconData icon = isSuccess
        ? Icons.check_circle_rounded
        : isQueued
            ? Icons.cloud_upload_rounded
            : Icons.error_rounded;
    final String title = isSuccess
        ? 'Berhasil'
        : isQueued
            ? 'Tersimpan Offline'
            : 'Gagal';

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
              ),
              child: Icon(icon, size: 36, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (detectedAction != null && isSuccess)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _actionLabel(detectedAction!),
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600),
                ),
              ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: iconColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK',
                    style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _actionLabel(ScanAction a) {
    switch (a) {
      case ScanAction.checkIn:
        return 'Check-In terdeteksi';
      case ScanAction.checkOut:
        return 'Check-Out terdeteksi';
      case ScanAction.employeeEntry:
        return 'Karyawan terdeteksi';
    }
  }
}

// ---------------------------------------------------------------------------
// Top bar button
// ---------------------------------------------------------------------------

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
