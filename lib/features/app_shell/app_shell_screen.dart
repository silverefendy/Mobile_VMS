import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../menu/menu_controller.dart';

class AppShellScreen extends StatelessWidget {
  const AppShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuController>().items;
    final auth = context.read<AuthController>();
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 900 ? 4 : width >= 600 ? 3 : 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operations'),
        actions: [IconButton(onPressed: auth.logout, icon: const Icon(Icons.logout))],
      ),
      body: menu.isEmpty
          ? const Center(child: Text('No menu configuration from server.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.7,
              ),
              itemCount: menu.length,
              itemBuilder: (_, index) {
                final item = menu[index];
                return Card(
                  child: InkWell(
                    onTap: () => context.push(item.route),
                    child: Center(child: Text(item.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18))),
                  ),
                );
              },
            ),
    );
  }
}
