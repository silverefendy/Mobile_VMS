import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'dashboard_controller.dart';

class DashboardSection extends StatefulWidget {
  const DashboardSection({super.key});

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<DashboardController>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardController>();
    if (vm.loading) {
      return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    }
    if (vm.error != null) {
      return ListTile(title: const Text('Dashboard unavailable'), subtitle: Text(vm.error!));
    }
    if (vm.cards.isEmpty) {
      return const ListTile(title: Text('No dashboard cards configured'));
    }

    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1000 ? 4 : width >= 700 ? 3 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: vm.cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.1,
      ),
      itemBuilder: (_, i) {
        final card = vm.cards[i];
        return Card(
          child: InkWell(
            onTap: card.route == null ? null : () => context.push(card.route!),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(card.title, style: const TextStyle(fontSize: 14)),
                const Spacer(),
                Text(card.value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        );
      },
    );
  }
}
