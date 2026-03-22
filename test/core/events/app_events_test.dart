import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';

void main() {
  group('AppEventBus', () {
    late AppEventBus eventBus;

    setUp(() {
      eventBus = AppEventBus.createForTest();
    });

    tearDown(() {
      eventBus.dispose();
    });

    test('should publish event to subscribers', () async {
      final completer = Completer<AppEvent>();
      const event = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.create,
      );

      eventBus.stream.listen(completer.complete);
      eventBus.publish(event);

      final receivedEvent = await completer.future;
      expect(receivedEvent, equals(event));
    });

    test('should call onError when publish fails', () async {
      final errorCompleter = Completer<Object?>();
      final stackTraceCompleter = Completer<StackTrace>();

      eventBus..onError = (event, error, stackTrace) {
        errorCompleter.complete(error);
        stackTraceCompleter.complete(stackTrace);
      }
      // Close the event bus to trigger error
      ..dispose();

      const event = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.create,
      );

      eventBus.publish(event);

      final error = await errorCompleter.future;
      expect(error, isA<StateError>());

      final stackTrace = await stackTraceCompleter.future;
      expect(stackTrace, isA<StackTrace>());
    });

    test('should use default error handler when onError is null', () async {
      // This test verifies that the default error handler doesn't throw
      final eventBus = AppEventBus.createForTest()
      // Close the event bus
      ..dispose();

      const event = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.create,
      );

      // Should not throw even though bus is closed
      expect(() => eventBus.publish(event), returnsNormally);
    });

    test('should support multiple subscribers', () async {
      final completer1 = Completer<AppEvent>();
      final completer2 = Completer<AppEvent>();

      eventBus.stream.listen(completer1.complete);
      eventBus.stream.listen(completer2.complete);

      const event = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.update,
      );

      eventBus.publish(event);

      final received1 = await completer1.future;
      final received2 = await completer2.future;

      expect(received1, equals(event));
      expect(received2, equals(event));
    });

    test('should only receive events after subscription', () async {
      final completer = Completer<AppEvent>();

      const event1 = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.create,
      );

      // Publish before subscription
      eventBus.publish(event1);

      // Subscribe after event
      late StreamSubscription<AppEvent> subscription;
      subscription = eventBus.stream.listen((event) {
        completer.complete(event);
        subscription.cancel();
      });

      const event2 = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.update,
      );

      // Publish after subscription
      eventBus.publish(event2);

      final received = await completer.future;
      expect(received, equals(event2));
      expect(received, isNot(equals(event1)));
    });

    test('should filter events by type', () async {
      final nodeEventCompleter = Completer<NodeDataChangedEvent>();

      eventBus.stream
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

      eventBus.publish(graphEvent);

      // Wait a bit to ensure node event is not completed
      await Future.delayed(const Duration(milliseconds: 10));

      expect(nodeEventCompleter.isCompleted, false);

      eventBus.publish(nodeEvent);

      final receivedNode = await nodeEventCompleter.future;
      expect(receivedNode, equals(nodeEvent));
    });

    test('should handle rapid event publishing', () async {
      const eventCount = 100;
      final receivedEvents = <AppEvent>[];

      eventBus.stream.listen(receivedEvents.add);

      for (var i = 0; i < eventCount; i++) {
        eventBus.publish(
          const NodeDataChangedEvent(
            changedNodes: [],
            action: DataChangeAction.update,
          ),
        );
      }

      // Wait for all events to be processed
      await Future.delayed(const Duration(milliseconds: 100));

      expect(receivedEvents.length, equals(eventCount));
    });
  });

  group('AppEvent events', () {
    test('NodeDataChangedEvent should be equatable', () {
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

    test('GraphNodeRelationChangedEvent should be equatable', () {
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
