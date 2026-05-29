import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'dashboard_controller.dart';

class DashboardSection extends StatefulWidget {
  const DashboardSection({super.key});

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DashboardController>().refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final controller = context.read<DashboardController>();

      // Hindari refresh agresif setiap kembali dari background.
      // Dashboard lama tetap ditampilkan agar user tidak perlu login ulang
      // ketika koneksi/session sedang delay sesaat.
      if (controller.cards.isEmpty && !controller.loading) {
        controller.refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardController>();

    if (vm.loading && vm.cards.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (vm.error != null && vm.cards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Dashboard tidak tersedia',
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              color: Colors.red.shade400,
              onPressed: () => context.read<DashboardController>().refresh(),
              iconSize: 20,
            ),
          ],
        ),
      );
    }

    if (vm.cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A8A),
                letterSpacing: 0.5,
              ),
            ),
            GestureDetector(
              onTap: () => context.read<DashboardController>().refresh(force: true),
              child: const Icon(Icons.refresh_rounded,
                  size: 18, color: Color(0xFF1E3A8A)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: vm.cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.8,
          ),
          itemBuilder: (_, i) {
            final card = vm.cards[i];
            return _DashCard(
              title: card.title,
              value: card.value,
              iconKey: card.iconKey,
              onTap:
                  card.route != null ? () => context.push(card.route!) : null,
            );
          },
        ),
      ],
    );
  }
}

class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.title,
    required this.value,
    required this.iconKey,
    this.onTap,
  });

  final String title;
  final String value;
  final String iconKey;
  final VoidCallback? onTap;

  static const _iconMap = <String, IconData>{
    'hourglass': Icons.hourglass_top_rounded,
    'people': Icons.people_alt_rounded,
    'check_circle': Icons.check_circle_outline_rounded,
    'logout': Icons.door_front_door_outlined,
    'dashboard': Icons.dashboard_rounded,
  };

  static const _colors = [
    Color(0xFFD97706),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF059669),
  ];

  static const _bgs = [
    Color(0xFFFEF3C7),
    Color(0xFFDBEAFE),
    Color(0xFFEDE9FE),
    Color(0xFFD1FAE5),
  ];

  @override
  Widget build(BuildContext context) {
    final colorIdx = iconKey.hashCode.abs() % _colors.length;
    final color = _colors[colorIdx];
    final bg = _bgs[colorIdx];
    final icon = _iconMap[iconKey] ?? Icons.info_outline_rounded;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDE4F5), width: 0.5),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A8A),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
