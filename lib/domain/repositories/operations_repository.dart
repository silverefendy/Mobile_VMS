import '../models/operation_models.dart';

abstract class OperationsRepository {
  Future<ScanOutcome> processScan({required String rawCode, required ScanAction action});

  /// Determine whether a QR scan should check a visitor in or out.
  ///
  /// Implementations should prefer an active/open visit lookup over stale labels
  /// so a single scanner button can safely perform the correct operation.
  Future<ScanAction> determineVisitAction({required String rawCode});

  /// Query status visitor dari rawCode QR — dipakai untuk auto-detect check-in/out
  Future<String> getVisitorStatus({required String rawCode});
  Future<List<VisitorRecord>> getActiveVisitors({String query = ''});
  Future<List<ApprovalRecord>> getPendingApprovals();
  Future<void> approve(String approvalId);
  Future<void> reject(String approvalId, {String? reason});
  Future<List<ActivityEvent>> getRecentActivity();
}
