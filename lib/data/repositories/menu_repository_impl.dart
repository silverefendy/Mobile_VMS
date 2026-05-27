import '../../core/network/api_client.dart';
import '../../domain/models/menu_item.dart';
import '../../domain/repositories/menu_repository.dart';

class MenuRepositoryImpl implements MenuRepository {
  MenuRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<MenuItem>> fetchMenu() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/api/method/visitor_management.mobile.get_mobile_navigation');
    final msg = response.data?['message'];
    final rows = (msg is Map<String, dynamic> ? (msg['menu_items'] as List<dynamic>?) : (msg as List<dynamic>?)) ?? [];

    return rows
        .map(
          (e) => MenuItem(
            id: e['id'].toString(),
            label: e['label'].toString(),
            route: e['route'].toString(),
            iconKey: e['icon_key'].toString(),
            order: (e['order'] as num?)?.toInt() ?? 0,
            permissions: (e['permissions'] as List<dynamic>? ?? const []).map((x) => x.toString()).toList(),
            group: (e['group'] ?? 'Operations').toString(),
            featureFlag: e['feature_flag']?.toString(),
          ),
        )
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  @override
  Future<List<DashboardCard>> fetchDashboardCards() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/api/method/visitor_management.mobile.get_dashboard_cards');
    final rows = (response.data?['message'] as List<dynamic>? ?? const []);
    return rows
        .map((e) => DashboardCard(
              id: e['id'].toString(),
              title: e['title'].toString(),
              value: e['value'].toString(),
              iconKey: e['icon_key']?.toString() ?? 'dashboard',
              order: (e['order'] as num?)?.toInt() ?? 0,
              route: e['route']?.toString(),
              featureFlag: e['feature_flag']?.toString(),
            ))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  @override
  Future<Map<String, bool>> fetchFeatureFlags() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/api/method/visitor_management.mobile.get_feature_flags');
    final raw = (response.data?['message'] as Map<String, dynamic>? ?? const {});
    return raw.map((k, v) => MapEntry(k, v == true));
  }
}
