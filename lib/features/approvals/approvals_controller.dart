import 'package:flutter/foundation.dart';

import '../../domain/models/operation_models.dart';
import '../../domain/repositories/operations_repository.dart';

class ApprovalsController extends ChangeNotifier {
  ApprovalsController(this._repo);
  final OperationsRepository _repo;

  bool loading = false;
  String? error;
  List<ApprovalRecord> items = const [];

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await _repo.getPendingApprovals();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> approve(String id) async {
    await _repo.approve(id);
    await refresh();
  }

  Future<void> reject(String id) async {
    await _repo.reject(id);
    await refresh();
  }
}
