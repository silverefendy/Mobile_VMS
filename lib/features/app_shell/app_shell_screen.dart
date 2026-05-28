import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../domain/models/menu_item.dart';
import '../dashboard/dashboard_section.dart';
import '../menu/app_menu_controller.dart';

class AppShellScreen extends StatelessWidget {
  const AppShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<AppMenuController>().items;
    final auth = context.read<AuthController>();
    final session = auth.session;

    final grouped = <String, List<MenuItem>>{};
    for (final item in menu) {
      grouped.putIfAbsent(item.group, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              floating: true,
              snap: true,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Operations',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  if (session != null)
                    Text(
                      session.fullName,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                ),
                IconButton(
                  onPressed: auth.logout,
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Logout',
                ),
                const SizedBox(width: 4),
              ],
            ),

            // Body
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Dashboard section
                  const DashboardSection(),
                  const SizedBox(height: 20),

                  // Menu groups
                  for (final entry in grouped.entries) ...[  
                    _SectionHeader(title: entry.key),
                    const SizedBox(height: 10),
                    _MenuGrid(items: entry.value),
                    const SizedBox(height: 20),
                  ],

                  const SizedBox(height: 8),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E3A8A),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 0.5,
            color: const Color(0xFF1E3A8A).withOpacity(0.2),
          ),
        ),
      ],
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.items});
  final List<MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _MenuCard(item: items[i]),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.item});
  final MenuItem item;

  static const _iconMap = <String, IconData>{
    'qr_code_scanner': Icons.qr_code_scanner_rounded,
    'people': Icons.people_alt_rounded,
    'check_circle': Icons.fact_check_rounded,
    'history': Icons.history_rounded,
    'bar_chart': Icons.bar_chart_rounded,
    'scan': Icons.qr_code_scanner_rounded,
  };

  static const _colorMap = <String, Color>{
    'qr_code_scanner': Color(0xFF2563EB),
    'scan': Color(0xFF2563EB),
    'people': Color(0xFF16A34A),
    'check_circle': Color(0xFFEA580C),
    'history': Color(0xFF7C3AED),
    'bar_chart': Color(0xFF0891B2),
  };

  static const _bgMap = <String, Color>{
    'qr_code_scanner': Color(0xFFEFF6FF),
    'scan': Color(0xFFEFF6FF),
    'people': Color(0xFFF0FDF4),
    'check_circle': Color(0xFFFFF7ED),
    'history': Color(0xFFFAF5FF),
    'bar_chart': Color(0xFFECFEFF),
  };

  @override
  Widget build(BuildContext context) {
    final icon = _iconMap[item.iconKey] ?? Icons.widgets_rounded;
    final color = _colorMap[item.iconKey] ?? const Color(0xFF1E3A8A);
    final bg = _bgMap[item.iconKey] ?? const Color(0xFFEFF6FF);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(item.route),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFDDE4F5),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
