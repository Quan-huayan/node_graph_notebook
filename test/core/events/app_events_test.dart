import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';
import '../../test_helpers.dart';

void main() {
  group('AppEventBus', () {
    late AppEventBus eventBus;

    setUp(() {
      // 每个测试使用新的事件总线实例（用于测试隔离）
      eventBus = AppEventBus.createForTest();
    });

    tearDown(() {
      eventBus.dispose();
    });

    test('should return same instance using factory constructor', () {
      // 测试单例模式
      final instance1 = AppEventBus();
      final instance2 = AppEventBus();

      expect(identical(instance1, instance2), true);

      // 测试 createForTest() 返回新实例
      final testInstance = AppEventBus.createForTest();
      expect(identical(instance1, testInstance), false);

      testInstance.dispose();
    });

    test('should broadcast events to multiple subscribers', () async {
      final event1 = const NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.create,
      );

      final eventList1 = <AppEvent>[];
      final eventList2 = <AppEvent>[];

      // 订阅者 1
      final subscription1 = eventBus.stream.listen(eventList1.add);

      // 订阅者 2
      final subscription2 = eventBus.stream.listen(eventList2.add);

      // 发布事件
      eventBus.publish(event1);

      // 等待事件传递
      await Future.delayed(const Duration(milliseconds: 10));

      expect(eventList1, equals([event1]));
      expect(eventList2, equals([event1]));

      await subscription1.cancel();
      await subscription2.cancel();
    });

    test('should not publish events after dispose', () async {
      final event1 = const NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.create,
      );

      final eventList = <AppEvent>[];
      final subscription = eventBus.stream.listen(eventList.add);

      // 释放事件总线
      eventBus.dispose();

      // 发布事件（应该被忽略）
      eventBus.publish(event1);

      // 等待
      await Future.delayed(const Duration(milliseconds: 10));

      expect(eventList, isEmpty);

      await subscription.cancel();
    });

    test('should handle multiple event types', () async {
      final node = NodeTestHelpers.test(
        id: 'test-id',
        title: 'Test Node',
        content: 'Test Content',
      );

      final event1 = NodeDataChangedEvent(
        changedNodes: [node],
        action: DataChangeAction.create,
      );

      final event2 = const GraphNodeRelationChangedEvent(
        graphId: 'graph-1',
        nodeIds: ['node-1', 'node-2'],
        action: RelationChangeAction.addedToGraph,
      );

      final eventList = <AppEvent>[];
      final subscription = eventBus.stream.listen(eventList.add);

      eventBus.publish(event1);
      eventBus.publish(event2);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(eventList.length, 2);
      expect(eventList[0], equals(event1));
      expect(eventList[1], equals(event2));

      await subscription.cancel();
    });
  });

  group('NodeDataChangedEvent', () {
    test('should be equatable when properties match', () {
      final node = NodeTestHelpers.test(
        id: 'test-id',
        title: 'Test Node',
        content: 'Test Content',
      );

      final event1 = NodeDataChangedEvent(
        changedNodes: [node],
        action: DataChangeAction.create,
      );

      final event2 = NodeDataChangedEvent(
        changedNodes: [node],
        action: DataChangeAction.create,
      );

      expect(event1, equals(event2));
    });

    test('should not be equatable when properties differ', () {
      final node1 = NodeTestHelpers.test(
        id: 'test-id-1',
        title: 'Test Node 1',
        content: 'Test Content 1',
      );

      final node2 = NodeTestHelpers.test(
        id: 'test-id-2',
        title: 'Test Node 2',
        content: 'Test Content 2',
      );

      final event1 = NodeDataChangedEvent(
        changedNodes: [node1],
        action: DataChangeAction.create,
      );

      final event2 = NodeDataChangedEvent(
        changedNodes: [node2],
        action: DataChangeAction.update,
      );

      expect(event1, isNot(equals(event2)));
    });

    test('props should contain changedNodes and action', () {
      final node = NodeTestHelpers.test(
        id: 'test-id',
        title: 'Test Node',
        content: 'Test Content',
      );

      final event = NodeDataChangedEvent(
        changedNodes: [node],
        action: DataChangeAction.delete,
      );

      expect(event.props, equals([ [node], DataChangeAction.delete ]));
    });
  });

  group('GraphNodeRelationChangedEvent', () {
    test('should be equatable when properties match', () {
      final event1 = const GraphNodeRelationChangedEvent(
        graphId: 'graph-1',
        nodeIds: ['node-1', 'node-2'],
        action: RelationChangeAction.addedToGraph,
      );

      final event2 = const GraphNodeRelationChangedEvent(
        graphId: 'graph-1',
        nodeIds: ['node-1', 'node-2'],
        action: RelationChangeAction.addedToGraph,
      );

      expect(event1, equals(event2));
    });

    test('should not be equatable when properties differ', () {
      final event1 = const GraphNodeRelationChangedEvent(
        graphId: 'graph-1',
        nodeIds: ['node-1', 'node-2'],
        action: RelationChangeAction.addedToGraph,
      );

      final event2 = const GraphNodeRelationChangedEvent(
        graphId: 'graph-2',
        nodeIds: ['node-3', 'node-4'],
        action: RelationChangeAction.removedFromGraph,
      );

      expect(event1, isNot(equals(event2)));
    });

    test('props should contain graphId, nodeIds, and action', () {
      final event = const GraphNodeRelationChangedEvent(
        graphId: 'graph-1',
        nodeIds: ['node-1', 'node-2'],
        action: RelationChangeAction.removedFromGraph,
      );

      expect(event.props, equals(['graph-1', ['node-1', 'node-2'], RelationChangeAction.removedFromGraph]));
    });
  });
}
