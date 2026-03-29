/// Layout-specific events for the UI layout system.
///
/// This module defines events that are published when Nodes are attached,
/// detached, moved, or when layout state changes.
///
/// ## Event Flow
///
/// 1. UILayoutService performs operation (attach/detach/move)
/// 2. Event is published to EventBus
/// 3. Subscribers (UI components, plugins) react to event
/// 4. UI updates automatically
///
/// ## Usage
///
/// ```dart
/// // Subscribe to events
/// eventBus.stream.listen((event) {
///   if (event is NodeAttachedEvent) {
///     print('Node ${event.nodeId} attached to ${event.hookId}');
///   }
/// });
///
/// // Events are published automatically by UILayoutService
/// await layoutService.attachNode(
///   nodeId: 'node-1',
///   hookId: 'sidebar',
///   position: LocalPosition.absolute(10, 20),
/// );
/// ```
library;

import '../../events/app_events.dart';
import '../coordinate_system.dart';

/// Event published when a Node is attached to a Hook.
///
/// Contains information about which Node was attached and where.
/// UI components can subscribe to this event to update their display.
///
/// ## Example
///
/// ```dart
/// eventBus.stream
///   .where((event) => event is NodeAttachedEvent)
///   .listen((event) {
///     final e = event as NodeAttachedEvent;
///     print('Node ${e.nodeId} attached to ${e.hookId} at ${e.position}');
///   });
/// ```
class NodeAttachedEvent extends AppEvent {
  /// Creates a node attached event.
  ///
  /// [nodeId] is the ID of the Node that was attached.
  /// [hookId] is the ID of the Hook the Node was attached to.
  /// [position] is the local position within the Hook.
  /// [zIndex] is the rendering order for the Node.
  const NodeAttachedEvent({
    required this.nodeId,
    required this.hookId,
    required this.position,
    this.zIndex = 0,
  });

  /// ID of the Node that was attached.
  final String nodeId;

  /// ID of the Hook the Node was attached to.
  final String hookId;

  /// Local position of the Node within the Hook.
  final LocalPosition position;

  /// Rendering order (higher values on top).
  final int zIndex;

  @override
  String toString() =>
      'NodeAttachedEvent(nodeId: $nodeId, hookId: $hookId, position: $position, zIndex: $zIndex)';
}

/// Event published when a Node is detached from a Hook.
///
/// Contains information about which Node was detached and from where.
/// UI components can subscribe to this event to remove the Node from display.
///
/// ## Example
///
/// ```dart
/// eventBus.stream
///   .where((event) => event is NodeDetachedEvent)
///   .listen((event) {
///     final e = event as NodeDetachedEvent;
///     print('Node ${e.nodeId} detached from ${e.hookId}');
///   });
/// ```
class NodeDetachedEvent extends AppEvent {
  /// Creates a node detached event.
  ///
  /// [nodeId] is the ID of the Node that was detached.
  /// [hookId] is the ID of the Hook the Node was detached from.
  /// [oldPosition] is the position where the Node was before detachment.
  const NodeDetachedEvent({
    required this.nodeId,
    required this.hookId,
    required this.oldPosition,
  });

  /// ID of the Node that was detached.
  final String nodeId;

  /// ID of the Hook the Node was detached from.
  final String hookId;

  /// Position of the Node before it was detached.
  final LocalPosition oldPosition;

  @override
  String toString() =>
      'NodeDetachedEvent(nodeId: $nodeId, hookId: $hookId, oldPosition: $oldPosition)';
}

/// Event published when a Node's position is updated.
///
/// Contains information about the Node's new position.
/// UI components can subscribe to this event to animate the position change.
///
/// ## Example
///
/// ```dart
/// eventBus.stream
///   .where((event) => event is NodePositionUpdatedEvent)
///   .listen((event) {
///     final e = event as NodePositionUpdatedEvent;
///     print('Node ${e.nodeId} moved to ${e.newPosition}');
///   });
/// ```
class NodePositionUpdatedEvent extends AppEvent {
  /// Creates a node position updated event.
  ///
  /// [nodeId] is the ID of the Node that was moved.
  /// [hookId] is the ID of the Hook containing the Node.
  /// [oldPosition] is the position before the update.
  /// [newPosition] is the position after the update.
  const NodePositionUpdatedEvent({
    required this.nodeId,
    required this.hookId,
    required this.oldPosition,
    required this.newPosition,
  });

  /// ID of the Node that was moved.
  final String nodeId;

  /// ID of the Hook containing the Node.
  final String hookId;

  /// Position before the update.
  final LocalPosition oldPosition;

  /// Position after the update.
  final LocalPosition newPosition;

  @override
  String toString() =>
      'NodePositionUpdatedEvent(nodeId: $nodeId, hookId: $hookId, old: $oldPosition, new: $newPosition)';
}

/// Event published when a Node is moved between Hooks.
///
/// Contains information about the source and destination Hooks.
/// UI components can subscribe to this event to animate the move.
///
/// ## Example
///
/// ```dart
/// eventBus.stream
///   .where((event) => event is NodeMovedEvent)
///   .listen((event) {
///     final e = event as NodeMovedEvent;
///     print('Node ${e.nodeId} moved from ${e.oldHookId} to ${e.newHookId}');
///   });
/// ```
class NodeMovedEvent extends AppEvent {
  /// Creates a node moved event.
  ///
  /// [nodeId] is the ID of the Node that was moved.
  /// [oldHookId] is the ID of the source Hook.
  /// [newHookId] is the ID of the destination Hook.
  /// [oldPosition] is the position in the source Hook.
  /// [newPosition] is the position in the destination Hook.
  const NodeMovedEvent({
    required this.nodeId,
    required this.oldHookId,
    required this.newHookId,
    required this.oldPosition,
    required this.newPosition,
  });

  /// ID of the Node that was moved.
  final String nodeId;

  /// ID of the source Hook.
  final String oldHookId;

  /// ID of the destination Hook.
  final String newHookId;

  /// Position in the source Hook.
  final LocalPosition oldPosition;

  /// Position in the destination Hook.
  final LocalPosition newPosition;

  @override
  String toString() =>
      'NodeMovedEvent(nodeId: $nodeId, from: $oldHookId, to: $newHookId, oldPos: $oldPosition, newPos: $newPosition)';
}

/// Event published when a Hook's layout is recalculated.
///
/// Contains information about which Hook was recalculated.
/// UI components can subscribe to this event to update their layout.
///
/// ## Example
///
/// ```dart
/// eventBus.stream
///   .where((event) => event is LayoutRecalculatedEvent)
///   .listen((event) {
///     final e = event as LayoutRecalculatedEvent;
///     print('Layout recalculated for Hook: ${e.hookId}');
///   });
/// ```
class LayoutRecalculatedEvent extends AppEvent {
  /// Creates a layout recalculated event.
  ///
  /// [hookId] is the ID of the Hook that was recalculated.
  /// [hasChanges] indicates if any positions actually changed.
  const LayoutRecalculatedEvent({
    required this.hookId,
    this.hasChanges = true,
  });

  /// ID of the Hook that was recalculated.
  final String hookId;

  /// Whether any positions actually changed.
  final bool hasChanges;

  @override
  String toString() =>
      'LayoutRecalculatedEvent(hookId: $hookId, hasChanges: $hasChanges)';
}

/// Event published when a Hook tree structure changes.
///
/// Contains information about structural changes (add/remove Hook).
/// UI components can subscribe to this event to rebuild their tree.
///
/// ## Example
///
/// ```dart
/// eventBus.stream
///   .where((event) => event is HookTreeChangedEvent)
///   .listen((event) {
///     final e = event as HookTreeChangedEvent;
///     print('Hook tree changed: ${e.changeType} - ${e.hookId}');
///   });
/// ```
class HookTreeChangedEvent extends AppEvent {
  /// Creates a hook tree changed event.
  ///
  /// [hookId] is the ID of the Hook that was added/removed.
  /// [changeType] is the type of structural change.
  /// [parentId] is the ID of the parent Hook (null for root changes).
  const HookTreeChangedEvent({
    required this.hookId,
    required this.changeType,
    this.parentId,
  });

  /// ID of the Hook that was added/removed.
  final String hookId;

  /// Type of structural change.
  final HookTreeChangeType changeType;

  /// ID of the parent Hook (null for root).
  final String? parentId;

  @override
  String toString() =>
      'HookTreeChangedEvent(hookId: $hookId, changeType: $changeType, parentId: $parentId)';
}

/// Type of structural change in the Hook tree.
enum HookTreeChangeType {
  /// A Hook was added to the tree.
  hookAdded,

  /// A Hook was removed from the tree.
  hookRemoved,

  /// A Hook's configuration changed (size, layout strategy, etc.).
  hookConfigChanged,
}
