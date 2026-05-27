import 'package:flutter/foundation.dart';

import '../../core/auth/auth_controller.dart';
import '../../domain/models/menu_item.dart';
import '../../domain/repositories/menu_repository.dart';

class MenuController extends ChangeNotifier {
  MenuController(this._menuRepository);

  final MenuRepository _menuRepository;
  List<MenuItem> items = const [];

  Future<void> bindAuth(AuthController authController) async {
    if (authController.status == AuthStatus.authenticated) {
      await refresh();
    } else {
      items = const [];
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    items = await _menuRepository.fetchMenu();
    notifyListeners();
  }
}
