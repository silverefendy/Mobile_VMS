import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../domain/models/operation_models.dart';
import '../../domain/repositories/operations_repository.dart';

class OperationsRepositoryImpl implements OperationsRepository {
  OperationsRepositoryImpl(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<ScanOutcome> processScan(
      {required String rawCode, required ScanAction action}) async {
    try {
      final result = await _postScan(rawCode: rawCode, action: action.name);
      final shouldRetryWithBackendAlias =
          (result.type == ScanOutcomeType.invalid ||
                  result.type == ScanOutcomeType.unknown) &&
              result.message.toLowerCase().contains('action');
      if (shouldRetryWithBackendAlias) {
        return _postScan(rawCode: rawCode, action: _actionApiValue(action));
      }
      return result;
    } on AppException catch (e) {
      if (e.statusCode == 401) {
        return const ScanOutcome(
            type: ScanOutcomeType.unauthorized,
            message: 'Sesi habis, silakan login ulang');
      }
      return const ScanOutcome(
          type: ScanOutcomeType.networkError,
          message: 'Jaringan bermasalah, coba lagi');
    }
  }

  Future<ScanOutcome> _postScan({
    required String rawCode,
    required String action,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/method/visitor_management.mobile.process_scan',
      data: {'qr_code': rawCode, 'action': action},
    );
    final message =
        response.data?['message'] as Map<String, dynamic>? ?? const {};
    final status = (message['status'] ?? 'unknown').toString();
    return ScanOutcome(
      type: _toOutcome(status),
      message: (message['message'] ?? 'Diproses').toString(),
      referenceId: message['reference_id']?.toString(),
    );
  }

  String _actionApiValue(ScanAction action) {
    switch (action) {
      case ScanAction.checkIn:
        return 'check_in';
      case ScanAction.checkOut:
        return 'check_out';
      case ScanAction.employeeEntry:
        return 'employee_entry';
    }
  }


  @override
  Future<ScanAction> determineVisitAction({required String rawCode}) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/method/visitor_management.visitor_management.api.get_visitor_by_qr',
        queryParameters: {'qr_data': rawCode},
      );
      final msg = response.data?['message'];
      if (msg is Map<String, dynamic>) {
        return _hasActiveVisit(msg) ? ScanAction.checkOut : ScanAction.checkIn;
      }
    } catch (_) {
      // Let the normal process_scan endpoint surface invalid/expired/network
      // errors; defaulting to check-in keeps the scanner recoverable.
    }
    return ScanAction.checkIn;
  }

  bool _hasActiveVisit(Map<String, dynamic> payload) {
    final activeVisit = payload['active_visit'] ??
        payload['activeVisit'] ??
        payload['visit'] ??
        payload['current_visit'] ??
        payload['currentVisit'];
    if (activeVisit is Map<String, dynamic> && activeVisit.isNotEmpty) {
      final checkout = (activeVisit['check_out_time'] ??
              activeVisit['checkout_time'] ??
              activeVisit['checked_out_at'])
          ?.toString()
          .trim();
      if (checkout == null || checkout.isEmpty) return true;
    }
    if (activeVisit is List && activeVisit.isNotEmpty) return true;
    if (payload['has_active_visit'] == true || payload['is_checked_in'] == true) {
      return true;
    }

    final rawStatus = (payload['status'] ?? payload['visit_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    const activeStatuses = {
      'checked in',
      'check in',
      'active',
      'open',
      'on site',
      'onsite',
      'in progress',
      'arrived',
    };
    return activeStatuses.contains(rawStatus);
  }

  @override
  Future<String> getVisitorStatus({required String rawCode}) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/method/visitor_management.visitor_management.api.get_visitor_by_qr',
        queryParameters: {'qr_data': rawCode},
      );
      final msg = response.data?['message'];
      if (msg is Map<String, dynamic>) {
        return (msg['status'] ?? '').toString();
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  ScanOutcomeType _toOutcome(String status) {
    switch (status.trim().toLowerCase()) {
      case 'success':
        return ScanOutcomeType.success;
      case 'invalid':
        return ScanOutcomeType.invalid;
      case 'duplicate':
        return ScanOutcomeType.duplicate;
      case 'expired':
        return ScanOutcomeType.expired;
      case 'already_checked_in':
        return ScanOutcomeType.alreadyCheckedIn;
      case 'already_checked_out':
        return ScanOutcomeType.alreadyCheckedOut;
      default:
        return ScanOutcomeType.unknown;
    }
  }

  @override
  Future<List<VisitorRecord>> getActiveVisitors({String query = ''}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/method/visitor_management.mobile.get_active_visitors',
      queryParameters: {'query': query},
    );
    final list =
        (response.data?['message'] as List<dynamic>? ?? const []);
    return list
        .map((e) => VisitorRecord(
              id: e['id'].toString(),
              name: e['visitor_name'].toString(),
              host: e['host_name'].toString(),
              status: e['status'].toString(),
              checkInAt: e['check_in_time'].toString(),
              gate: e['gate']?.toString(),
            ))
        .toList();
  }

  @override
  Future<List<ApprovalRecord>> getPendingApprovals() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/method/visitor_management.mobile.get_pending_approvals',
    );
    final list =
        (response.data?['message'] as List<dynamic>? ?? const []);
    return list
        .map((e) => ApprovalRecord(
              id: e['id'].toString(),
              visitorName: e['visitor_name'].toString(),
              hostName: e['host_name'].toString(),
              purpose: e['purpose'].toString(),
              requestedAt: e['requested_at'].toString(),
            ))
        .toList();
  }

  @override
  Future<void> approve(String approvalId) => _apiClient.post(
        '/api/method/visitor_management.mobile.submit_approval',
        data: {'approval_id': approvalId, 'action': 'approve'},
      );

  @override
  Future<void> reject(String approvalId, {String? reason}) =>
      _apiClient.post(
        '/api/method/visitor_management.mobile.submit_approval',
        data: {
          'approval_id': approvalId,
          'action': 'reject',
          'reason': reason
        },
      );

  @override
  Future<List<ActivityEvent>> getRecentActivity() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/method/visitor_management.mobile.get_recent_activity',
    );
    final list =
        (response.data?['message'] as List<dynamic>? ?? const []);
    return list
        .map((e) => ActivityEvent(
              id: e['id'].toString(),
              type: e['type'].toString(),
              message: e['message'].toString(),
              time: e['time'].toString(),
            ))
        .toList();
  }
}
