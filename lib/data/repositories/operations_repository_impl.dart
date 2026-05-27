import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../domain/models/operation_models.dart';
import '../../domain/repositories/operations_repository.dart';

class OperationsRepositoryImpl implements OperationsRepository {
  OperationsRepositoryImpl(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<ScanOutcome> processScan({required String rawCode, required ScanAction action}) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>('/api/method/visitor_management.mobile.process_scan', data: {
        'qr_code': rawCode,
        'action': action.name,
      });
      final message = response.data?['message'] as Map<String, dynamic>? ?? const {};
      final status = (message['status'] ?? 'unknown').toString();
      return ScanOutcome(
        type: _toOutcome(status),
        message: (message['message'] ?? 'Processed').toString(),
        referenceId: message['reference_id']?.toString(),
      );
    } on AppException catch (e) {
      if (e.statusCode == 401) return const ScanOutcome(type: ScanOutcomeType.unauthorized, message: 'Session expired');
      return const ScanOutcome(type: ScanOutcomeType.networkError, message: 'Network error, retry');
    }
  }

  ScanOutcomeType _toOutcome(String status) {
    switch (status) {
      case 'success': return ScanOutcomeType.success;
      case 'invalid': return ScanOutcomeType.invalid;
      case 'duplicate': return ScanOutcomeType.duplicate;
      case 'expired': return ScanOutcomeType.expired;
      case 'already_checked_in': return ScanOutcomeType.alreadyCheckedIn;
      case 'already_checked_out': return ScanOutcomeType.alreadyCheckedOut;
      default: return ScanOutcomeType.unknown;
    }
  }

  @override
  Future<List<VisitorRecord>> getActiveVisitors({String query = ''}) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/api/method/visitor_management.mobile.get_active_visitors', queryParameters: {'query': query});
    final list = (response.data?['message'] as List<dynamic>? ?? const []);
    return list.map((e) => VisitorRecord(
      id: e['id'].toString(),
      name: e['visitor_name'].toString(),
      host: e['host_name'].toString(),
      status: e['status'].toString(),
      checkInAt: e['check_in_time'].toString(),
      gate: e['gate']?.toString(),
    )).toList();
  }

  @override
  Future<List<ApprovalRecord>> getPendingApprovals() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/api/method/visitor_management.mobile.get_pending_approvals');
    final list = (response.data?['message'] as List<dynamic>? ?? const []);
    return list.map((e) => ApprovalRecord(
      id: e['id'].toString(),
      visitorName: e['visitor_name'].toString(),
      hostName: e['host_name'].toString(),
      purpose: e['purpose'].toString(),
      requestedAt: e['requested_at'].toString(),
    )).toList();
  }

  @override
  Future<void> approve(String approvalId) => _apiClient.post('/api/method/visitor_management.mobile.submit_approval', data: {'approval_id': approvalId, 'action': 'approve'});

  @override
  Future<void> reject(String approvalId, {String? reason}) => _apiClient.post('/api/method/visitor_management.mobile.submit_approval', data: {'approval_id': approvalId, 'action': 'reject', 'reason': reason});

  @override
  Future<List<ActivityEvent>> getRecentActivity() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/api/method/visitor_management.mobile.get_recent_activity');
    final list = (response.data?['message'] as List<dynamic>? ?? const []);
    return list.map((e) => ActivityEvent(
      id: e['id'].toString(),
      type: e['type'].toString(),
      message: e['message'].toString(),
      time: e['time'].toString(),
    )).toList();
  }
}
