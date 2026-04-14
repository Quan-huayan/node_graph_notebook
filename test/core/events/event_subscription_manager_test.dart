import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/cqrs/commands/events/event_subscription_manager.dart';

void main() {
  group('EventSubscriptionManager', () {
    late EventSubscriptionManager manager;

    setUp(() {
      manager = EventSubscriptionManager('TestManager');
    });

    tearDown(() {
      manager.dispose();
    });

    test('应该跟踪订阅', () {
      final controller = StreamController<int>();
      final subscription = controller.stream.listen((_) {});

      manager.track('test', subscription);

      expect(manager.has('test'), true);
      expect(manager.count, 1);

      controller.close();
    });

    test('跟踪相同键时应该取消现有订阅', () {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();

      final sub1 = controller1.stream.listen((_) {});
      final sub2 = controller2.stream.listen((_) {});

      manager.track('test', sub1);
      expect(manager.has('test'), true);

      manager.track('test', sub2);
      expect(manager.has('test'), true);

      // 两个订阅都应该被跟踪
      expect(manager.count, 1);

      controller1.close();
      controller2.close();
    });

    test('应该取消特定订阅', () async {
      final controller = StreamController<int>();
      final subscription = controller.stream.listen((_) {});

      manager.track('test', subscription);
      expect(manager.has('test'), true);

      manager.cancel('test');
      expect(manager.has('test'), false);

      await controller.close();
    });

    test('应该在dispose时取消所有订阅', () {
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

    test('应该优雅地处理取消错误', () {
      final controller = StreamController<int>();
      final subscription = controller.stream.listen((_) {});

      manager.track('test', subscription);

      // 手动取消订阅以模拟错误
      subscription.cancel();

      // dispose不应该抛出异常，即使订阅已经被取消
      expect(() => manager.dispose(), returnsNormally);

      controller.close();
    });

    test('应该返回所有键', () {
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

    test('应该断言非空键', () {
      final controller = StreamController<int>();
      final subscription = controller.stream.listen((_) {});

      expect(
        () => manager.track('', subscription),
        throwsAssertionError,
      );

      controller.close();
    });

    test('应该断言非空ownerId', () {
      expect(
        () => EventSubscriptionManager(''),
        throwsAssertionError,
      );
    });

    test('应该处理订阅错误', () async {
      final controller = StreamController<int>();

      manager.track(
        'test',
        controller.stream.listen(
          (_) {},
          onError: (error) {
            // 错误处理程序防止未捕获的异常
            expect(error.toString(), contains('Test error'));
          },
        ),
      );

      // 触发错误 - 应该被onError处理程序捕获
      controller.addError(Exception('Test error'));

      // 给错误处理一些时间
      await Future.delayed(const Duration(milliseconds: 50));

      await controller.close();
    });
  });

  group('EventSubscriptionManager.toString', () {
    test('应该返回格式化字符串', () {
      final manager = EventSubscriptionManager('TestManager');
      final str = manager.toString();

      expect(str, contains('TestManager'));
      expect(str, contains('EventSubscriptionManager'));

      manager.dispose();
    });

    test('toString应该包含订阅键', () {
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
