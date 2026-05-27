import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../menu/menu_controller.dart';

class AppShellScreen extends StatelessWidget {
  const AppShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuController>().items;
    final auth = context.read<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operations'),
        actions: [IconButton(onPressed: auth.logout, icon: const Icon(Icons.logout))],
      ),
      body: menu.isEmpty
          ? const Center(child: Text('No menu configuration from server.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.7,
              ),
              itemCount: menu.length,
              itemBuilder: (_, index) {
                final item = menu[index];
                return Card(
                  child: InkWell(
                    onTap: () {},
                    child: Center(child: Text(item.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18))),
                  ),
                );
              },
            ),
    );
  }
}
