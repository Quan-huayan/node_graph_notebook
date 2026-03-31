/// Node interaction events for the UI layout system.
///
/// This module defines unified events for user interactions with Nodes.
/// These events are framework-agnostic and work with both Flutter and Flame.
///
/// ## Key Concepts
///
/// - **NodeInteractionEvent**: Unified event for all user interactions
/// - **InteractionType**: Enum defining interaction types (tap, drag, etc.)
/// - **Event Adapters**: Convert framework-specific events to unified events
/// - **Event Bus**: Propagate events through the system
///
/// ## Architecture
///
/// ```
/// Flutter Gesture / Flame Interaction
///           ↓
///   Event Adapter (convert)
///           ↓
///   NodeInteractionEvent (unified)
///           ↓
///   EventBus (publish)
///           ↓
///   Node / Plugin (subscribe & react)
/// ```
library;

import 'package:flame/events.dart';
import 'package:flutter/gestures.dart';

import '../../commands/command_bus.dart';
import '../../events/app_events.dart';
import '../coordinate_system.dart';

/// Type of user interaction with a Node.
///
/// Defines the category of interaction for unified event handling.
enum InteractionType {
  /// Single tap/click on a Node.
  tap,

  /// Double tap/click on a Node.
  doubleTap,

  /// Long press on a Node.
  longPress,

  /// Drag started (mouse down / touch start).
  dragStart,

  /// Drag updated (mouse move / touch move).
  dragUpdate,

  /// Drag ended (mouse up / touch end).
  dragEnd,

  /// Hover (mouse moved over Node).
  hover,

  /// Scroll (mouse wheel / trackpad).
  scroll,

  /// Custom interaction type.
  custom,
}

/// Unified event for user interactions with Nodes.
///
/// This event is framework-agnostic and represents interactions from
/// both Flutter (gestures) and Flame (input handling).
///
/// ## Event Flow
///
/// 1. User interacts with UI (Flutter Widget or Flame component)
/// 2. Event adapter converts framework-specific event to NodeInteractionEvent
/// 3. Event published to EventBus
/// 4. Nodes and plugins subscribe and react
///
/// ## Usage
///
/// ```dart
/// // Subscribe to node interactions
/// eventBus.stream
///   .where((event) => event is NodeInteractionEvent)
///   .listen((event) {
///     final e = event as NodeInteractionEvent;
///     if (e.nodeId == 'my-node') {
///       print('Node ${e.nodeId} received ${e.type}');
///     }
///   });
///
/// // Dispatch event (done automatically by adapters)
/// eventBus.publish(NodeInteractionEvent(
///   nodeId: 'my-node',
///   type: InteractionType.tap,
///   position: LocalPosition.absolute(10, 20),
/// ));
/// ```
class NodeInteractionEvent extends AppEvent {
  /// Creates a node interaction event.
  ///
  /// [nodeId] is the ID of the Node that received the interaction.
  /// [type] is the type of interaction.
  /// [position] is the local position of the interaction within the Node.
  /// [data] is optional additional data (e.g., scroll delta, drag delta).
  /// [timestamp] is when the interaction occurred (milliseconds since epoch).
  const NodeInteractionEvent({
    required this.nodeId,
    required this.type,
    this.position,
    this.data,
    this.timestamp,
  });

  /// ID of the Node that received the interaction.
  final String nodeId;

  /// Type of interaction.
  final InteractionType type;

  /// Local position of the interaction within the Node (if applicable).
  final LocalPosition? position;

  /// Optional additional data.
  ///
  /// Examples:
  /// - scroll: {'deltaX': 0.0, 'deltaY': 10.0}
  /// - dragUpdate: {'deltaX': 5.0, 'deltaY': 3.0}
  /// - custom: plugin-specific data
  final Map<String, dynamic>? data;

  /// Timestamp of the interaction (milliseconds since epoch).
  ///
  /// If null, defaults to current time when event is created.
  final int? timestamp;

  @override
  String toString() =>
      'NodeInteractionEvent(nodeId: $nodeId, type: $type, position: $position)';

  /// Gets data value as a specific type.
  ///
  /// Returns the value for [key] cast to type [T], or [defaultValue] if not found.
  T? getData<T>(String key, {T? defaultValue}) {
    final value = data?[key];
    if (value == null) return defaultValue;
    return value as T?;
  }
}

/// Result of an interaction handler.
///
/// Returned by Node interaction handlers to indicate if the event
/// was handled and should stop propagating.
class InteractionResult {
  /// Creates an interaction result.
  ///
  /// [handled] indicates if the event was handled.
  /// [shouldPropagate] indicates if the event should continue propagating
  /// to other handlers (default: false if handled).
  const InteractionResult({
    this.handled = true,
    this.shouldPropagate = false,
  });

  /// The event was handled by this handler.
  final bool handled;

  /// The event should continue propagating to other handlers.
  final bool shouldPropagate;

  /// Event was not handled (should propagate).
  static const notHandled = InteractionResult(handled: false, shouldPropagate: true);

  /// Event was handled and should stop propagating.
  static const handledStop = InteractionResult(handled: true, shouldPropagate: false);

  /// Event was handled but should continue propagating.
  static const handledAndPropagate = InteractionResult(handled: true, shouldPropagate: true);
}

/// Event adapter exception.
///
/// Thrown when event adaptation fails due to type mismatch or invalid data.
class EventAdapterException implements Exception {
  /// Creates an event adapter exception.
  ///
  /// [message] is the error message.
  const EventAdapterException(this.message);

  /// Error message.
  final String message;

  @override
  String toString() => 'EventAdapterException: $message';
}

/// Base class for event adapters.
///
/// Event adapters convert framework-specific events (Flutter gestures,
/// Flame inputs) to unified [NodeInteractionEvent] instances.
///
/// ## Implementing a Custom Adapter
///
/// ```dart
/// class MyCustomAdapter extends EventAdapter {
///   @override
///   Stream<NodeInteractionEvent> adaptEvents(dynamic sourceEvent) {
///     return sourceEvent.stream.map((event) => NodeInteractionEvent(
///       nodeId: event.targetId,
///       type: InteractionType.custom,
///       data: {'customData': event.data},
///     ));
///   }
/// }
/// ```
abstract class EventAdapter {
  /// Adapts framework-specific events to NodeInteractionEvent.
  ///
  /// [sourceEvent] is the framework-specific event to adapt.
  ///
  /// Returns a stream of adapted events (may be multiple events from one source).
  ///
  /// ✅ Type validation: Validates source event type before adaptation.
  Stream<NodeInteractionEvent> adaptEvents(dynamic sourceEvent) {
    // 验证源事件类型（如果子类重写了这个方法，可以选择性地调用）
    if (!_validateSourceEventType(sourceEvent)) {
      throw EventAdapterException(
        'Invalid event type: ${sourceEvent.runtimeType}',
      );
    }

    return adaptEventsInternal(sourceEvent);
  }

  /// Internal adaptation method.
  ///
  /// Subclasses should override this method to implement the actual adaptation logic.
  /// This method is called after type validation passes.
  ///
  /// [sourceEvent] is the validated framework-specific event.
  Stream<NodeInteractionEvent> adaptEventsInternal(dynamic sourceEvent);

  /// Validates the source event type.
  ///
  /// Subclasses can override this method to implement custom validation logic.
  /// Returns true if the event type is valid, false otherwise.
  ///
  /// Default implementation accepts all event types.
  bool _validateSourceEventType(dynamic sourceEvent) => true;
}

/// Adapter for Flutter gesture events.
///
/// Converts Flutter GestureDetector events to NodeInteractionEvent.
/// This adapter is used by Flutter Widgets that wrap Nodes.
///
/// ## Usage
///
/// ```dart
/// final adapter = FlutterGestureAdapter(nodeId: 'my-node');
///
/// GestureDetector(
///   onTap: () => adapter.adaptTap(),
///   onPanStart: (details) => adapter.adaptDragStart(details),
///   child: NodeWidget(node: node),
/// )
/// ```
class FlutterGestureAdapter extends EventAdapter {
  /// Creates a Flutter gesture adapter.
  ///
  /// [nodeId] is the ID of the Node this adapter is for.
  /// [commandBus] is the CommandBus to publish adapted events to.
  FlutterGestureAdapter({
    required this.nodeId,
    required CommandBus commandBus,
  }) : _commandBus = commandBus;

  /// ID of the Node this adapter is for.
  final String nodeId;

  /// CommandBus to publish events to.
  final CommandBus _commandBus;

  /// Adapts a tap gesture.
  ///
  /// [position] is the local position of the tap (optional).
  void adaptTap([LocalPosition? position]) {
    _publish(NodeInteractionEvent(
      nodeId: nodeId,
      type: InteractionType.tap,
      position: position,
    ));
  }

  /// Adapts a double tap gesture.
  ///
  /// [position] is the local position of the tap (optional).
  void adaptDoubleTap([LocalPosition? position]) {
    _publish(NodeInteractionEvent(
      nodeId: nodeId,
      type: InteractionType.doubleTap,
      position: position,
    ));
  }

  /// Adapts a long press gesture.
  ///
  /// [position] is the local position of the press (optional).
  void adaptLongPress([LocalPosition? position]) {
    _publish(NodeInteractionEvent(
      nodeId: nodeId,
      type: InteractionType.longPress,
      position: position,
    ));
  }

  /// Adapts a drag start gesture.
  ///
  /// [details] is the drag start details from Flutter.
  void adaptDragStart(DragStartDetails details) {
    _publish(NodeInteractionEvent(
      nodeId: nodeId,
      type: InteractionType.dragStart,
      position: LocalPosition.absolute(details.globalPosition.dx, details.globalPosition.dy),
      data: {
        'localPosition': {'x': details.localPosition.dx, 'y': details.localPosition.dy},
      },
    ));
  }

  /// Adapts a drag update gesture.
  ///
  /// [details] is the drag update details from Flutter.
  void adaptDragUpdate(DragUpdateDetails details) {
    _publish(NodeInteractionEvent(
      nodeId: nodeId,
      type: InteractionType.dragUpdate,
      position: LocalPosition.absolute(details.globalPosition.dx, details.globalPosition.dy),
      data: {
        'delta': {'x': details.delta.dx, 'y': details.delta.dy},
        'localPosition': {'x': details.localPosition.dx, 'y': details.localPosition.dy},
      },
    ));
  }

  /// Adapts a drag end gesture.
  ///
  /// [details] is the drag end details from Flutter (optional).
  void adaptDragEnd([DragEndDetails? details]) {
    _publish(NodeInteractionEvent(
      nodeId: nodeId,
      type: InteractionType.dragEnd,
      data: details != null
          ? {
              'velocity': {'x': details.velocity.pixelsPerSecond.dx, 'y': details.velocity.pixelsPerSecond.dy},
            }
          : null,
    ));
  }

  /// Adapts a hover event.
  ///
  /// [details] is the hover event details from Flutter.
  void adaptHover(PointerHoverEvent details) {
    _publish(NodeInteractionEvent(
      nodeId: nodeId,
      type: InteractionType.hover,
      position: LocalPosition.absolute(details.localPosition.dx, details.localPosition.dy),
    ));
  }

  /// Adapts a scroll event.
  ///
  /// [details] is the scroll details from Flutter.
  void adaptScroll(PointerScrollEvent details) {
    _publish(NodeInteractionEvent(
      nodeId: nodeId,
      type: InteractionType.scroll,
      data: {
        'scrollDelta': {'x': details.scrollDelta.dx, 'y': details.scrollDelta.dy},
      },
    ));
  }

  @override
  Stream<NodeInteractionEvent> adaptEventsInternal(dynamic sourceEvent)
    // This is a convenience method for bulk event adaptation
    // Most usage will be direct method calls (adaptTap, adaptDragStart, etc.)
    => const Stream.empty();

  @override
  bool _validateSourceEventType(dynamic sourceEvent) =>
    // FlutterGestureAdapter doesn't use adaptEventsInternal, so we accept all types
    // Validation is done in individual adapt methods
    true;

  void _publish(NodeInteractionEvent event) {
    _commandBus.publishEvent(event);
  }
}

/// Adapter for Flame interaction events.
///
/// Converts Flame input events (tap, drag, etc.) to NodeInteractionEvent.
/// This adapter is used by Flame Components that render Nodes.
///
/// ## Usage
///
/// ```dart
/// final adapter = FlameInteractionAdapter(nodeId: 'my-node', eventBus: eventBus);
///
/// class MyNodeComponent extends Component {
///   @override
///   void onDragStart(int pointerId, DragStartInfo info) {
///     adapter.adaptDragStart(pointerId, info);
///   }
/// }
/// ```
class FlameInteractionAdapter extends EventAdapter {
  /// Creates a Flame interaction adapter.
  ///
  /// [nodeId] is the ID of the Node this adapter is for.
  /// [commandBus] is the CommandBus to publish adapted events to.
  FlameInteractionAdapter({
    required this.nodeId,
    required CommandBus commandBus,
  }) : _commandBus = commandBus;

  /// ID of the Node this adapter is for.
  final String nodeId;

  /// CommandBus to publish events to.
  final CommandBus _commandBus;

  /// Adapts a tap event.
  ///
  /// [position] is the local position of the tap.
  void adaptTap(LocalPosition position) {
    _publish(NodeInteractionEvent(
      nodeId: nodeId,
      type: InteractionType.tap,
      position: position,
    ));
  }

  /// Adapts a drag start event.
  ///
  /// [pointerId] is the pointer ID from Flame.
  /// [info] is the drag start info from Flame.
  void adaptDragStart(int pointerId, DragStartInfo info) {
    _publish(NodeInteractionEvent(
      nodeId: nodeId,
      type: InteractionType.dragStart,
      position: LocalPosition.absolute(info.eventPosition.global.x, info.eventPosition.global.y),
      data: {
        'pointerId': pointerId,
      },
    ));
  }

  /// Adapts a drag update event.
  ///
  /// [pointerId] is the pointer ID from Flame.
  /// [info] is the drag update info from Flame.
  void adaptDragUpdate(int pointerId, DragUpdateInfo info) {
    _publish(NodeInteractionEvent(
      nodeId: nodeId,
      type: InteractionType.dragUpdate,
      position: LocalPosition.absolute(info.eventPosition.global.x, info.eventPosition.global.y),
      data: {
        'pointerId': pointerId,
        'delta': {'x': info.delta.global.x, 'y': info.delta.global.y},
      },
    ));
  }

  /// Adapts a drag end event.
  ///
  /// [pointerId] is the pointer ID from Flame.
  /// [info] is the drag end info from Flame (optional).
  void adaptDragEnd(int pointerId, [DragEndInfo? info]) {
    _publish(NodeInteractionEvent(
      nodeId: nodeId,
      type: InteractionType.dragEnd,
      data: {
        'pointerId': pointerId,
      },
    ));
  }

  @override
  Stream<NodeInteractionEvent> adaptEventsInternal(dynamic sourceEvent)
    // TODO: This is a convenience method for bulk event adaptation
    // Most usage will be direct method calls (adaptTap, adaptDragStart, etc.)
    => const Stream.empty();

  @override
  bool _validateSourceEventType(dynamic sourceEvent) =>
    // FlameInteractionAdapter doesn't use adaptEventsInternal, so we accept all types
    // Validation is done in individual adapt methods
    true;

  void _publish(NodeInteractionEvent event) {
    _commandBus.publishEvent(event);
  }
}
