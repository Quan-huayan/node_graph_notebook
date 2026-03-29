/// Hierarchical UI Hook tree structure for layout management.
///
/// This module defines the [UIHookNode] class, which represents a Hook
/// in the hierarchical layout tree. Hooks can contain child Hooks and
/// attached Nodes, forming a tree structure that defines the UI layout.
///
/// ## Key Concepts
///
/// - **UIHookNode**: A node in the Hook tree (container for other Hooks or Nodes)
/// - **Hierarchy**: Hooks can have parent and child Hooks
/// - **Attachments**: Nodes can be attached to Hooks at specific positions
/// - **Coordinate System**: Each Hook has its own local coordinate system
/// - **Layout Configuration**: Each Hook defines how its children are arranged
///
/// ## Usage
///
/// ```dart
/// // Create root Hook
/// final root = UIHookNode.root();
///
/// // Create sidebar Hook
/// final sidebar = UIHookNode(
///   hookPointId: 'sidebar',
///   localPosition: LocalPosition.absolute(0, 0),
///   size: Size(300, 800),
///   layoutConfig: LayoutConfig(
///     strategy: LayoutStrategy.sequential,
///     direction: Axis.vertical,
///   ),
/// );
/// root.addChild(sidebar);
///
/// // Attach a Node to sidebar
/// final attachment = NodeAttachment(
///   nodeId: 'node-1',
///   localPosition: LocalPosition.sequential(index: 0),
/// );
/// sidebar.attachNode(attachment);
/// ```
library;

import 'package:flutter/material.dart';
import 'coordinate_system.dart';
import 'layout_strategy.dart';
import 'node_attachment.dart';

/// A node in the hierarchical UI Hook tree.
///
/// UIHookNodes form a tree structure where each Hook can contain:
/// - Child Hooks (nested containers)
/// - Attached Nodes (actual content)
///
/// Hooks define the layout strategy for their children using [LayoutConfig].
/// Each Hook has its own local coordinate system for positioning children.
///
/// ## Hook Tree Structure
///
/// ```
/// Root Hook (main)
/// ├─ Sidebar Hook
/// │  ├─ Sidebar.top Hook (tab bar)
/// │  └─ Sidebar.bottom Hook (content)
/// │     ├─ Node: "folder-tree"
/// │     └─ Node: "node-list"
/// └─ Graph Hook
///    └─ Node: "graph-canvas"
/// ```
///
/// ## Coordinate Systems
///
/// Each Hook has a local coordinate system where (0, 0) is the top-left
/// corner of the Hook. Child positions are relative to their parent Hook.
///
/// ## Lifecycle
///
/// 1. **Creation**: Hook created with ID and configuration
/// 2. **Attachment**: Hook added as child to parent Hook
/// 3. **Population**: Child Hooks and Nodes attached
/// 4. **Layout**: Positions calculated based on layout strategy
/// 5. **Rendering**: Hook tree rendered to Flutter Widget tree or Flame components
/// 6. **Detachment**: Hook removed from parent (or entire tree destroyed)
class UIHookNode {

  /// Creates a Hook with the given properties.
  ///
  /// [id] is the unique identifier for this Hook in the tree.
  /// [hookPointId] is the semantic ID (e.g., 'sidebar', 'toolbar').
  /// [localPosition] is the position within the parent Hook's coordinate system.
  /// [size] is the size of this Hook (infinite for auto-sizing).
  /// [layoutConfig] defines how children are arranged.
  /// [parent] is the parent Hook (set automatically when added as child).
  UIHookNode({
    required this.id,
    required this.hookPointId,
    required this.localPosition,
    required this.size,
    required this.layoutConfig,
    this.parent,
  }) {
    if (parent != null) {
      parent!._children.add(this);
    }
  }
  /// Creates a root Hook (no parent).
  ///
  /// Root Hooks have:
  /// - ID: 'root'
  /// - Hook point ID: 'root'
  /// - Local position: (0, 0)
  /// - Size: screen size (infinite by default)
  /// - Layout: sequential vertical
  factory UIHookNode.root() => UIHookNode(
      id: 'root',
      hookPointId: 'root',
      localPosition: const LocalPosition.absolute(0, 0),
      size: Size.infinite,
      layoutConfig: const LayoutConfig(
        strategy: LayoutStrategy.sequential,
        direction: Axis.vertical,
      ),
    );

  /// Unique identifier for this Hook in the tree.
  ///
  /// This is different from [hookPointId] which is semantic.
  /// Multiple Hooks can have the same hookPointId but different IDs.
  final String id;

  /// Semantic identifier for this type of Hook.
  ///
  /// Examples: 'sidebar', 'toolbar', 'context_menu', etc.
  /// Used for routing Node attachments to the correct Hook type.
  final String hookPointId;

  /// Position within the parent Hook's coordinate system.
  final LocalPosition localPosition;

  /// Size of this Hook.
  ///
  /// Use [Size.infinite] for auto-sizing (size determined by content).
  final Size size;

  /// Layout configuration for arranging children.
  final LayoutConfig layoutConfig;

  /// Parent Hook (null for root).
  UIHookNode? parent;

  /// Child Hooks (nested containers).
  final List<UIHookNode> _children = [];

  /// Attached Nodes (actual content, keyed by nodeId).
  final Map<String, NodeAttachment> _attachedNodes = {};

  /// Unmodifiable list of child Hooks.
  List<UIHookNode> get children => List.unmodifiable(_children);

  /// Unmodifiable map of attached Nodes.
  Map<String, NodeAttachment> get attachedNodes => Map.unmodifiable(_attachedNodes);

  /// Adds a child Hook to this Hook.
  ///
  /// [child] is the Hook to add as a child.
  ///
  /// Throws [StateError] if the child already has a parent.
  void addChild(UIHookNode child) {
    if (child.parent != null) {
      throw StateError('Child Hook already has a parent: ${child.id}');
    }

    child.parent = this;
    _children.add(child);
  }

  /// Removes a child Hook from this Hook.
  ///
  /// [childId] is the ID of the child to remove.
  ///
  /// Returns the removed Hook, or null if not found.
  UIHookNode? removeChild(String childId) {
    final index = _children.indexWhere((child) => child.id == childId);
    if (index < 0) return null;

    final child = _children.removeAt(index);
    child.parent = null;
    return child;
  }

  /// Finds a child Hook by ID.
  ///
  /// [childId] is the ID to search for.
  ///
  /// Returns the child Hook, or null if not found.
  UIHookNode? findChild(String childId) {
    for (final child in _children) {
      if (child.id == childId) return child;

      // Search recursively
      final found = child.findChild(childId);
      if (found != null) return found;
    }

    return null;
  }

  /// Finds a descendant Hook by hook point ID.
  ///
  /// [hookPointId] is the semantic ID to search for.
  ///
  /// Returns the first matching Hook, or null if not found.
  UIHookNode? findByHookPointId(String hookPointId) {
    if (this.hookPointId == hookPointId) return this;

    for (final child in _children) {
      final found = child.findByHookPointId(hookPointId);
      if (found != null) return found;
    }

    return null;
  }

  /// Attaches a Node to this Hook.
  ///
  /// [attachment] defines how the Node is attached and positioned.
  ///
  /// Throws [StateError] if a Node with the same ID is already attached.
  void attachNode(NodeAttachment attachment) {
    if (_attachedNodes.containsKey(attachment.nodeId)) {
      throw StateError('Node already attached to this Hook: ${attachment.nodeId}');
    }

    _attachedNodes[attachment.nodeId] = attachment;
  }

  /// Detaches a Node from this Hook.
  ///
  /// [nodeId] is the ID of the Node to detach.
  ///
  /// Returns the removed attachment, or null if not found.
  NodeAttachment? detachNode(String nodeId) => _attachedNodes.remove(nodeId);

  /// Updates the position of an attached Node.
  ///
  /// [nodeId] is the ID of the Node to update.
  /// [newPosition] is the new local position for the Node.
  ///
  /// Throws [StateError] if the Node is not attached.
  void updateNodePosition(String nodeId, LocalPosition newPosition) {
    final attachment = _attachedNodes[nodeId];
    if (attachment == null) {
      throw StateError('Node not attached to this Hook: $nodeId');
    }

    _attachedNodes[nodeId] = attachment.copyWith(localPosition: newPosition);
  }

  /// Gets an attached Node by ID.
  ///
  /// [nodeId] is the ID of the Node to get.
  ///
  /// Returns the attachment, or null if not found.
  NodeAttachment? getAttachedNode(String nodeId) => _attachedNodes[nodeId];

  /// Checks if a Node is attached to this Hook.
  ///
  /// [nodeId] is the ID of the Node to check.
  bool hasNodeAttached(String nodeId) => _attachedNodes.containsKey(nodeId);

  /// Gets the path from root to this Hook.
  ///
  /// Returns a list of Hook IDs from root to this Hook (inclusive).
  ///
  /// Example: `['root', 'sidebar', 'sidebar.bottom']`
  List<String> getPath() {
    final path = <String>[id];
    var current = parent;

    while (current != null) {
      path.insert(0, current.id);
      current = current.parent;
    }

    return path;
  }

  /// Calculates the depth of this Hook in the tree.
  ///
  /// Returns 0 for root, 1 for root's children, etc.
  int getDepth() {
    var depth = 0;
    var current = parent;

    while (current != null) {
      depth++;
      current = current.parent;
    }

    return depth;
  }

  /// Gets all descendants of this Hook (children, grandchildren, etc.).
  ///
  /// Returns a flattened list of all descendant Hooks.
  List<UIHookNode> getDescendants() {
    final descendants = <UIHookNode>[];

    for (final child in _children) {
      descendants.add(child);
      descendants.addAll(child.getDescendants());
    }

    return descendants;
  }

  /// Gets the total number of Nodes attached to this Hook and all descendants.
  ///
  /// Useful for debugging and analytics.
  int getTotalAttachedNodeCount() {
    var count = _attachedNodes.length;

    for (final child in _children) {
      count += child.getTotalAttachedNodeCount();
    }

    return count;
  }

  @override
  String toString() {
    final childCount = _children.length;
    final nodeCount = _attachedNodes.length;
    final depth = getDepth();

    return 'UIHookNode(id: $id, hookPointId: $hookPointId, depth: $depth, children: $childCount, nodes: $nodeCount)';
  }

  /// Prints the tree structure starting from this Hook (for debugging).
  ///
  /// [indent] is the indentation level (used for recursion).
  void debugPrintTree({int indent = 0}) {
    final indentation = '  ' * indent;
    final childInfo = '${_children.length} children';
    final nodeInfo = '${_attachedNodes.length} nodes';

    debugPrint('$indentation├─ $id ($hookPointId) [$childInfo, $nodeInfo]');

    for (final child in _children) {
      child.debugPrintTree(indent: indent + 1);
    }

    for (final attachment in _attachedNodes.values) {
      debugPrint('$indentation  └─ Node: ${attachment.nodeId}');
    }
  }
}
