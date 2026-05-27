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

    final grouped = <String, List<MenuItem>>{};
    for (final item in menu) {
      grouped.putIfAbsent(item.group, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operations'),
        actions: [
          IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings)),
          IconButton(onPressed: auth.logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const DashboardSection(),
          const SizedBox(height: 16),
          for (final entry in grouped.entries) ...[
            Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _OperationalMenuGrid(items: entry.value),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _OperationalMenuGrid extends StatelessWidget {
  const _OperationalMenuGrid({required this.items});
  final List<MenuItem> items;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1000 ? 4 : width >= 700 ? 3 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2,
      ),
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];
        return FilledButton.tonal(
          onPressed: () => context.push(item.route),
          child: Text(item.label, textAlign: TextAlign.center),
        );
      },
    );
  }
}
