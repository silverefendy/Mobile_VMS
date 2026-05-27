import '../models/operation_models.dart';

abstract class OperationsRepository {
  Future<ScanOutcome> processScan({required String rawCode, required ScanAction action});
  Future<List<VisitorRecord>> getActiveVisitors({String query = ''});
  Future<List<ApprovalRecord>> getPendingApprovals();
  Future<void> approve(String approvalId);
  Future<void> reject(String approvalId, {String? reason});
  Future<List<ActivityEvent>> getRecentActivity();
}
