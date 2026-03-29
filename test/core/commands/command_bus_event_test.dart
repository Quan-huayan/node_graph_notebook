import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';

void main() {
  group('CommandBus EventStream Integration', () {
    late CommandBus commandBus;

    setUp(() {
      commandBus = CommandBus();
    });

    tearDown(() {
      commandBus.dispose();
    });

    test('should have eventStream', () {
      expect(commandBus.eventStream, isNotNull);
      expect(commandBus.eventStream, isA<Stream<AppEvent>>());
    });

    test('should allow direct event publishing', () async {
      final receivedEvents = <AppEvent>[];
      final subscription = commandBus.eventStream.listen(receivedEvents.add);

      // Publish event directly without command
      const event = NodeDataChangedEvent(
        changedNodes: [],  // Empty list for testing
        action: DataChangeAction.create,
      );

      commandBus.publishEvent(event);

      // Wait for event to be published
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents.first, isA<NodeDataChangedEvent>());

      final nodeEvent = receivedEvents.first as NodeDataChangedEvent;
      expect(nodeEvent.action, equals(DataChangeAction.create));

      await subscription.cancel();
    });

    test('should publish batch of events', () async {
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

      // Wait for events to be published
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(2));
      expect(receivedEvents[0], isA<NodeDataChangedEvent>());
      expect(receivedEvents[1], isA<NodeDataChangedEvent>());

      expect((receivedEvents[0] as NodeDataChangedEvent).action, equals(DataChangeAction.create));
      expect((receivedEvents[1] as NodeDataChangedEvent).action, equals(DataChangeAction.update));

      await subscription.cancel();
    });

    test('should not publish events after disposal', () async {
      final receivedEvents = <AppEvent>[];
      final subscription = commandBus.eventStream.listen(receivedEvents.add);

      // Dispose command bus
      commandBus.dispose();

      // Try to publish event
      expect(
        () => commandBus.publishEvent(const NodeDataChangedEvent(
          changedNodes: [],
          action: DataChangeAction.create,
        )),
        throwsA(isA<StateError>()),
      );

      await subscription.cancel();
    });

    test('should support multiple subscribers', () async {
      final subscriber1Events = <AppEvent>[];
      final subscriber2Events = <AppEvent>[];

      final subscription1 = commandBus.eventStream.listen(subscriber1Events.add);
      final subscription2 = commandBus.eventStream.listen(subscriber2Events.add);

      const event = NodeDataChangedEvent(
        changedNodes: [],
        action: DataChangeAction.delete,
      );

      commandBus.publishEvent(event);

      // Wait for event to be published
      await Future.delayed(const Duration(milliseconds: 10));

      // Both subscribers should receive the event
      expect(subscriber1Events.length, equals(1));
      expect(subscriber2Events.length, equals(1));
      expect(subscriber1Events.first, equals(subscriber2Events.first));

      await subscription1.cancel();
      await subscription2.cancel();
    });

    test('should stream events in order', () async {
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

      for (final event in events) {
        commandBus.publishEvent(event);
      }

      // Wait for events to be published
      await Future.delayed(const Duration(milliseconds: 50));

      expect(receivedEvents.length, equals(3));
      expect((receivedEvents[0] as NodeDataChangedEvent).action, equals(DataChangeAction.create));
      expect((receivedEvents[1] as NodeDataChangedEvent).action, equals(DataChangeAction.update));
      expect((receivedEvents[2] as NodeDataChangedEvent).action, equals(DataChangeAction.delete));

      await subscription.cancel();
    });
  });
}
