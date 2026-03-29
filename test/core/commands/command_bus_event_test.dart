import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';

void main() {
  group('CommandBus 事件流集成测试', () {
    late CommandBus commandBus;

    setUp(() {
      commandBus = CommandBus();
    });

    tearDown(() {
      commandBus.dispose();
    });

    test('应该有事件流', () {
      expect(commandBus.eventStream, isNotNull);
      expect(commandBus.eventStream, isA<Stream<AppEvent>>());
    });

    test('应该允许直接发布事件', () async {
      final receivedEvents = <AppEvent>[];
      final subscription = commandBus.eventStream.listen(receivedEvents.add);

      // 直接发布事件，不通过命令
      const event = NodeDataChangedEvent(
        changedNodes: [],  // 测试用的空列表
        action: DataChangeAction.create,
      );

      commandBus.publishEvent(event);

      // 等待事件发布
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents.first, isA<NodeDataChangedEvent>());

      final nodeEvent = receivedEvents.first as NodeDataChangedEvent;
      expect(nodeEvent.action, equals(DataChangeAction.create));

      await subscription.cancel();
    });

    test('应该批量发布事件', () async {
      final receivedEvents = <AppEvent>[];
      final subscription = commandBus.eventStream.listen(receivedEvents.add);

      final events = [
        const NodeDataChangedEvent(
          changedNodes: [],
          action: DataChangeAction.create,
        ),
        const NodeDataChangedEvent(
          changedNodes: [],
          action: DataChangeAction.update,
        ),
      ];

      commandBus.publishEvents(events);

      // 等待事件发布
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(2));
      expect(receivedEvents[0], isA<NodeDataChangedEvent>());
      expect(receivedEvents[1], isA<NodeDataChangedEvent>());

      expect((receivedEvents[0] as NodeDataChangedEvent).action, equals(DataChangeAction.create));
      expect((receivedEvents[1] as NodeDataChangedEvent).action, equals(DataChangeAction.update));

      await subscription.cancel();
    });

    test('应该在释放后不发布事件', () async {
      final receivedEvents = <AppEvent>[];
      final subscription = commandBus.eventStream.listen(receivedEvents.add);

      // 释放命令总线
      commandBus.dispose();

      // 尝试发布事件
      expect(
        () => commandBus.publishEvent(const NodeDataChangedEvent(
          changedNodes: [],
          action: DataChangeAction.create,
        )),
        throwsA(isA<StateError>()),
      );

      await subscription.cancel();
    });

    test('应该支持多个订阅者', () async {
      final subscriber1Events = <AppEvent>[];
      final subscriber2Events = <AppEvent>[];

      final subscription1 = commandBus.eventStream.listen(subscriber1Events.add);
      final subscription2 = commandBus.eventStream.listen(subscriber2Events.add);

      const event = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.delete,
      );

      commandBus.publishEvent(event);

      // 等待事件发布
      await Future.delayed(const Duration(milliseconds: 10));

      // 两个订阅者都应该收到事件
      expect(subscriber1Events.length, equals(1));
      expect(subscriber2Events.length, equals(1));
      expect(subscriber1Events.first, equals(subscriber2Events.first));

      await subscription1.cancel();
      await subscription2.cancel();
    });

    test('应该按顺序流式传输事件', () async {
      final receivedEvents = <AppEvent>[];
      final subscription = commandBus.eventStream.listen(receivedEvents.add);

      final events = [
        const NodeDataChangedEvent(
          changedNodes: [],
          action: DataChangeAction.create,
        ),
        const NodeDataChangedEvent(
          changedNodes: [],
          action: DataChangeAction.update,
        ),
        const NodeDataChangedEvent(
          changedNodes: [],
          action: DataChangeAction.delete,
        ),
      ];

      events.forEach(commandBus.publishEvent);

      // 等待事件发布
      await Future.delayed(const Duration(milliseconds: 50));

      expect(receivedEvents.length, equals(3));
      expect((receivedEvents[0] as NodeDataChangedEvent).action, equals(DataChangeAction.create));
      expect((receivedEvents[1] as NodeDataChangedEvent).action, equals(DataChangeAction.update));
      expect((receivedEvents[2] as NodeDataChangedEvent).action, equals(DataChangeAction.delete));

      await subscription.cancel();
    });
  });
}
