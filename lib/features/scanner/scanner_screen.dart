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
  final MobileScannerController _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);

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

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanCoordinator>();
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final raw = capture.barcodes.first.rawValue;
              if (raw != null && raw.isNotEmpty) {
                scan.onCodeDetected(raw);
              }
            },
          ),
          _Overlay(feedback: scan.feedback, state: scan.state),
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
          Positioned(
            top: 32,
            left: 16,
            right: 16,
            child: Row(children: [
              IconButton.filledTonal(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
              const Spacer(),
              DropdownButton<ScanAction>(
                value: scan.action,
                dropdownColor: Colors.black87,
                style: const TextStyle(color: Colors.white),
                onChanged: (v) => v != null ? scan.setAction(v) : null,
                items: const [
                  DropdownMenuItem(value: ScanAction.checkIn, child: Text('Check-In')),
                  DropdownMenuItem(value: ScanAction.checkOut, child: Text('Check-Out')),
                  DropdownMenuItem(value: ScanAction.employeeEntry, child: Text('Employee')),
                ],
              ),
              IconButton.filledTonal(
                onPressed: () async {
                  scan.toggleTorch();
                  await _controller.toggleTorch();
                },
                icon: Icon(scan.torchOn ? Icons.flash_on : Icons.flash_off),
              )
            ]),
          ),
        ],
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.feedback, required this.state});
  final String feedback;
  final ScanState state;

  @override
  Widget build(BuildContext context) {
    Color color = Colors.white;
    if (state == ScanState.success) color = Colors.greenAccent;
    if (state == ScanState.error) color = Colors.redAccent;
    if (state == ScanState.queued) color = Colors.orangeAccent;
    return Column(
      children: [
        const Spacer(),
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12), border: Border.all(color: color, width: 2)),
          child: Row(children: [
            Expanded(child: Text(feedback, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700))),
          ]),
        )
      ],
    );
  }
}
