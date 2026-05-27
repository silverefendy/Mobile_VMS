import '../models/menu_item.dart';

abstract class MenuRepository {
  Future<List<MenuItem>> fetchMenu();
  Future<List<DashboardCard>> fetchDashboardCards();
  Future<Map<String, bool>> fetchFeatureFlags();
}
