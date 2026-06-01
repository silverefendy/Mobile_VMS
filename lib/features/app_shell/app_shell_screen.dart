import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/auth/auth_controller.dart';
import '../../domain/models/menu_item.dart';
import '../dashboard/dashboard_controller.dart';
import '../employee/employee_dashboard_controller.dart';
import '../menu/app_menu_controller.dart';
import '../widgets/connection_indicator.dart';
import '../../theme/colors.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardController>().refresh();
      context.read<EmployeeDashboardController>().refreshDashboard();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    final session = auth.session;
    final menu = context.watch<AppMenuController>().items;

    // Pisahkan menu visitor vs employee
    final visitorItems = menu
        .where((m) => !_isEmployeeItem(m.id))
        .toList();
    final employeeItems = menu
        .where((m) => _isEmployeeItem(m.id))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              backgroundColor: kBrandTeal,
              foregroundColor: Colors.white,
              floating: true,
              snap: true,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('VMS',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  if (session != null)
                    Text(session.fullName,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70)),
                ],
              ),
              actions: [
                // ✅ Connection indicator di pojok kanan atas AppBar
                ConnectionIndicator(position: ConnectionPosition.topRight),
                const SizedBox(width: 4),
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
              bottom: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.people_alt_rounded, size: 18),
                    text: 'Visitor',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                  Tab(
                    icon: Icon(Icons.badge_rounded, size: 18),
                    text: 'Employee',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                ],
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _VisitorTab(menuItems: visitorItems),
              _EmployeeTab(menuItems: employeeItems),
            ],
          ),
        ),
      ),
    );
  }

  /// Item yang termasuk ke tab Employee
  bool _isEmployeeItem(String id) =>
      id == 'employee' || id.startsWith('emp');
}

// ---------------------------------------------------------------------------
// TAB 1 — Visitor
// ---------------------------------------------------------------------------

class _VisitorTab extends StatelessWidget {
  const _VisitorTab({required this.menuItems});
  final List<MenuItem> menuItems;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardController>();

    // Grup menu visitor
    final grouped = <String, List<MenuItem>>{};
    for (final item in menuItems) {
      grouped.putIfAbsent(item.group, () => []).add(item);
    }

    return RefreshIndicator(
      onRefresh: () => context.read<DashboardController>().refresh(force: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          _TabHeader(
            icon: Icons.people_alt_rounded,
            title: 'Visitor Overview',
            subtitle: 'Status kunjungan tamu hari ini',
          ),
          const SizedBox(height: 14),

          // Dashboard cards visitor
          if (vm.loading && vm.cards.isEmpty)
            const SizedBox(
              height: 100,
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (vm.cards.isNotEmpty)
            _VisitorCardsGrid(cards: vm.cards)
          else if (vm.error != null)
            _ErrorChip(
              message: 'Gagal memuat statistik',
              onRetry: () =>
                  context.read<DashboardController>().refresh(force: true),
            ),

          const SizedBox(height: 20),

          // Menu visitor
          for (final entry in grouped.entries) ...[
            _SectionHeader(title: entry.key),
            const SizedBox(height: 10),
            _MenuGrid(items: entry.value),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 2 — Employee
// ---------------------------------------------------------------------------

class _EmployeeTab extends StatelessWidget {
  const _EmployeeTab({required this.menuItems});
  final List<MenuItem> menuItems;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EmployeeDashboardController>();
    final dash = vm.dashboard;

    return RefreshIndicator(
      onRefresh: vm.refreshDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          _TabHeader(
            icon: Icons.badge_rounded,
            title: 'Employee Overview',
            subtitle: dash?.isManager == true
                ? 'Monitoring karyawan di area'
                : 'Status masuk area Anda hari ini',
          ),
          const SizedBox(height: 14),

          // Loading
          if (vm.loadingDashboard && dash == null)
            const SizedBox(
              height: 100,
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          // Employee cards — manager vs personal
          else if (dash != null) ...[
            if (dash.isManager)
              _EmployeeManagerCards(vm: vm)
            else
              _EmployeePersonalCard(dash: dash),
          ] else if (vm.errorDashboard != null)
            _ErrorChip(
              message: 'Gagal memuat data employee',
              onRetry: vm.refreshDashboard,
            ),

          const SizedBox(height: 16),

          // Tombol ke halaman detail employee dashboard
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/employee'),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(
                dash?.isManager == true
                    ? 'Lihat Detail Semua Karyawan'
                    : 'Lihat Riwayat Saya',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: kBrandTeal,
                side: const BorderSide(color: kBrandTeal),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Menu employee (kalau ada)
          if (menuItems.isNotEmpty) ...[
            _SectionHeader(title: 'Employee Menu'),
            const SizedBox(height: 10),
            _MenuGrid(items: menuItems),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Employee cards — Manager view
// ---------------------------------------------------------------------------

class _EmployeeManagerCards extends StatelessWidget {
  const _EmployeeManagerCards({required this.vm});
  final EmployeeDashboardController vm;

  @override
  Widget build(BuildContext context) {
    final inside = vm.insideResult;
    final pending = inside?.pendingApproval ?? 0;
    final approved = inside?.approvedInside ?? 0;
    final total = inside?.total ?? 0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: [
        _StatCard(
          label: 'Menunggu Approval',
          value: '$pending',
          icon: Icons.hourglass_top_rounded,
          color: Colors.orange,
        ),
        _StatCard(
          label: 'Di Dalam Area',
          value: '$approved',
          icon: Icons.badge_rounded,
          color: kBrandTeal,
        ),
        _StatCard(
          label: 'Total di Area',
          value: '$total',
          icon: Icons.groups_rounded,
          color: Colors.purple,
        ),
        _StatCard(
          label: 'Tap untuk detail',
          value: '→',
          icon: Icons.arrow_forward_rounded,
          color: Colors.grey,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Employee cards — Personal view
// ---------------------------------------------------------------------------

class _EmployeePersonalCard extends StatelessWidget {
  const _EmployeePersonalCard({required this.dash});
  final dynamic dash;

  @override
  Widget build(BuildContext context) {
    final inside = dash.todaySummary.currentlyInside as bool;
    final total = dash.todaySummary.totalEntries as int;
    final lastIn = dash.todaySummary.lastCheckIn as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: inside ? kBrandTeal : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: inside
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              inside
                  ? Icons.location_on_rounded
                  : Icons.location_off_rounded,
              color: inside ? Colors.white : Colors.grey,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inside ? 'Anda di Dalam Area' : 'Anda di Luar Area',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: inside ? Colors.white : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lastIn != null
                      ? 'Masuk: $lastIn  •  Total: $total entry'
                      : 'Belum ada entry hari ini',
                  style: TextStyle(
                    fontSize: 12,
                    color: inside
                        ? Colors.white70
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable stat card
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Visitor cards grid (dari DashboardController)
// ---------------------------------------------------------------------------

class _VisitorCardsGrid extends StatelessWidget {
  const _VisitorCardsGrid({required this.cards});
  final List<dynamic> cards;

  static const _iconMap = <String, IconData>{
    'hourglass': Icons.hourglass_top_rounded,
    'people': Icons.people_alt_rounded,
    'check_circle': Icons.check_circle_outline_rounded,
    'logout': Icons.door_front_door_outlined,
    'dashboard': Icons.dashboard_rounded,
  };

  static const _colors = [
    Color(0xFFD97706),
    kBrandTeal,
    Color(0xFF7C3AED),
    Color(0xFF059669),
  ];

  static const _bgs = [
    Color(0xFFFEF3C7),
    kBrandTealLight,
    Color(0xFFEDE9FE),
    Color(0xFFD1FAE5),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.8,
      ),
      itemBuilder: (_, i) {
        final card = cards[i];
        final colorIdx = i % _colors.length;
        final icon = _iconMap[card.iconKey] ?? Icons.info_outline;
        return GestureDetector(
          onTap: card.route != null
              ? () => context.push(card.route as String)
              : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0xFFDDE4F5), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _bgs[colorIdx],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon,
                      color: _colors[colorIdx], size: 16),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.value,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _colors[colorIdx],
                            height: 1)),
                    const SizedBox(height: 2),
                    Text(card.title,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _TabHeader extends StatelessWidget {
  const _TabHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kBrandTealLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: kBrandTeal, size: 22),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kBrandTeal)),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
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
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kBrandTeal,
                letterSpacing: 0.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 0.5,
            color: kBrandTeal.withValues(alpha: 0.25),
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
    'scan': Icons.qr_code_scanner_rounded,
    'people': Icons.people_alt_rounded,
    'check_circle': Icons.fact_check_rounded,
    'history': Icons.history_rounded,
    'bar_chart': Icons.bar_chart_rounded,
    'badge': Icons.badge_rounded,
    'today': Icons.today_rounded,
    'hourglass': Icons.hourglass_top_rounded,
    'logout': Icons.door_front_door_outlined,
  };

  static const _colorMap = <String, Color>{
    'qr_code_scanner': kBrandTeal,
    'scan': kBrandTeal,
    'people': Color(0xFF16A34A),
    'check_circle': Color(0xFFEA580C),
    'history': Color(0xFF7C3AED),
    'bar_chart': Color(0xFF0891B2),
    'badge': kBrandTeal,
    'today': kBrandTeal,
    'hourglass': Color(0xFFD97706),
    'logout': Color(0xFF64748B),
  };

  static const _bgMap = <String, Color>{
    'qr_code_scanner': kBrandTealLight,
    'scan': kBrandTealLight,
    'people': Color(0xFFF0FDF4),
    'check_circle': Color(0xFFFFF7ED),
    'history': Color(0xFFFAF5FF),
    'bar_chart': kBrandTealLight,
    'badge': kBrandTealLight,
    'today': kBrandTealLight,
    'hourglass': Color(0xFFFEF3C7),
    'logout': Color(0xFFF8FAFC),
  };

  @override
  Widget build(BuildContext context) {
    final icon = _iconMap[item.iconKey] ?? Icons.widgets_rounded;
    final color = _colorMap[item.iconKey] ?? kBrandTeal;
    final bg = _bgMap[item.iconKey] ?? kBrandTealLight;

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
                color: const Color(0xFFDDE4F5), width: 0.5),
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

class _ErrorChip extends StatelessWidget {
  const _ErrorChip({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.red.shade400, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 12, color: Colors.red.shade600)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Retry',
                  style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}