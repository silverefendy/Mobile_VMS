import '../models/operation_models.dart';

abstract class OperationsRepository {
  Future<ScanOutcome> processScan({required String rawCode, required ScanAction action});
  /// Query status visitor dari rawCode QR — dipakai untuk auto-detect check-in/out
  Future<String> getVisitorStatus({required String rawCode});
  Future<List<VisitorRecord>> getActiveVisitors({String query = ''});
  Future<List<ApprovalRecord>> getPendingApprovals();
  Future<void> approve(String approvalId);
  Future<void> reject(String approvalId, {String? reason});
  Future<List<ActivityEvent>> getRecentActivity();
}
