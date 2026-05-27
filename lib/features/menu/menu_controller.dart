import 'package:flutter/foundation.dart';

import '../../core/auth/auth_controller.dart';
import '../../domain/models/menu_item.dart';
import '../../domain/repositories/menu_repository.dart';

class MenuController extends ChangeNotifier {
  MenuController(this._menuRepository);

  final MenuRepository _menuRepository;
  List<MenuItem> items = const [];
  Map<String, bool> featureFlags = const {};

  Future<void> bindAuth(AuthController authController) async {
    if (authController.status == AuthStatus.authenticated) {
      await refresh();
    } else {
      items = const [];
      featureFlags = const {};
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final flags = await _menuRepository.fetchFeatureFlags();
    final fetched = await _menuRepository.fetchMenu();
    featureFlags = flags;
    items = fetched.where((m) => m.featureFlag == null || (flags[m.featureFlag!] ?? true)).toList();
    notifyListeners();
  }

  bool can(String capability) => featureFlags[capability] ?? false;
}
