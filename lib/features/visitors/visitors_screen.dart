import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'visitors_controller.dart';

class VisitorsScreen extends StatefulWidget {
  const VisitorsScreen({super.key});

  @override
  State<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends State<VisitorsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<VisitorsController>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VisitorsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Active Visitors')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search visitor / host'),
            onSubmitted: (v) => vm.refresh(search: v.trim()),
          ),
        ),
        if (vm.loading) const LinearProgressIndicator(),
        if (vm.error != null) Padding(padding: const EdgeInsets.all(16), child: Text(vm.error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: RefreshIndicator(
            onRefresh: vm.refresh,
            child: ListView.builder(
              itemCount: vm.visitors.length,
              itemBuilder: (_, i) {
                final v = vm.visitors[i];
                return ListTile(
                  title: Text(v.name),
                  subtitle: Text('Host: ${v.host} • In: ${v.checkInAt}'),
                  trailing: Text(v.status),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}
