library;

import 'package:flutter/material.dart';
import 'coordinate_system.dart';
import 'node_attachment.dart';

/// A node in the UI hook tree, representing a spatial region that can contain
/// child hooks and attached nodes. Each hook node has a position, size, and
/// belongs to a hook point identified by [hookPointId].
class UIHookNode {
  /// Creates a [UIHookNode] with the given properties and optionally adds it
  /// as a child of [parent].
  UIHookNode({
    required this.id,
    required this.hookPointId,
    required this.localPosition,
    required this.size,
    this.parent,
  }) {
    if (parent != null) {
      parent!._children.add(this);
    }
  }

  /// Creates the root hook node with id 'root' and infinite size.
  factory UIHookNode.root() => UIHookNode(
      id: 'root',
      hookPointId: 'root',
      localPosition: const LocalPosition.absolute(0, 0),
      size: Size.infinite,
    );

  /// Unique identifier for this hook node.
  final String id;

  /// The hook point this node is associated with (e.g. 'main.toolbar').
  final String hookPointId;

  /// The local position of this node relative to its parent.
  final LocalPosition localPosition;

  /// The size of this hook node.
  final Size size;

  /// The parent hook node, or null if this is the root.
  UIHookNode? parent;

  final List<UIHookNode> _children = [];

  final Map<String, NodeAttachment> _attachedNodes = {};

  /// An unmodifiable list of this node's child hooks.
  List<UIHookNode> get children => List.unmodifiable(_children);

  /// An unmodifiable map of node IDs to their [NodeAttachment]s.
  Map<String, NodeAttachment> get attachedNodes => Map.unmodifiable(_attachedNodes);

  /// Adds [child] as a child of this hook node. Throws if child already has
  /// a parent.
  void addChild(UIHookNode child) {
    if (child.parent != null) {
      throw StateError('Child Hook already has a parent: ${child.id}');
    }

    child.parent = this;
    _children.add(child);
  }

  /// Removes and returns the child with [childId], or null if not found.
  UIHookNode? removeChild(String childId) {
    final index = _children.indexWhere((child) => child.id == childId);
    if (index < 0) return null;

    final child = _children.removeAt(index);
    child.parent = null;
    return child;
  }

  /// Recursively searches for a child hook by its [childId].
  UIHookNode? findChild(String childId) {
    for (final child in _children) {
      if (child.id == childId) return child;

      final found = child.findChild(childId);
      if (found != null) return found;
    }

    return null;
  }

  /// Recursively searches for a child hook by its [hookPointId].
  UIHookNode? findByHookPointId(String hookPointId) {
    if (this.hookPointId == hookPointId) return this;

    for (final child in _children) {
      final found = child.findByHookPointId(hookPointId);
      if (found != null) return found;
    }

    return null;
  }

  /// Attaches a [NodeAttachment] to this hook. Throws if the node is already
  /// attached.
  void attachNode(NodeAttachment attachment) {
    if (_attachedNodes.containsKey(attachment.nodeId)) {
      throw StateError('Node already attached to this Hook: ${attachment.nodeId}');
    }

    _attachedNodes[attachment.nodeId] = attachment;
  }

  /// Detaches and returns the [NodeAttachment] for [nodeId], or null.
  NodeAttachment? detachNode(String nodeId) => _attachedNodes.remove(nodeId);

  /// Updates the position of an attached node to [newPosition].
  void updateNodePosition(String nodeId, LocalPosition newPosition) {
    final attachment = _attachedNodes[nodeId];
    if (attachment == null) {
      throw StateError('Node not attached to this Hook: $nodeId');
    }

    _attachedNodes[nodeId] = attachment.copyWith(localPosition: newPosition);
  }

  /// Updates the metadata of an attached node.
  void updateNodeMetadata(String nodeId, Map<String, dynamic> metadata) {
    final attachment = _attachedNodes[nodeId];
    if (attachment == null) {
      throw StateError('Node not attached to this Hook: $nodeId');
    }

    _attachedNodes[nodeId] = attachment.copyWith(metadata: metadata);
  }

  /// Returns the [NodeAttachment] for [nodeId], or null.
  NodeAttachment? getAttachedNode(String nodeId) => _attachedNodes[nodeId];

  /// Returns true if [nodeId] is attached to this hook.
  bool hasNodeAttached(String nodeId) => _attachedNodes.containsKey(nodeId);

  /// Returns the path from the root to this node as a list of IDs.
  List<String> getPath() {
    final path = <String>[id];
    var current = parent;

    while (current != null) {
      path.insert(0, current.id);
      current = current.parent;
    }

    return path;
  }

  /// Returns the depth of this node in the tree (root is depth 0).
  int getDepth() {
    var depth = 0;
    var current = parent;

    while (current != null) {
      depth++;
      current = current.parent;
    }

    return depth;
  }

  /// Returns all descendant hook nodes in a flat list.
  List<UIHookNode> getDescendants() {
    final descendants = <UIHookNode>[];

    for (final child in _children) {
      descendants.add(child);
      descendants.addAll(child.getDescendants());
    }

    return descendants;
  }

  /// Returns the total number of attached nodes in this subtree.
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

  /// Prints this node and its subtree in a tree-like format to the debug
  /// console, with optional [indent] level.
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