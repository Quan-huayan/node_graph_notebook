/// Node attachment model for UI layout system.
///
/// This module defines the [NodeAttachment] class, which represents
/// a Node attached to a Hook in the UI layout tree.
///
/// ## Key Concepts
///
/// - **NodeAttachment**: Represents a Node-Hook relationship
/// - **Attachment Lifecycle**: Nodes can be attached, detached, moved between Hooks
/// - **Positioning**: Nodes have a local position within their parent Hook
/// - **Z-Index**: Controls rendering order when nodes overlap
///
/// ## Usage
///
/// ```dart
/// final attachment = NodeAttachment(
///   nodeId: 'node-123',
///   localPosition: LocalPosition.absolute(100, 200),
///   zIndex: 1,
/// );
///
/// hook.attachNode(attachment);
/// ```
library;

import 'package:flutter/material.dart';
import 'coordinate_system.dart';

/// Attachment metadata for a Node attached to a Hook.
///
/// Represents the relationship between a Node and a Hook in the UI layout tree.
/// Contains information about where and how the Node is positioned within
/// the Hook's coordinate system.
///
/// ## Lifecycle
///
/// 1. **Attachment**: Created when a Node is attached to a Hook
/// 2. **Position Update**: Can be moved within the same Hook
/// 3. **Detachment**: Removed when Node is detached from Hook
/// 4. **Movement**: Can be moved between Hooks (new attachment created)
///
/// ## Example
///
/// ```dart
/// // Create attachment
/// final attachment = NodeAttachment(
///   nodeId: 'sidebar-node-1',
///   localPosition: LocalPosition.absolute(10, 20),
///   zIndex: 0,
/// );
///
/// // Attach to Hook
/// hook.attachNode(attachment);
///
/// // Update position
/// hook.updateNodePosition('sidebar-node-1', LocalPosition.absolute(50, 100));
///
/// // Detach from Hook
/// hook.detachNode('sidebar-node-1');
/// ```
@immutable
class NodeAttachment {
  /// Creates a node attachment.
  ///
  /// [nodeId] is the unique ID of the attached Node.
  /// [localPosition] is the position within the Hook's local coordinate system.
  /// [zIndex] controls rendering order (higher values render on top).
  /// [size] is the optional size of the Node (useful for layout calculations).
  /// [metadata] is optional additional data for custom use cases.
  const NodeAttachment({
    required this.nodeId,
    required this.localPosition,
    this.zIndex = 0,
    this.size,
    this.metadata,
  });

  /// The unique ID of the attached Node.
  final String nodeId;

  /// Position of the Node within the Hook's local coordinate system.
  final LocalPosition localPosition;

  /// Rendering order (higher values render on top).
  ///
  /// Nodes with higher z-index values are rendered above nodes with lower values.
  /// This is similar to CSS z-index property.
  ///
  /// Default is 0. Negative values are allowed.
  final int zIndex;

  /// Optional size of the Node.
  ///
  /// Used by layout calculators to determine spacing and wrapping.
  /// If null, a default size may be assumed by the layout calculator.
  final Size? size;

  /// Optional metadata for custom use cases.
  ///
  /// Plugins can use this to store additional information about the attachment,
  /// such as animation state, custom properties, etc.
  final Map<String, dynamic>? metadata;

  /// Creates a copy of this attachment with some fields replaced.
  NodeAttachment copyWith({
    String? nodeId,
    LocalPosition? localPosition,
    int? zIndex,
    Size? size,
    Map<String, dynamic>? metadata,
  }) => NodeAttachment(
      nodeId: nodeId ?? this.nodeId,
      localPosition: localPosition ?? this.localPosition,
      zIndex: zIndex ?? this.zIndex,
      size: size ?? this.size,
      metadata: metadata ?? this.metadata,
    );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NodeAttachment &&
        other.nodeId == nodeId &&
        other.localPosition == localPosition &&
        other.zIndex == zIndex &&
        other.size == size &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(nodeId, localPosition, zIndex, size, metadata);

  @override
  String toString() => 'NodeAttachment(nodeId: $nodeId, position: $localPosition, zIndex: $zIndex${size != null ? ", size: $size" : ""})';

  /// Compares two maps for equality.
  static bool _mapEquals<T>(Map<T, dynamic>? a, Map<T, dynamic>? b) {
    if (a == null) return b == null;
    if (b == null) return false;
    if (a.length != b.length) return false;

    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (a[key] != b[key]) return false;
    }

    return true;
  }
}
