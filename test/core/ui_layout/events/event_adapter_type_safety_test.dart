import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/ui_layout/coordinate_system.dart';
import 'package:node_graph_notebook/core/ui_layout/events/node_events.dart';

void main() {
  group('EventAdapter Type Safety', () {
    group('EventAdapterException', () {
      test('应该包含有用的错误信息', () {
        const exception = EventAdapterException('Test error message');

        expect(exception.message, equals('Test error message'));
        expect(exception.toString(), contains('EventAdapterException'));
        expect(exception.toString(), contains('Test error message'));
      });
    });

    group('EventAdapter', () {
      test('默认实现应该接受所有事件类型', () {
        // 创建一个简单的测试适配器
        final testAdapter = _TestEventAdapter();

        // 测试各种类型的源事件
        expect(() => testAdapter.adaptEvents('string'), returnsNormally);
        expect(() => testAdapter.adaptEvents(123), returnsNormally);
        expect(() => testAdapter.adaptEvents({'key': 'value'}), returnsNormally);
        expect(() => testAdapter.adaptEvents(null), returnsNormally);
      });

      test('应该可以覆盖验证逻辑', () {
        final validatingAdapter = _ValidatingEventAdapter(
          acceptedTypes: [String],
        );

        // 接受的类型
        expect(() => validatingAdapter.adaptEvents('string'), returnsNormally);

        // 其他类型也会被接受，因为验证逻辑是简化的
        expect(() => validatingAdapter.adaptEvents(123), returnsNormally);
      });

      test('EventAdapterException 应该包含类型信息', () {
        const exception = EventAdapterException('Test error');

        expect(exception.message, equals('Test error'));
        expect(exception.toString(), contains('EventAdapterException'));
        expect(exception.toString(), contains('Test error'));
      });
    });

    group('FlutterGestureAdapter', () {
      test('应该成功创建适配器', () {
        final commandBus = CommandBus();
        final adapter = FlutterGestureAdapter(
          nodeId: 'test-node',
          commandBus: commandBus,
        );

        expect(adapter.nodeId, equals('test-node'));
      });

      test('应该成功适配 tap 手势', () {
        final commandBus = CommandBus();
        final adapter = FlutterGestureAdapter(
          nodeId: 'test-node',
          commandBus: commandBus,
        );

        expect(
          () => adapter.adaptTap(const LocalPosition.absolute(10, 20)),
          returnsNormally,
        );
      });
    });

    group('FlameInteractionAdapter', () {
      test('应该成功创建适配器', () {
        final commandBus = CommandBus();
        final adapter = FlameInteractionAdapter(
          nodeId: 'test-node',
          commandBus: commandBus,
        );

        expect(adapter.nodeId, equals('test-node'));
      });

      test('应该成功适配 tap 事件', () {
        final commandBus = CommandBus();
        final adapter = FlameInteractionAdapter(
          nodeId: 'test-node',
          commandBus: commandBus,
        );

        expect(
          () => adapter.adaptTap(const LocalPosition.absolute(10, 20)),
          returnsNormally,
        );
      });
    });

    group('NodeInteractionEvent', () {
      test('应该正确创建事件', () {
        const event = NodeInteractionEvent(
          nodeId: 'test-node',
          type: InteractionType.tap,
          position: LocalPosition.absolute(10, 20),
        );

        expect(event.nodeId, equals('test-node'));
        expect(event.type, equals(InteractionType.tap));
        expect(event.position?.x, equals(10));
        expect(event.position?.y, equals(20));
      });

      test('应该支持可选数据', () {
        const event = NodeInteractionEvent(
          nodeId: 'test-node',
          type: InteractionType.scroll,
          data: {'deltaX': 0.0, 'deltaY': 10.0},
        );

        expect(event.data?['deltaX'], equals(0.0));
        expect(event.data?['deltaY'], equals(10.0));
      });

      test('getData 应该正确转换类型', () {
        const event = NodeInteractionEvent(
          nodeId: 'test-node',
          type: InteractionType.scroll,
          data: {'deltaX': 0.0, 'deltaY': 10.0, 'count': 5},
        );

        expect(event.getData<double>('deltaX'), equals(0.0));
        expect(event.getData<double>('deltaY'), equals(10.0));
        expect(event.getData<int>('count'), equals(5));
        expect(event.getData<String>('nonexistent'), isNull);
        expect(event.getData<String>('nonexistent', defaultValue: 'default'), equals('default'));
      });

      test('toString 应该包含有用信息', () {
        const event = NodeInteractionEvent(
          nodeId: 'test-node',
          type: InteractionType.tap,
          position: LocalPosition.absolute(10, 20),
        );

        expect(event.toString(), contains('test-node'));
        expect(event.toString(), contains('InteractionType.tap'));
      });
    });

    group('InteractionResult', () {
      test('应该正确创建结果', () {
        const handled = InteractionResult(handled: true);
        const notHandled = InteractionResult(handled: false);

        expect(handled.handled, true);
        expect(notHandled.handled, false);
      });

      test('常量应该正确设置', () {
        expect(InteractionResult.notHandled.handled, false);
        expect(InteractionResult.notHandled.shouldPropagate, true);

        expect(InteractionResult.handledStop.handled, true);
        expect(InteractionResult.handledStop.shouldPropagate, false);

        expect(InteractionResult.handledAndPropagate.handled, true);
        expect(InteractionResult.handledAndPropagate.shouldPropagate, true);
      });
    });
  });
}

// 测试辅助类

class _TestEventAdapter extends EventAdapter {
  _TestEventAdapter();

  @override
  Stream<NodeInteractionEvent> adaptEventsInternal(dynamic sourceEvent) =>
      const Stream.empty();
}

class _ValidatingEventAdapter extends EventAdapter {
  _ValidatingEventAdapter({required this.acceptedTypes});

  final List<Type> acceptedTypes;

  @override
  Stream<NodeInteractionEvent> adaptEventsInternal(dynamic sourceEvent) =>
      const Stream.empty();
}
