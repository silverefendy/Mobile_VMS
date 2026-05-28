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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  void _showResultDialog(BuildContext context, ScanState state, String message) {
    final isSuccess = state == ScanState.success;
    final isQueued = state == ScanState.queued;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  color: isSuccess
                      ? Colors.green.shade50
                      : isQueued
                          ? Colors.orange.shade50
                          : Colors.red.shade50,
                ),
                child: Icon(
                  isSuccess
                      ? Icons.check_circle_rounded
                      : isQueued
                          ? Icons.cloud_upload_rounded
                          : Icons.error_rounded,
                  size: 36,
                  color: isSuccess
                      ? Colors.green.shade600
                      : isQueued
                          ? Colors.orange.shade600
                          : Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isSuccess
                    ? 'Berhasil'
                    : isQueued
                        ? 'Tersimpan Offline'
                        : 'Gagal',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: isSuccess
                        ? Colors.green.shade600
                        : isQueued
                            ? Colors.orange.shade600
                            : Colors.red.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanCoordinator>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (scan.state == ScanState.success ||
          scan.state == ScanState.error ||
          scan.state == ScanState.queued) {
        if (ModalRoute.of(context)?.isCurrent == true) {
          _showResultDialog(context, scan.state, scan.feedback);
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final raw = capture.barcodes.first.rawValue;
              if (raw != null && raw.isNotEmpty) {
                scan.onCodeDetected(raw);
              }
            },
          ),

          // Viewfinder overlay
          const _ScanViewfinder(),

          // Bottom status bar (tetap ada tapi hanya saat idle/scanning)
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
                child: Text(
                  scan.feedback,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),

          // Retry button kalau ada pending
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  _TopBarButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ScanAction.values.map((a) {
                        final isActive = scan.action == a;
                        return GestureDetector(
                          onTap: () => scan.setAction(a),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _actionLabel(a),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isActive ? Colors.black87 : Colors.white70,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Spacer(),
                  _TopBarButton(
                    icon: scan.torchOn ? Icons.flash_on : Icons.flash_off,
                    onTap: () async {
                      scan.toggleTorch();
                      await _controller.toggleTorch();
                    },
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _actionLabel(ScanAction action) {
    switch (action) {
      case ScanAction.checkIn:
        return 'Check-In';
      case ScanAction.checkOut:
        return 'Check-Out';
      case ScanAction.employeeEntry:
        return 'Karyawan';
    }
  }
}

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
        Offset(size.width, size.height - len)
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
