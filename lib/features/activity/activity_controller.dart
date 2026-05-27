import 'package:flutter/foundation.dart';

import '../../domain/models/operation_models.dart';
import '../../domain/repositories/operations_repository.dart';

class ActivityController extends ChangeNotifier {
  ActivityController(this._repo);
  final OperationsRepository _repo;

  bool loading = false;
  List<ActivityEvent> events = const [];

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    events = await _repo.getRecentActivity();
    loading = false;
    notifyListeners();
  }
}
