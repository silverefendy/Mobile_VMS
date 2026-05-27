import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_vms/core/resilience/pending_operation_queue.dart';

void main() {
  test('queue enqueues and dequeues in order', () {
    final queue = PendingOperationQueue();
    queue.enqueue(PendingOperation(id: '1', payload: const {'v': 1}, createdAt: DateTime(2026)));
    queue.enqueue(PendingOperation(id: '2', payload: const {'v': 2}, createdAt: DateTime(2026)));
    expect(queue.length, 2);
    expect(queue.dequeue()?.id, '1');
    expect(queue.dequeue()?.id, '2');
  });
}
