import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'activity_controller.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ActivityController>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ActivityController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Recent Activity')),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: vm.refresh,
              child: ListView.builder(
                itemCount: vm.events.length,
                itemBuilder: (_, i) {
                  final e = vm.events[i];
                  return ListTile(title: Text(e.message), subtitle: Text('${e.type} • ${e.time}'));
                },
              ),
            ),
    );
  }
}
