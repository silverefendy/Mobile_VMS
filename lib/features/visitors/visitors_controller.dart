import 'package:flutter/foundation.dart';

import '../../domain/models/operation_models.dart';
import '../../domain/repositories/operations_repository.dart';

class VisitorsController extends ChangeNotifier {
  VisitorsController(this._repo);
  final OperationsRepository _repo;

  bool loading = false;
  String query = '';
  String? error;
  List<VisitorRecord> visitors = const [];

  Future<void> refresh({String? search}) async {
    loading = true;
    if (search != null) query = search;
    error = null;
    notifyListeners();
    try {
      visitors = await _repo.getActiveVisitors(query: query);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }
}
