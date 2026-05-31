import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/employee_models.dart';
import 'employee_dashboard_controller.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _tabInit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeDashboardController>().refreshDashboard();
    });
  }

  TabController _getTabController(bool isManager) {
    final count = isManager ? 3 : 2;
    if (!_tabInit || _tabController.length != count) {
      if (_tabInit) _tabController.dispose();
      _tabController = TabController(length: count, vsync: this);
      _tabInit = true;
    }
    return _tabController;
  }

  @override
  void dispose() {
    if (_tabInit) _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EmployeeDashboardController>();
    final tc = _getTabController(vm.isManager);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            floating: true,
            snap: true,
            title: const Text('Employee Dashboard',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: vm.refreshDashboard,
                tooltip: 'Refresh',
              ),
            ],
            bottom: TabBar(
              controller: tc,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.white,
              tabs: [
                const Tab(text: 'Status Saya'),
                const Tab(text: 'Riwayat'),
                if (vm.isManager) const Tab(text: 'Di Area'),
              ],
            ),
          ),
        ],
        body: vm.loadingDashboard && vm.dashboard == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: tc,
                children: [
                  _MyStatusTab(vm: vm),
                  _HistoryTab(vm: vm),
                  if (vm.isManager) _EmployeesInsideTab(vm: vm),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1 — Status saya
// ---------------------------------------------------------------------------

class _MyStatusTab extends StatelessWidget {
  const _MyStatusTab({required this.vm});
  final EmployeeDashboardController vm;

  @override
  Widget build(BuildContext context) {
    final dash = vm.dashboard;
    if (dash == null) return const Center(child: Text('Memuat data...'));
    if (dash.warning != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: _WarningCard(message: dash.warning!),
      );
    }
    return RefreshIndicator(
      onRefresh: vm.refreshDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileCard(dash: dash),
          const SizedBox(height: 16),
          _CurrentStatusCard(dash: dash),
          const SizedBox(height: 16),
          _TodaySummaryCards(summary: dash.todaySummary),
          if (dash.recentEntries.isNotEmpty) ...[  
            const SizedBox(height: 16),
            const _SectionHeader(title: 'Entry Terbaru'),
            const SizedBox(height: 8),
            ...dash.recentEntries.take(3).map((e) => _EntryCard(entry: e)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 2 — Riwayat
// ---------------------------------------------------------------------------

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.vm});
  final EmployeeDashboardController vm;

  @override
  Widget build(BuildContext context) {
    final entries = vm.dashboard?.recentEntries ?? [];
    if (entries.isEmpty) {
      return const Center(
        child: Text('Belum ada riwayat entry.', style: TextStyle(color: Colors.grey)),
      );
    }
    return RefreshIndicator(
      onRefresh: vm.refreshDashboard,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (_, i) => _EntryCard(entry: entries[i]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 3 — Karyawan di area (manager only)
// ---------------------------------------------------------------------------

class _EmployeesInsideTab extends StatelessWidget {
  const _EmployeesInsideTab({required this.vm});
  final EmployeeDashboardController vm;

  @override
  Widget build(BuildContext context) {
    if (vm.loadingInside && vm.insideResult == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final result = vm.insideResult;
    if (result == null || !result.canAccess) {
      return Center(
        child: Text(result?.message ?? 'Tidak ada akses.',
            style: const TextStyle(color: Colors.grey)),
      );
    }
    return RefreshIndicator(
      onRefresh: vm.refreshEmployeesInside,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InsideSummaryBar(result: result),
          const SizedBox(height: 16),
          if (result.employees.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Tidak ada karyawan di dalam area saat ini.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else ...[  
            const _SectionHeader(title: 'Karyawan di Dalam Area'),
            const SizedBox(height: 8),
            ...result.employees.map((e) => _EmployeeInsideCard(record: e)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable Widgets
// ---------------------------------------------------------------------------

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.dash});
  final MyEmployeeDashboard dash;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A8A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Text(
              (dash.employeeName ?? 'E').isNotEmpty
                  ? (dash.employeeName!)[0].toUpperCase()
                  : 'E',
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dash.employeeName ?? '-',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(dash.designation ?? dash.department ?? '-',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                if (dash.isManager)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Manager',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentStatusCard extends StatelessWidget {
  const _CurrentStatusCard({required this.dash});
  final MyEmployeeDashboard dash;

  @override
  Widget build(BuildContext context) {
    final inside = dash.todaySummary.currentlyInside;
    final active = dash.activeEntry;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: inside ? Colors.green.shade200 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                inside ? Icons.location_on_rounded : Icons.location_off_rounded,
                color: inside ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('Status Sekarang',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: inside ? Colors.green.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: inside ? Colors.green.shade300 : Colors.grey.shade300),
            ),
            child: Text(
              inside ? 'Di Dalam Area' : 'Di Luar Area',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: inside ? Colors.green.shade700 : Colors.grey.shade600,
              ),
            ),
          ),
          if (active != null) ...[  
            const SizedBox(height: 10),
            _InfoRow(label: 'Status Entry', value: active.status),
            _InfoRow(label: 'Check In', value: active.checkInTime),
            _InfoRow(label: 'Keperluan', value: active.purpose),
          ],
        ],
      ),
    );
  }
}

class _TodaySummaryCards extends StatelessWidget {
  const _TodaySummaryCards({required this.summary});
  final EmployeeTodaySummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            label: 'Entry Hari Ini',
            value: '${summary.totalEntries}',
            icon: Icons.today_rounded,
            color: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: 'Terakhir Masuk',
            value: summary.lastCheckIn ?? '-',
            icon: Icons.login_rounded,
            color: Colors.green,
            small: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: 'Terakhir Keluar',
            value: summary.lastCheckOut ?? '-',
            icon: Icons.logout_rounded,
            color: Colors.grey,
            small: true,
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.small = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE4F5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                fontSize: small ? 12 : 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E3A8A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              maxLines: 2),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});
  final EmployeeEntryRecord entry;

  Color get _statusColor {
    if (entry.isActive) return Colors.orange;
    if (entry.isCompleted) return Colors.purple;
    if (entry.isCheckedOut) return Colors.green;
    if (entry.isRejected) return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE4F5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.id,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A8A))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(entry.status,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoRow(label: 'Keperluan', value: entry.purpose),
          _InfoRow(label: 'Masuk', value: entry.checkInTime),
          if (entry.checkOutTime != '-')
            _InfoRow(label: 'Keluar', value: entry.checkOutTime),
        ],
      ),
    );
  }
}

class _EmployeeInsideCard extends StatelessWidget {
  const _EmployeeInsideCard({required this.record});
  final EmployeeInsideRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: record.isPending ? Colors.orange.shade200 : const Color(0xFFDDE4F5),
          width: record.isPending ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor:
                record.isPending ? Colors.orange.shade50 : Colors.blue.shade50,
            child: Text(
              record.employeeName.isNotEmpty
                  ? record.employeeName[0].toUpperCase()
                  : 'K',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: record.isPending
                    ? Colors.orange.shade700
                    : const Color(0xFF1E3A8A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.employeeName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${record.department} \u2022 ${record.checkInTime}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (record.purpose != '-')
                  Text(record.purpose,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: record.isPending
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: record.isPending
                          ? Colors.orange.shade300
                          : Colors.green.shade300),
                ),
                child: Text(
                  record.isPending ? 'Menunggu' : 'Di Dalam',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: record.isPending
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(record.durationLabel,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsideSummaryBar extends StatelessWidget {
  const _InsideSummaryBar({required this.result});
  final EmployeesInsideResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A8A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(label: 'Total', value: '${result.total}', color: Colors.white),
          _StatChip(
              label: 'Menunggu',
              value: '${result.pendingApproval}',
              color: Colors.amber),
          _StatChip(
              label: 'Di Dalam',
              value: '${result.approvedInside}',
              color: Colors.greenAccent),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E3A8A),
            letterSpacing: 0.5));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style:
                    TextStyle(color: Colors.amber.shade900, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
