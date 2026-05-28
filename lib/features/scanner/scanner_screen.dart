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

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
  );

  /// Guard agar dialog tidak muncul dobel
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final coordinator = context.read<ScanCoordinator>();
      coordinator.setReady();
      coordinator.retryPending();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _maybeShowResultDialog(
      BuildContext context, ScanCoordinator scan) async {
    if (_dialogShowing) return;
    if (scan.state != ScanState.success &&
        scan.state != ScanState.error &&
        scan.state != ScanState.queued) return;

    _dialogShowing = true;
    final capturedState = scan.state;
    final capturedMsg = scan.feedback;
    final capturedAction = scan.lastDetectedAction;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        state: capturedState,
        message: capturedMsg,
        detectedAction: capturedAction,
      ),
    );

    // Dialog sudah ditutup — reset coordinator supaya scanner siap lagi
    if (mounted) {
      context.read<ScanCoordinator>().resetAfterResult();
    }
    _dialogShowing = false;
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanCoordinator>();

    // Panggil dialog hanya sekali per state result
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeShowResultDialog(context, scan);
    });

    final isAutoMode = scan.scanMode == ScanMode.auto;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Kamera
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final raw = capture.barcodes.first.rawValue;
              if (raw != null && raw.isNotEmpty) {
                scan.onCodeDetected(raw);
              }
            },
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
                  isAutoMode
                      ? 'Mode otomatis — sistem akan deteksi check-in / check-out'
                      : '${_actionLabel(scan.action)} — scan QR',
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
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),

                    // Mode selector: Auto | Check-In | Check-Out | Karyawan
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tombol AUTO
                          _ModeChip(
                            label: 'Auto',
                            isActive: isAutoMode,
                            activeColor: Colors.blue.shade300,
                            onTap: () => scan.setScanMode(ScanMode.auto),
                          ),
                          // Tombol manual per aksi
                          ...ScanAction.values.map((a) => _ModeChip(
                                label: _actionLabelShort(a),
                                isActive:
                                    !isAutoMode && scan.action == a,
                                onTap: () => scan.setAction(a),
                              )),
                        ],
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

  String _actionLabel(ScanAction a) {
    switch (a) {
      case ScanAction.checkIn:
        return 'Check-In';
      case ScanAction.checkOut:
        return 'Check-Out';
      case ScanAction.employeeEntry:
        return 'Karyawan';
    }
  }

  String _actionLabelShort(ScanAction a) {
    switch (a) {
      case ScanAction.checkIn:
        return 'In';
      case ScanAction.checkOut:
        return 'Out';
      case ScanAction.employeeEntry:
        return 'Emp';
    }
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

// ---------------------------------------------------------------------------
// Mode chip di top bar
// ---------------------------------------------------------------------------

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.activeColor,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? (activeColor ?? Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive
                ? (activeColor != null
                    ? Colors.white
                    : Colors.black87)
                : Colors.white70,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Viewfinder
// ---------------------------------------------------------------------------

class _ScanViewfinder extends StatelessWidget {
  const _ScanViewfinder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(220, 220),
            painter: _ViewfinderPainter(),
          ),
          const SizedBox(height: 16),
          const Text(
            'Arahkan kamera ke QR code',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cornerPaint = Paint()
      ..color = Colors.blue.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const r = Radius.circular(4);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, r), paint);

    const len = 24.0;
    final corners = [
      [Offset(0, len), Offset.zero, Offset(len, 0)],
      [Offset(size.width - len, 0), Offset(size.width, 0), Offset(size.width, len)],
      [Offset(0, size.height - len), Offset(0, size.height), Offset(len, size.height)],
      [
        Offset(size.width - len, size.height),
        Offset(size.width, size.height),
        Offset(size.width, size.height - len),
      ],
    ];
    for (final c in corners) {
      final path = Path()
        ..moveTo(c[0].dx, c[0].dy)
        ..lineTo(c[1].dx, c[1].dy)
        ..lineTo(c[2].dx, c[2].dy);
      canvas.drawPath(path, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
