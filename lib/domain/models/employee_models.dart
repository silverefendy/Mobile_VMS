// Domain models untuk Employee Dashboard
// File: lib/domain/models/employee_models.dart

/// Summary statistik employee hari ini
class EmployeeTodaySummary {
  const EmployeeTodaySummary({
    required this.totalEntries,
    required this.currentlyInside,
    this.lastCheckIn,
    this.lastCheckOut,
  });

  final int totalEntries;
  final bool currentlyInside;
  final String? lastCheckIn;
  final String? lastCheckOut;

  factory EmployeeTodaySummary.fromJson(Map<String, dynamic> json) {
    return EmployeeTodaySummary(
      totalEntries: (json['total_entries'] as num?)?.toInt() ?? 0,
      currentlyInside: json['currently_inside'] == true,
      lastCheckIn: json['last_check_in'] as String?,
      lastCheckOut: json['last_check_out'] as String?,
    );
  }

  static const empty = EmployeeTodaySummary(
    totalEntries: 0,
    currentlyInside: false,
  );
}

/// Satu record Employee Entry Request
class EmployeeEntryRecord {
  const EmployeeEntryRecord({
    required this.id,
    required this.status,
    required this.checkInTime,
    required this.checkOutTime,
    required this.approvedAt,
    required this.purpose,
  });

  final String id;
  final String status;
  final String checkInTime;
  final String checkOutTime;
  final String approvedAt;
  final String purpose;

  factory EmployeeEntryRecord.fromJson(Map<String, dynamic> json) {
    return EmployeeEntryRecord(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      checkInTime: json['check_in_time']?.toString() ?? '-',
      checkOutTime: json['check_out_time']?.toString() ?? '-',
      approvedAt: json['approved_at']?.toString() ?? '-',
      purpose: json['purpose']?.toString() ?? '-',
    );
  }

  bool get isActive => status == 'Pending Approval' || status == 'Approved';
  bool get isCompleted => status == 'Completed';
  bool get isCheckedOut => status == 'Checked Out';
  bool get isRejected => status == 'Rejected';
}

/// Data dashboard pribadi employee
class MyEmployeeDashboard {
  const MyEmployeeDashboard({
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.designation,
    required this.isManager,
    required this.todaySummary,
    required this.recentEntries,
    this.activeEntry,
    this.warning,
    this.image,
  });

  final String? employeeId;
  final String? employeeName;
  final String? department;
  final String? designation;
  final bool isManager;
  final EmployeeTodaySummary todaySummary;
  final List<EmployeeEntryRecord> recentEntries;
  final EmployeeEntryRecord? activeEntry;
  final String? warning;
  final String? image;

  factory MyEmployeeDashboard.fromJson(Map<String, dynamic> json) {
    final activeJson = json['active_entry'] as Map<String, dynamic>?;
    final recentList = json['recent_entries'] as List<dynamic>? ?? [];
    final summaryJson = json['today_summary'] as Map<String, dynamic>? ?? {};
    return MyEmployeeDashboard(
      employeeId: json['employee_id'] as String?,
      employeeName: json['employee_name'] as String?,
      department: json['department'] as String?,
      designation: json['designation'] as String?,
      isManager: json['is_manager'] == true,
      warning: json['warning'] as String?,
      image: json['image'] as String?,
      todaySummary: summaryJson.isNotEmpty
          ? EmployeeTodaySummary.fromJson(summaryJson)
          : EmployeeTodaySummary.empty,
      activeEntry:
          activeJson != null ? EmployeeEntryRecord.fromJson(activeJson) : null,
      recentEntries: recentList
          .map((e) => EmployeeEntryRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Satu baris karyawan yang sedang di dalam area (manager view)
class EmployeeInsideRecord {
  const EmployeeInsideRecord({
    required this.entryId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.status,
    required this.checkInTime,
    required this.purpose,
    this.durationMinutes,
    this.approvedAt,
  });

  final String entryId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String status;
  final String checkInTime;
  final String purpose;
  final int? durationMinutes;
  final String? approvedAt;

  factory EmployeeInsideRecord.fromJson(Map<String, dynamic> json) {
    return EmployeeInsideRecord(
      entryId: json['entry_id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      employeeName: json['employee_name']?.toString() ?? '',
      department: json['department']?.toString() ?? '-',
      status: json['status']?.toString() ?? '',
      checkInTime: json['check_in_time']?.toString() ?? '-',
      purpose: json['purpose']?.toString() ?? '-',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      approvedAt: json['approved_at'] as String?,
    );
  }

  /// Format durasi "2j 30m"
  String get durationLabel {
    if (durationMinutes == null) return '-';
    final h = durationMinutes! ~/ 60;
    final m = durationMinutes! % 60;
    if (h == 0) return '${m}m';
    return '${h}j ${m}m';
  }

  bool get isPending => status == 'Pending Approval';
}

/// Hasil get_employees_inside()
class EmployeesInsideResult {
  const EmployeesInsideResult({
    required this.canAccess,
    required this.total,
    required this.pendingApproval,
    required this.approvedInside,
    required this.employees,
    this.message,
  });

  final bool canAccess;
  final int total;
  final int pendingApproval;
  final int approvedInside;
  final List<EmployeeInsideRecord> employees;
  final String? message;

  factory EmployeesInsideResult.fromJson(Map<String, dynamic> json) {
    final list = json['employees'] as List<dynamic>? ?? [];
    return EmployeesInsideResult(
      canAccess: json['can_access'] == true,
      total: (json['total'] as num?)?.toInt() ?? 0,
      pendingApproval: (json['pending_approval'] as num?)?.toInt() ?? 0,
      approvedInside: (json['approved_inside'] as num?)?.toInt() ?? 0,
      message: json['message'] as String?,
      employees: list
          .map((e) => EmployeeInsideRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static const noAccess = EmployeesInsideResult(
    canAccess: false,
    total: 0,
    pendingApproval: 0,
    approvedInside: 0,
    employees: [],
  );
}
