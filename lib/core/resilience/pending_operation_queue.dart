import 'dart:collection';

class PendingOperation {
  const PendingOperation({required this.id, required this.payload, required this.createdAt, this.attempts = 0});
  final String id;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;

  PendingOperation bump() => PendingOperation(id: id, payload: payload, createdAt: createdAt, attempts: attempts + 1);
}

class PendingOperationQueue {
  final Queue<PendingOperation> _queue = Queue<PendingOperation>();

  int get length => _queue.length;
  bool get isEmpty => _queue.isEmpty;

  void enqueue(PendingOperation operation) => _queue.add(operation);
  PendingOperation? peek() => _queue.isEmpty ? null : _queue.first;
  PendingOperation? dequeue() => _queue.isEmpty ? null : _queue.removeFirst();
}
