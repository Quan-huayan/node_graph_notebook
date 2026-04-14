import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/cqrs/commands/command_bus.dart';
import 'package:node_graph_notebook/core/cqrs/commands/events/app_events.dart';

void main() {
  group('CommandBus EventStream', () {
    late CommandBus commandBus;

    setUp(() {
      commandBus = CommandBus();
    });

    tearDown(() {
      commandBus.dispose();
    });

    test('应该将事件发布给订阅者', () async {
      final completer = Completer<AppEvent>();
      const event = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.create,
      );

      commandBus.eventStream.listen(completer.complete);
      commandBus.publishEvent(event);

      final receivedEvent = await completer.future;
      expect(receivedEvent, equals(event));
    });

    test('应该支持多个订阅者', () async {
      final completer1 = Completer<AppEvent>();
      final completer2 = Completer<AppEvent>();

      commandBus.eventStream.listen(completer1.complete);
      commandBus.eventStream.listen(completer2.complete);

      const event = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.update,
      );

      commandBus.publishEvent(event);

      final received1 = await completer1.future;
      final received2 = await completer2.future;

      expect(received1, equals(event));
      expect(received2, equals(event));
    });

    test('应该只接收订阅之后的事件', () async {
      final completer = Completer<AppEvent>();

      const event1 = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.create,
      );

      // 在订阅之前发布
      commandBus.publishEvent(event1);

      // 在事件之后订阅
      late StreamSubscription<AppEvent> subscription;
      subscription = commandBus.eventStream.listen((event) {
        completer.complete(event);
        subscription.cancel();
      });

      const event2 = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.update,
      );

      // 在订阅之后发布
      commandBus.publishEvent(event2);

      final received = await completer.future;
      expect(received, equals(event2));
      expect(received, isNot(equals(event1)));
    });

    test('应该按类型过滤事件', () async {
      final nodeEventCompleter = Completer<NodeDataChangedEvent>();

      commandBus.eventStream
          .where((event) => event is NodeDataChangedEvent)
          .cast<NodeDataChangedEvent>()
          .listen(nodeEventCompleter.complete);

      const nodeEvent = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.create,
      );

      const graphEvent = GraphNodeRelationChangedEvent(
        graphId: 'test',
        nodeIds: [],
        action: RelationChangeAction.addedToGraph,
      );

      commandBus.publishEvent(graphEvent);

      // 等待一段时间以确保节点事件未完成
      await Future.delayed(const Duration(milliseconds: 10));

      expect(nodeEventCompleter.isCompleted, false);

      commandBus.publishEvent(nodeEvent);

      final receivedNode = await nodeEventCompleter.future;
      expect(receivedNode, equals(nodeEvent));
    });

    test('应该处理快速事件发布', () async {
      const eventCount = 100;
      final receivedEvents = <AppEvent>[];

      commandBus.eventStream.listen(receivedEvents.add);

      for (var i = 0; i < eventCount; i++) {
        commandBus.publishEvent(
          const NodeDataChangedEvent(
            changedNodes: [],
            action: DataChangeAction.update,
          ),
        );
      }

      // 等待所有事件被处理
      await Future.delayed(const Duration(milliseconds: 100));

      expect(receivedEvents.length, equals(eventCount));
    });
  });

  group('AppEvent 事件', () {
    test('NodeDataChangedEvent 应该是可比较的', () {
      const event1 = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.create,
      );

      const event2 = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.create,
      );

      const event3 = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.update,
      );

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });

    test('GraphNodeRelationChangedEvent 应该是可比较的', () {
      const event1 = GraphNodeRelationChangedEvent(
        graphId: 'graph1',
        nodeIds: ['node1', 'node2'],
        action: RelationChangeAction.addedToGraph,
      );

      const event2 = GraphNodeRelationChangedEvent(
        graphId: 'graph1',
        nodeIds: ['node1', 'node2'],
        action: RelationChangeAction.addedToGraph,
      );

      const event3 = GraphNodeRelationChangedEvent(
        graphId: 'graph2',
        nodeIds: ['node3'],
        action: RelationChangeAction.removedFromGraph,
      );

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });
  });
}
