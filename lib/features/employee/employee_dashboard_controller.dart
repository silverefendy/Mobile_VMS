import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../domain/models/employee_models.dart';

class EmployeeDashboardController extends ChangeNotifier {
  EmployeeDashboardController(this._apiClient);

  final ApiClient _apiClient;

  bool loadingDashboard = false;
  bool loadingInside = false;
  String? errorDashboard;
  String? errorInside;

  MyEmployeeDashboard? dashboard;
  EmployeesInsideResult? insideResult;

  bool get isManager => dashboard?.isManager ?? false;

  Future<void> refreshDashboard() async {
    if (loadingDashboard) return;
    loadingDashboard = true;
    errorDashboard = null;
    notifyListeners();

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/method/visitor_management.mobile_employee.get_my_employee_dashboard',
      );
      final msg = response.data?['message'] as Map<String, dynamic>?;
      if (msg != null) {
        dashboard = MyEmployeeDashboard.fromJson(msg);
      }
    } catch (e) {
      errorDashboard = e.toString();
    } finally {
      loadingDashboard = false;
      notifyListeners();
    }

    // Kalau manager, auto-load daftar karyawan di dalam area
    if (isManager && insideResult == null) {
      await refreshEmployeesInside();
    }
  }

  Future<void> refreshEmployeesInside() async {
    if (loadingInside) return;
    loadingInside = true;
    errorInside = null;
    notifyListeners();

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/method/visitor_management.mobile_employee.get_employees_inside',
      );
      final msg = response.data?['message'] as Map<String, dynamic>?;
      if (msg != null) {
        insideResult = EmployeesInsideResult.fromJson(msg);
      }
    } catch (e) {
      errorInside = e.toString();
    } finally {
      loadingInside = false;
      notifyListeners();
    }
  }
}
