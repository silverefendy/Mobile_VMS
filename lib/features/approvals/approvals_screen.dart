import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'approvals_controller.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ApprovalsController>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ApprovalsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Approvals')),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: vm.items.length,
              itemBuilder: (_, i) {
                final a = vm.items[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.visitorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('Host: ${a.hostName}'),
                      Text('Purpose: ${a.purpose}'),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: FilledButton(onPressed: () => vm.approve(a.id), child: const Text('Approve'))),
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton(onPressed: () => vm.reject(a.id), child: const Text('Reject'))),
                      ])
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
