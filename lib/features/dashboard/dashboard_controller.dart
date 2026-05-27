import 'package:flutter/foundation.dart';

import '../../domain/models/menu_item.dart';
import '../../domain/repositories/menu_repository.dart';

class DashboardController extends ChangeNotifier {
  DashboardController(this._menuRepository);

  final MenuRepository _menuRepository;
  bool loading = false;
  String? error;
  List<DashboardCard> cards = const [];

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      cards = await _menuRepository.fetchDashboardCards();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }
}
