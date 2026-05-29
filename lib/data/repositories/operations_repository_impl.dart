import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../domain/models/operation_models.dart';
import '../../domain/repositories/operations_repository.dart';

class OperationsRepositoryImpl implements OperationsRepository {
  OperationsRepositoryImpl(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<ScanResolution> resolveScanAction({required String rawCode}) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/method/visitor_management.mobile.resolve_scan_action',
        data: {'qr_code': rawCode},
      );
      final message = _messageMap(response.data);
      final visitor =
          _nestedMap(message, const ['visitor', 'visitor_info', 'visitorInfo']);
      final employee = _nestedMap(
          message, const ['employee', 'employee_info', 'employeeInfo']);
      final nextAction = _stringFrom(message, const [
        'next_action',
        'nextAction',
        'action',
      ]);

      if (nextAction.isEmpty) {
        throw AppException('Backend tidak mengirim next_action');
      }

      return ScanResolution(
        rawCode: rawCode,
        entityType: _entityType(_stringFrom(message, const [
          'entity_type',
          'entityType',
          'type',
        ])),
        currentStatus: _stringFrom(message, const [
          'current_status',
          'currentStatus',
          'status',
        ]),
        nextAction: nextAction,
        visitorName: _stringOrNullFrom([message, visitor], const [
          'visitor_name',
          'visitorName',
          'full_name',
          'fullName',
          'name',
        ]),
        company: _stringOrNullFrom([message, visitor], const [
          'company',
          'company_name',
          'companyName',
          'organization',
        ]),
        employeeName: _stringOrNullFrom([message, employee, visitor], const [
          'employee_name',
          'employeeName',
          'host_name',
          'hostName',
          'full_name',
          'fullName',
          'name',
        ]),
        referenceId: _stringOrNull(message, const [
          'reference_id',
          'referenceId',
          'id',
        ]),
      );
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Gagal membaca aksi scan dari backend');
    }
  }

  @override
  Future<ScanOutcome> executeScanAction(
      {required ScanResolution resolution}) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/method/visitor_management.mobile.execute_scan_action',
        data: {
          'qr_code': resolution.rawCode,
          'action': resolution.nextAction,
        },
      );
      final message = _messageMap(response.data);
      final status = _stringFrom(message, const ['status'], fallback: 'unknown');
      return ScanOutcome(
        type: _toOutcome(status),
        message: _stringFrom(message, const ['message'], fallback: 'Diproses'),
        referenceId:
            _stringOrNull(message, const ['reference_id', 'referenceId']),
      );
    } on AppException catch (e) {
      if (e.statusCode == 401) {
        return const ScanOutcome(
            type: ScanOutcomeType.unauthorized,
            message: 'Sesi habis, silakan login ulang');
      }
      return ScanOutcome(
        type: ScanOutcomeType.networkError,
        message:
            e.message.isEmpty ? 'Jaringan bermasalah, coba lagi' : e.message,
      );
    }
  }

  Map<String, dynamic> _messageMap(Map<String, dynamic>? data) {
    final message = data?['message'];
    if (message is Map<String, dynamic>) return message;
    if (data == null) return const {};
    return data;
  }

  String _stringFrom(
    Map<String, dynamic> payload,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = payload[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  String? _stringOrNull(Map<String, dynamic> payload, List<String> keys) {
    final value = _stringFrom(payload, keys);
    return value.isEmpty ? null : value;
  }

  String? _stringOrNullFrom(
    List<Map<String, dynamic>> payloads,
    List<String> keys,
  ) {
    for (final payload in payloads) {
      final value = _stringOrNull(payload, keys);
      if (value != null) return value;
    }
    return null;
  }

  Map<String, dynamic> _nestedMap(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = payload[key];
      if (value is Map<String, dynamic>) return value;
    }
    return const {};
  }

  ScanEntityType _entityType(String value) {
    switch (value.trim().toUpperCase()) {
      case 'VISITOR':
        return ScanEntityType.visitor;
      case 'EMPLOYEE':
        return ScanEntityType.employee;
      default:
        return ScanEntityType.unknown;
    }
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
