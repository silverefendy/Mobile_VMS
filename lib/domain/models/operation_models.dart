enum ScanOutcomeType { success, invalid, duplicate, expired, alreadyCheckedIn, alreadyCheckedOut, networkError, unauthorized, unknown }

enum ScanEntityType { visitor, employee, unknown }

class ScanResolution {
  const ScanResolution({
    required this.rawCode,
    required this.entityType,
    required this.currentStatus,
    required this.nextAction,
    this.visitorName,
    this.company,
    this.employeeName,
    this.referenceId,
  });

  final String rawCode;
  final ScanEntityType entityType;
  final String currentStatus;
  final String nextAction;
  final String? visitorName;
  final String? company;
  final String? employeeName;
  final String? referenceId;

  bool get isVisitor => entityType == ScanEntityType.visitor;
  bool get isEmployee => entityType == ScanEntityType.employee;
}

class ScanOutcome {
  const ScanOutcome({required this.type, required this.message, this.referenceId});
  final ScanOutcomeType type;
  final String message;
  final String? referenceId;
}

class VisitorRecord {
  const VisitorRecord({required this.id, required this.name, required this.host, required this.status, required this.checkInAt, this.gate});
  final String id;
  final String name;
  final String host;
  final String status;
  final String checkInAt;
  final String? gate;
}

class ApprovalRecord {
  const ApprovalRecord({required this.id, required this.visitorName, required this.hostName, required this.purpose, required this.requestedAt});
  final String id;
  final String visitorName;
  final String hostName;
  final String purpose;
  final String requestedAt;
}

class ActivityEvent {
  const ActivityEvent({required this.id, required this.type, required this.message, required this.time});
  final String id;
  final String type;
  final String message;
  final String time;
}
