import '../models/operation_models.dart';

abstract class OperationsRepository {
  Future<ScanResolution> resolveScanAction({required String rawCode});

  Future<ScanOutcome> executeScanAction({required ScanResolution resolution});

  /// Query status visitor dari rawCode QR — dipakai untuk auto-detect check-in/out
  Future<String> getVisitorStatus({required String rawCode});
  Future<List<VisitorRecord>> getActiveVisitors({String query = ''});
  Future<List<ApprovalRecord>> getPendingApprovals();
  Future<void> approve(String approvalId);
  Future<void> reject(String approvalId, {String? reason});
  Future<List<ActivityEvent>> getRecentActivity();
}
