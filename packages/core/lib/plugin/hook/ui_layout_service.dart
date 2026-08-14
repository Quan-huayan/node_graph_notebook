library;

import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../cqrs/commands/command_bus.dart';
import 'coordinate_system.dart';
import 'events/layout_events.dart';
import 'node_attachment.dart';
import 'node_template.dart';
import 'ui_hook_tree.dart';

/// Central service managing the layout of UI hook nodes, their attachments,
/// and spatial relationships. Provides persistence, coordinate queries, and
/// node template-based creation.
class UILayoutService {
  /// Creates a [UILayoutService] with the given [commandBus] and optional
  /// [nodeTemplateRegistry].
  UILayoutService({
    required CommandBus commandBus,
    NodeTemplateRegistry? nodeTemplateRegistry,
  })  : _commandBus = commandBus,
        _nodeTemplateRegistry = nodeTemplateRegistry ?? NodeTemplateRegistry();

  final CommandBus _commandBus;

  late final UIHookNode _rootHook;

  final Map<String, UIHookNode> _hookIndex = {};

  final Map<String, Rect> _hookBoundsIndex = {};

  final Map<String, String> _nodeToHookIndex = {};

  final NodeTemplateRegistry _nodeTemplateRegistry;

  bool _isInitialized = false;

  static const String _kLayoutPersistenceKey = 'ui_layout_state';

  /// Initializes the layout service by creating the hook tree, registering
  /// standard hook points, indexing hooks, and restoring persisted layout.
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('UILayoutService already initialized');
      return;
    }

    debugPrint('Initializing UILayoutService...');

    createHookTree();

    _registerStandardHookPoints();

    _indexHooks(_rootHook);

    await _restoreLayout();

    _isInitialized = true;
    debugPrint('UILayoutService initialized with ${_hookIndex.length} Hooks');
  }

  /// Creates the root hook node for the layout tree.
  void createHookTree() {
    _rootHook = UIHookNode.root();
    debugPrint('Created root Hook');
  }

  void _registerStandardHookPoints() {
    final toolbarHook = UIHookNode(
      id: 'main.toolbar',
      hookPointId: 'main.toolbar',
      localPosition: const LocalPosition.absolute(0, 0),
      size: const Size(double.infinity, 48),
    );
    _rootHook.addChild(toolbarHook);

    final sidebarHook = UIHookNode(
      id: 'sidebar',
      hookPointId: 'sidebar',
      localPosition: const LocalPosition.absolute(0, 48),
      size: const Size(300, double.infinity),
    );
    _rootHook.addChild(sidebarHook);

    final sidebarTopHook = UIHookNode(
      id: 'sidebar.top',
      hookPointId: 'sidebar.top',
      localPosition: const LocalPosition.absolute(0, 0),
      size: const Size(double.infinity, 48),
    );
    sidebarHook.addChild(sidebarTopHook);

    final sidebarBottomHook = UIHookNode(
      id: 'sidebar.bottom',
      hookPointId: 'sidebar.bottom',
      localPosition: const LocalPosition.absolute(0, 48),
      size: const Size(double.infinity, double.infinity),
    );
    sidebarHook.addChild(sidebarBottomHook);

    final graphHook = UIHookNode(
      id: 'graph',
      hookPointId: 'graph',
      localPosition: const LocalPosition.absolute(300, 48),
      size: const Size(double.infinity, double.infinity),
    );
    _rootHook.addChild(graphHook);

    final nodeContextMenuHook = UIHookNode(
      id: 'context_menu.node',
      hookPointId: 'context_menu.node',
      localPosition: const LocalPosition.absolute(0, 0),
      size: const Size(200, 300),
    );
    _rootHook.addChild(nodeContextMenuHook);

    final graphContextMenuHook = UIHookNode(
      id: 'context_menu.graph',
      hookPointId: 'context_menu.graph',
      localPosition: const LocalPosition.absolute(0, 0),
      size: const Size(200, 300),
    );
    _rootHook.addChild(graphContextMenuHook);

    final statusBarHook = UIHookNode(
      id: 'status.bar',
      hookPointId: 'status.bar',
      localPosition: const LocalPosition.absolute(0, 0),
      size: const Size(double.infinity, 24),
    );
    _rootHook.addChild(statusBarHook);

    final settingsHook = UIHookNode(
      id: 'settings',
      hookPointId: 'settings',
      localPosition: const LocalPosition.absolute(0, 0),
      size: const Size(600, 800),
    );
    _rootHook.addChild(settingsHook);

    debugPrint('Registered standard Hook points');
  }

  void _indexHooks(UIHookNode hook) {
    _hookIndex[hook.id] = hook;

    hook.children.forEach(_indexHooks);
  }

  /// Looks up a hook node by its unique [hookId].
  UIHookNode? getHook(String hookId) => _hookIndex[hookId];

  /// Finds a hook node by its [hookPointId] (e.g. 'main.toolbar', 'sidebar').
  UIHookNode? getHookByPointId(String hookPointId) => _rootHook.findByHookPointId(hookPointId);

  /// Attaches a node to the specified hook at the given [position].
  /// Optionally persists the layout state.
  Future<void> attachNode({
    required String nodeId,
    required String hookId,
    required LocalPosition position,
    int zIndex = 0,
    bool persist = true,
  }) async {
    if (!_isInitialized) {
      throw StateError('UILayoutService not initialized');
    }

    final hook = _hookIndex[hookId];
    if (hook == null) {
      throw ArgumentError('Hook not found: $hookId');
    }

    if (_nodeToHookIndex.containsKey(nodeId)) {
      throw StateError('Node $nodeId is already attached to Hook ${_nodeToHookIndex[nodeId]}');
    }

    final attachment = NodeAttachment(
      nodeId: nodeId,
      localPosition: position,
      zIndex: zIndex,
    );

    hook.attachNode(attachment);

    _nodeToHookIndex[nodeId] = hookId;

    _commandBus.publishEvent(NodeAttachedEvent(
      nodeId: nodeId,
      hookId: hookId,
      position: position,
      zIndex: zIndex,
    ));

    debugPrint('Attached Node $nodeId to Hook $hookId at $position');

    if (persist) {
      await _persistLayout();
    }
  }

  /// Detaches a node from its current hook. Optionally persists the layout.
  Future<void> detachNode({
    required String nodeId,
    bool persist = true,
  }) async {
    if (!_isInitialized) {
      throw StateError('UILayoutService not initialized');
    }

    final hookId = _nodeToHookIndex[nodeId];
    if (hookId == null) {
      throw StateError('Node $nodeId is not attached to any Hook');
    }

    final hook = _hookIndex[hookId];
    if (hook == null) {
      throw StateError('Hook $hookId not found in index');
    }

    final attachment = hook.detachNode(nodeId);
    if (attachment == null) {
      throw StateError('Node $nodeId not found in Hook $hookId');
    }

    _nodeToHookIndex.remove(nodeId);

    _commandBus.publishEvent(NodeDetachedEvent(
      nodeId: nodeId,
      hookId: hookId,
      oldPosition: attachment.localPosition,
    ));

    debugPrint('Detached Node $nodeId from Hook $hookId');

    if (persist) {
      await _persistLayout();
    }
  }

  /// Moves a node from its current hook to [targetHookId] at [newPosition].
  /// Optionally updates the z-index and persists the layout.
  Future<void> moveNode({
    required String nodeId,
    required String targetHookId,
    required LocalPosition newPosition,
    int? newZIndex,
    bool persist = true,
  }) async {
    if (!_isInitialized) {
      throw StateError('UILayoutService not initialized');
    }

    final currentHookId = _nodeToHookIndex[nodeId];
    if (currentHookId == null) {
      throw StateError('Node $nodeId is not attached to any Hook');
    }

    final currentHook = _hookIndex[currentHookId];
    if (currentHook == null) {
      throw StateError('Hook $currentHookId not found in index');
    }

    final targetHook = _hookIndex[targetHookId];
    if (targetHook == null) {
      throw ArgumentError('Target Hook not found: $targetHookId');
    }

    final oldAttachment = currentHook.getAttachedNode(nodeId);
    if (oldAttachment == null) {
      throw StateError('Node $nodeId not found in Hook $currentHookId');
    }

    if (currentHookId == targetHookId) {
      final oldPosition = oldAttachment.localPosition;
      currentHook.updateNodePosition(nodeId, newPosition);

      if (newZIndex != null) {
        final updatedAttachment = currentHook.getAttachedNode(nodeId);
        if (updatedAttachment != null) {
          currentHook.detachNode(nodeId);
          currentHook.attachNode(updatedAttachment.copyWith(zIndex: newZIndex));
        }
      }

      _commandBus.publishEvent(NodePositionUpdatedEvent(
        nodeId: nodeId,
        hookId: currentHookId,
        oldPosition: oldPosition,
        newPosition: newPosition,
      ));

      debugPrint('Updated Node $nodeId position in Hook $currentHookId');
    } else {
      currentHook.detachNode(nodeId);
      _nodeToHookIndex.remove(nodeId);

      final newAttachment = NodeAttachment(
        nodeId: nodeId,
        localPosition: newPosition,
        zIndex: newZIndex ?? oldAttachment.zIndex,
        size: oldAttachment.size,
        metadata: oldAttachment.metadata,
      );

      targetHook.attachNode(newAttachment);
      _nodeToHookIndex[nodeId] = targetHookId;

      _commandBus.publishEvent(NodeMovedEvent(
        nodeId: nodeId,
        oldHookId: currentHookId,
        newHookId: targetHookId,
        oldPosition: oldAttachment.localPosition,
        newPosition: newPosition,
      ));

      debugPrint('Moved Node $nodeId from Hook $currentHookId to Hook $targetHookId');
    }

    if (persist) {
      await _persistLayout();
    }
  }

  /// Updates the position of an already-attached node within its current hook.
  /// Optionally persists the layout.
  Future<void> updateNodePosition({
    required String nodeId,
    required LocalPosition newPosition,
    bool persist = true,
  }) async {
    if (!_isInitialized) {
      throw StateError('UILayoutService not initialized');
    }

    final hookId = _nodeToHookIndex[nodeId];
    if (hookId == null) {
      throw StateError('Node $nodeId is not attached to any Hook');
    }

    final hook = _hookIndex[hookId];
    if (hook == null) {
      throw StateError('Hook $hookId not found in index');
    }

    final oldAttachment = hook.getAttachedNode(nodeId);
    if (oldAttachment == null) {
      throw StateError('Node $nodeId not found in Hook $hookId');
    }

    hook.updateNodePosition(nodeId, newPosition);

    _commandBus.publishEvent(NodePositionUpdatedEvent(
      nodeId: nodeId,
      hookId: hookId,
      oldPosition: oldAttachment.localPosition,
      newPosition: newPosition,
    ));

    debugPrint('Updated Node $nodeId position in Hook $hookId');

    if (persist) {
      await _persistLayout();
    }
  }

  /// Updates the render state metadata of a node within its hook.
  void updateNodeRenderState({
    required String nodeId,
    required String renderState,
  }) {
    if (!_isInitialized) {
      throw StateError('UILayoutService not initialized');
    }

    final hookId = _nodeToHookIndex[nodeId];
    if (hookId == null) {
      debugPrint('Node $nodeId is not attached to any Hook, cannot update render state');
      return;
    }

    final hook = _hookIndex[hookId];
    if (hook == null) {
      debugPrint('Hook $hookId not found in index, cannot update render state');
      return;
    }

    final attachment = hook.getAttachedNode(nodeId);
    if (attachment == null) {
      debugPrint('Node $nodeId not found in Hook $hookId, cannot update render state');
      return;
    }

    final updatedMetadata = Map<String, dynamic>.from(attachment.metadata ?? {});
    updatedMetadata['renderState'] = renderState;

    hook.updateNodeMetadata(nodeId, updatedMetadata);

    debugPrint('Updated Node $nodeId render state to: $renderState');
  }

  /// Returns the hook ID that [nodeId] is attached to, or null.
  String? getNodeHookId(String nodeId) => _nodeToHookIndex[nodeId];

  /// Returns the hook ID that [nodeId] is attached to (alias for [getNodeHookId]).
  String? getNodeHook(String nodeId) => getNodeHookId(nodeId);

  /// Finds the deepest hook at the given [screenPosition] based on registered
  /// bounding rectangles.
  String? getHookAtPosition(Offset screenPosition) {
    String? foundHookId;
    var foundDepth = -1;

    for (final entry in _hookBoundsIndex.entries) {
      final hookId = entry.key;
      final bounds = entry.value;

      if (bounds.contains(screenPosition)) {
        final depth = hookId.split('.').length - 1;

        if (depth > foundDepth) {
          foundHookId = hookId;
          foundDepth = depth;
        }
      }
    }

    return foundHookId;
  }

  /// Returns the registered bounding rectangle for [hookId], or null.
  Rect? getHookBounds(String hookId) => _hookBoundsIndex[hookId];

  /// Registers a bounding rectangle for the given [hookId] for hit-testing.
  void registerHookBounds(String hookId, Rect bounds) {
    _hookBoundsIndex[hookId] = bounds;
    debugPrint('Registered bounds for Hook $hookId: $bounds');
  }

  /// Removes the bounding rectangle registration for [hookId].
  void unregisterHookBounds(String hookId) {
    _hookBoundsIndex.remove(hookId);
    debugPrint('Unregistered bounds for Hook $hookId');
  }

  /// Returns the [NodeAttachment] for [nodeId], or null if not attached.
  NodeAttachment? getNodeAttachment(String nodeId) {
    final hookId = _nodeToHookIndex[nodeId];
    if (hookId == null) return null;

    final hook = _hookIndex[hookId];
    if (hook == null) return null;

    return hook.getAttachedNode(nodeId);
  }

  Future<void> _persistLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final data = {
        'nodeAttachments': _nodeToHookIndex.map((nodeId, hookId) {
          final hook = _hookIndex[hookId];
          final attachment = hook?.getAttachedNode(nodeId);
          final localPosition = attachment?.localPosition;
          return MapEntry(nodeId, {
            'hookId': hookId,
            'position': {
              'x': localPosition?.x ?? 0.0,
              'y': localPosition?.y ?? 0.0,
              'type': localPosition?.type.name ?? 'absolute',
              'index': localPosition?.type == PositionType.sequential
                  ? localPosition?.x.toInt()
                  : null,
            },
            'zIndex': attachment?.zIndex ?? 0,
          });
        }),
      };

      final jsonString = jsonEncode(data);
      await prefs.setString(_kLayoutPersistenceKey, jsonString);

      debugPrint('Persisted layout state (${_nodeToHookIndex.length} Nodes)');
    } catch (e) {
      debugPrint('Failed to persist layout state: $e');
    }
  }

  Future<void> _restoreLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_kLayoutPersistenceKey);

      if (jsonString == null) {
        debugPrint('No persisted layout state found');
        return;
      }

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final attachments = data['nodeAttachments'] as Map<String, dynamic>;

      var restoredCount = 0;
      for (final entry in attachments.entries) {
        final nodeId = entry.key;
        final attachmentData = entry.value as Map<String, dynamic>;
        final hookId = attachmentData['hookId'] as String;
        final positionData = attachmentData['position'] as Map<String, dynamic>;
        final zIndex = attachmentData['zIndex'] as int;

        final hook = _hookIndex[hookId];
        if (hook == null) {
          debugPrint('Hook $hookId not found, skipping Node $nodeId');
          continue;
        }

        final positionType = PositionType.values.firstWhere(
          (e) => e.name == positionData['type'],
          orElse: () => PositionType.absolute,
        );

        final x = positionData['x'] as double;
        final y = positionData['y'] as double;
        final index = positionData['index'] as int? ?? x.toInt();

        final position = switch (positionType) {
          PositionType.absolute => LocalPosition.absolute(x, y),
          PositionType.proportional => LocalPosition.proportional(x, y),
          PositionType.sequential => LocalPosition.sequential(index: index),
          PositionType.fill => const LocalPosition.fill(),
        };

        await attachNode(
          nodeId: nodeId,
          hookId: hookId,
          position: position,
          zIndex: zIndex,
          persist: false,
        );

        restoredCount++;
      }

      debugPrint('Restored layout state ($restoredCount Nodes)');
    } catch (e) {
      debugPrint('Failed to restore layout state: $e');
    }
  }

  /// Clears the persisted layout state from shared preferences.
  Future<void> clearPersistedLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLayoutPersistenceKey);
      debugPrint('Cleared persisted layout state');
    } catch (e) {
      debugPrint('Failed to clear layout state: $e');
    }
  }

  /// The root [UIHookNode] of the layout tree.
  UIHookNode get rootHook => _rootHook;

  /// Returns all registered hook nodes.
  List<UIHookNode> getAllHooks() => _hookIndex.values.toList();

  /// Returns an unmodifiable map of nodeId to hookId for all attachments.
  Map<String, String> getAllNodeAttachments() => Map.unmodifiable(_nodeToHookIndex);

  /// The [NodeTemplateRegistry] used for creating nodes from templates.
  NodeTemplateRegistry get nodeTemplateRegistry => _nodeTemplateRegistry;

  /// Registers a [NodeTemplate] for creating and attaching nodes.
  void registerNodeTemplate(NodeTemplate template) {
    _nodeTemplateRegistry.register(template);
    debugPrint('已注册节点模板: ${template.id}');
  }

  /// Creates a node from the template identified by [templateId] and attaches
  /// it to the specified hook. Returns the created [Node].
  Future<Node> createAndAttachNodeFromTemplate({
    required String templateId,
    required String nodeId,
    required String title,
    String? content,
    Map<String, dynamic>? params,
    String? hookId,
    LocalPosition? position,
    int? zIndex,
    bool persist = true,
  }) async {
    if (!_isInitialized) {
      throw StateError('UILayoutService not initialized');
    }

    final node = _nodeTemplateRegistry.createNode(
      templateId: templateId,
      id: nodeId,
      title: title,
      content: content,
      params: params,
    );

    final template = _nodeTemplateRegistry.get(templateId);

    final targetHookId = hookId ?? template?.defaultHookId;
    if (targetHookId == null) {
      throw ArgumentError(
        'No Hook ID provided and template has no default Hook',
      );
    }

    final targetPosition = position ?? template?.defaultPosition;
    if (targetPosition == null) {
      throw ArgumentError(
        'No position provided and template has no default position',
      );
    }

    await attachNode(
      nodeId: nodeId,
      hookId: targetHookId,
      position: targetPosition,
      zIndex: zIndex ?? 0,
      persist: persist,
    );

    debugPrint(
      '已从模板 $templateId 创建并附着节点 $nodeId 到 Hook $targetHookId',
    );

    return node;
  }

  /// Looks up a [NodeTemplate] by its [templateId].
  NodeTemplate? getNodeTemplate(String templateId) => _nodeTemplateRegistry.get(templateId);

  /// Returns all registered [NodeTemplate]s.
  List<NodeTemplate> getAllNodeTemplates() => _nodeTemplateRegistry.getAll();

  /// Returns all [NodeTemplate]s belonging to the given [category].
  List<NodeTemplate> getNodeTemplatesByCategory(String category) => _nodeTemplateRegistry.getByCategory(category);

  /// Returns all available template category names.
  List<String> getNodeTemplateCategories() => _nodeTemplateRegistry.getCategories();

  /// Prints the entire hook tree structure to the debug console.
  void debugPrintTree() {
    debugPrint('=== Hook树结构 ===');
    _rootHook.debugPrintTree();
    debugPrint('=========================');
  }
}