import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/events/event_subscription_manager.dart';

void main() {
  group('EventSubscriptionManager', () {
    late EventSubscriptionManager manager;

    setUp(() {
      manager = EventSubscriptionManager('TestManager');
    });

    tearDown(() {
      manager.dispose();
    });

    test('should track subscription', () {
      final controller = StreamController<int>();
      final subscription = controller.stream.listen((_) {});

      manager.track('test', subscription);

      expect(manager.has('test'), true);
      expect(manager.count, 1);

      controller.close();
    });

    test('should cancel existing subscription when tracking same key', () {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();

      final sub1 = controller1.stream.listen((_) {});
      final sub2 = controller2.stream.listen((_) {});

      manager.track('test', sub1);
      expect(manager.has('test'), true);

      manager.track('test', sub2);
      expect(manager.has('test'), true);

      // Both subscriptions should be tracked
      expect(manager.count, 1);

      controller1.close();
      controller2.close();
    });

    test('should cancel specific subscription', () async {
      final controller = StreamController<int>();
      final subscription = controller.stream.listen((_) {});

      manager.track('test', subscription);
      expect(manager.has('test'), true);

      manager.cancel('test');
      expect(manager.has('test'), false);

      await controller.close();
    });

    test('should cancel all subscriptions on dispose', () {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();

      manager..track('test1', controller1.stream.listen((_) {}))
      ..track('test2', controller2.stream.listen((_) {}));

      expect(manager.count, 2);

      manager.dispose();

      expect(manager.count, 0);
      expect(manager.has('test1'), false);
      expect(manager.has('test2'), false);

      controller1.close();
      controller2.close();
    });

    test('should handle cancellation errors gracefully', () {
      final controller = StreamController<int>();
      final subscription = controller.stream.listen((_) {});

      manager.track('test', subscription);

      // Manually cancel the subscription to simulate error
      subscription.cancel();

      // dispose should not throw even though subscription is already cancelled
      expect(() => manager.dispose(), returnsNormally);

      controller.close();
    });

    test('should return all keys', () {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();
      final controller3 = StreamController<int>();

      manager..track('test1', controller1.stream.listen((_) {}))
      ..track('test2', controller2.stream.listen((_) {}))
      ..track('test3', controller3.stream.listen((_) {}));

      final keys = manager.keys;
      expect(keys.length, 3);
      expect(keys, contains('test1'));
      expect(keys, contains('test2'));
      expect(keys, contains('test3'));

      controller1.close();
      controller2.close();
      controller3.close();
    });

    test('should assert non-empty key', () {
      final controller = StreamController<int>();
      final subscription = controller.stream.listen((_) {});

      expect(
        () => manager.track('', subscription),
        throwsAssertionError,
      );

      controller.close();
    });

    test('should assert non-empty ownerId', () {
      expect(
        () => EventSubscriptionManager(''),
        throwsAssertionError,
      );
    });

    test('should handle subscription errors', () async {
      final controller = StreamController<int>();

      manager.track(
        'test',
        controller.stream.listen(
          (_) {},
          onError: (error) {
            // Error handler prevents uncaught exceptions
            expect(error.toString(), contains('Test error'));
          },
        ),
      );

      // Trigger error - should be caught by onError handler
      controller.addError(Exception('Test error'));

      // Give time for error to be processed
      await Future.delayed(const Duration(milliseconds: 50));

      await controller.close();
    });
  });

  group('EventSubscriptionManager.toString', () {
    test('should return formatted string', () {
      final manager = EventSubscriptionManager('TestManager');
      final str = manager.toString();

      expect(str, contains('TestManager'));
      expect(str, contains('EventSubscriptionManager'));

      manager.dispose();
    });

    test('should include subscription keys in toString', () {
      final manager = EventSubscriptionManager('TestManager');
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();

      manager..track('test1', controller1.stream.listen((_) {}))
      ..track('test2', controller2.stream.listen((_) {}));

      final str = manager.toString();
      expect(str, contains('test1'));
      expect(str, contains('test2'));

      controller1.close();
      controller2.close();
      manager.dispose();
    });
  });
}
