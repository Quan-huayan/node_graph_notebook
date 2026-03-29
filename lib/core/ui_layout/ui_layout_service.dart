/// Core UI Layout Service for managing Hook tree and Node attachments.
///
/// UILayoutService is the central coordinator for the new UI layout system.
/// It manages the hierarchical Hook tree, handles Node attachments/detachments,
/// and coordinates layout recalculation.
///
/// ## Key Responsibilities
///
/// - **Hook Tree Management**: Create and maintain hierarchical Hook structure
/// - **Node Attachments**: Attach/detach/move Nodes between Hooks
/// - **Layout Coordination**: Trigger layout recalculation when state changes
/// - **Persistence**: Save and restore layout state
/// - **Event Publishing**: Publish events for UI updates
///
/// ## Architecture
///
/// ```
/// UILayoutService
///   ├─ Hook Tree (UIHookNode hierarchy)
///   ├─ Node-to-Hook Index (nodeId → hookId)
///   ├─ Hook Registry (hookId → UIHookNode)
///   └─ Layout Calculators (strategy implementations)
/// ```
///
/// ## Usage
///
/// ```dart
/// // Initialize service
/// final layoutService = UILayoutService(eventBus: eventBus);
/// await layoutService.initialize();
///
/// // Attach a Node to a Hook
/// await layoutService.attachNode(
///   nodeId: 'node-1',
///   hookId: 'sidebar',
///   position: LocalPosition.absolute(10, 20),
/// );
///
/// // Move a Node between Hooks
/// await layoutService.moveNode(
///   nodeId: 'node-1',
///   targetHookId: 'graph.view',
///   position: LocalPosition.absolute(100, 200),
/// );
///
/// // Get a Hook for rendering
/// final sidebarHook = layoutService.getHook('sidebar');
/// ```
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../commands/command_bus.dart';
import '../models/node.dart';
import 'coordinate_system.dart';
import 'events/layout_events.dart';
import 'layout_strategy.dart';
import 'node_attachment.dart';
import 'node_template.dart';
import 'ui_hook_tree.dart';

/// Service for managing UI layout with Hook tree and Node attachments.
///
/// This service is the central entry point for all layout operations.
/// It maintains the Hook tree structure and tracks Node attachments.
class UILayoutService {
  /// Creates a UI layout service.
  ///
  /// [commandBus] is required for publishing layout events.
  /// [nodeTemplateRegistry] is optional custom template registry.
  UILayoutService({
    required CommandBus commandBus,
    NodeTemplateRegistry? nodeTemplateRegistry,
  })  : _commandBus = commandBus,
        _nodeTemplateRegistry = nodeTemplateRegistry ?? NodeTemplateRegistry() {
    _registerDefaultCalculators();
  }

  /// CommandBus for publishing layout events.
  final CommandBus _commandBus;

  /// Root Hook of the Hook tree.
  late final UIHookNode _rootHook;

  /// Index of all Hooks by ID for fast lookup.
  final Map<String, UIHookNode> _hookIndex = {};

  /// Index of Node-to-Hook attachments (nodeId → hookId).
  final Map<String, String> _nodeToHookIndex = {};

  /// Registry of layout calculators by strategy.
  final Map<LayoutStrategy, LayoutCalculator> _calculators = {};

  /// Registry of Node templates.
  final NodeTemplateRegistry _nodeTemplateRegistry;

  /// Whether the service has been initialized.
  bool _isInitialized = false;

  /// Persistence key for layout state.
  static const String _kLayoutPersistenceKey = 'ui_layout_state';

  /// Initializes the layout service.
  ///
  /// Creates the Hook tree structure and restores persisted layout state.
  /// Must be called before any other operations.
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('UILayoutService already initialized');
      return;
    }

    debugPrint('Initializing UILayoutService...');

    // Create Hook tree structure
    createHookTree();

    // Register standard Hook points
    _registerStandardHookPoints();

    // Index all Hooks for fast lookup
    _indexHooks(_rootHook);

    // Restore persisted layout state
    await _restoreLayout();

    _isInitialized = true;
    debugPrint('UILayoutService initialized with ${_hookIndex.length} Hooks');
  }

  /// Creates the root Hook tree structure.
  ///
  /// Sets up the basic Hook hierarchy for the application.
  void createHookTree() {
    _rootHook = UIHookNode.root();
    debugPrint('Created root Hook');
  }

  /// Registers standard Hook points used by the application.
  ///
  /// These are the common Hook points that most plugins will use.
  void _registerStandardHookPoints() {
    // Main toolbar Hook
    final toolbarHook = UIHookNode(
      id: 'main.toolbar',
      hookPointId: 'main.toolbar',
      localPosition: const LocalPosition.absolute(0, 0),
      size: const Size(double.infinity, 48),
      layoutConfig: const LayoutConfig(
        strategy: LayoutStrategy.sequential,
        direction: Axis.horizontal,
      ),
    );
    _rootHook.addChild(toolbarHook);

    // Sidebar container Hook
    final sidebarHook = UIHookNode(
      id: 'sidebar',
      hookPointId: 'sidebar',
      localPosition: const LocalPosition.absolute(0, 48),
      size: const Size(300, double.infinity),
      layoutConfig: const LayoutConfig(
        strategy: LayoutStrategy.sequential,
        direction: Axis.vertical,
      ),
    );
    _rootHook.addChild(sidebarHook);

    // Sidebar top (tab bar)
    final sidebarTopHook = UIHookNode(
      id: 'sidebar.top',
      hookPointId: 'sidebar.top',
      localPosition: const LocalPosition.absolute(0, 0),
      size: const Size(double.infinity, 48),
      layoutConfig: const LayoutConfig(
        strategy: LayoutStrategy.sequential,
        direction: Axis.horizontal,
      ),
    );
    sidebarHook.addChild(sidebarTopHook);

    // Sidebar bottom (content)
    final sidebarBottomHook = UIHookNode(
      id: 'sidebar.bottom',
      hookPointId: 'sidebar.bottom',
      localPosition: const LocalPosition.absolute(0, 48),
      size: const Size(double.infinity, double.infinity),
      layoutConfig: const LayoutConfig(
        strategy: LayoutStrategy.sequential,
        direction: Axis.vertical,
      ),
    );
    sidebarHook.addChild(sidebarBottomHook);

    // Graph container Hook
    final graphHook = UIHookNode(
      id: 'graph',
      hookPointId: 'graph',
      localPosition: const LocalPosition.absolute(300, 48),
      size: const Size(double.infinity, double.infinity),
      layoutConfig: const LayoutConfig(
        strategy: LayoutStrategy.absolute,
      ),
    );
    _rootHook.addChild(graphHook);

    // Context menu Hooks
    final nodeContextMenuHook = UIHookNode(
      id: 'context_menu.node',
      hookPointId: 'context_menu.node',
      localPosition: const LocalPosition.absolute(0, 0),
      size: const Size(200, 300),
      layoutConfig: const LayoutConfig(
        strategy: LayoutStrategy.sequential,
        direction: Axis.vertical,
      ),
    );
    _rootHook.addChild(nodeContextMenuHook);

    final graphContextMenuHook = UIHookNode(
      id: 'context_menu.graph',
      hookPointId: 'context_menu.graph',
      localPosition: const LocalPosition.absolute(0, 0),
      size: const Size(200, 300),
      layoutConfig: const LayoutConfig(
        strategy: LayoutStrategy.sequential,
        direction: Axis.vertical,
      ),
    );
    _rootHook.addChild(graphContextMenuHook);

    // Status bar Hook
    final statusBarHook = UIHookNode(
      id: 'status.bar',
      hookPointId: 'status.bar',
      localPosition: const LocalPosition.absolute(0, 0),
      size: const Size(double.infinity, 24),
      layoutConfig: const LayoutConfig(
        strategy: LayoutStrategy.sequential,
        direction: Axis.horizontal,
      ),
    );
    _rootHook.addChild(statusBarHook);

    // Settings Hook
    final settingsHook = UIHookNode(
      id: 'settings',
      hookPointId: 'settings',
      localPosition: const LocalPosition.absolute(0, 0),
      size: const Size(600, 800),
      layoutConfig: const LayoutConfig(
        strategy: LayoutStrategy.sequential,
        direction: Axis.vertical,
      ),
    );
    _rootHook.addChild(settingsHook);

    debugPrint('Registered standard Hook points');
  }

  /// Indexes all Hooks in the tree for fast lookup.
  ///
  /// Traverses the tree recursively and builds a flat index.
  void _indexHooks(UIHookNode hook) {
    _hookIndex[hook.id] = hook;

    for (final child in hook.children) {
      _indexHooks(child);
    }
  }

  /// Registers the default layout calculators.
  void _registerDefaultCalculators() {
    _calculators[LayoutStrategy.absolute] = const AbsoluteLayoutCalculator();
    _calculators[LayoutStrategy.sequential] = const SequentialLayoutCalculator();
    _calculators[LayoutStrategy.flow] = const FlowLayoutCalculator();
    _calculators[LayoutStrategy.grid] = const GridLayoutCalculator();

    debugPrint('Registered default layout calculators');
  }

  /// Gets a Hook by ID.
  ///
  /// [hookId] is the unique ID of the Hook to retrieve.
  ///
  /// Returns the Hook, or null if not found.
  UIHookNode? getHook(String hookId) => _hookIndex[hookId];

  /// Gets a Hook by hook point ID (semantic ID).
  ///
  /// [hookPointId] is the semantic ID of the Hook.
  ///
  /// Returns the first matching Hook, or null if not found.
  UIHookNode? getHookByPointId(String hookPointId) => _rootHook.findByHookPointId(hookPointId);

  /// Attaches a Node to a Hook.
  ///
  /// [nodeId] is the ID of the Node to attach.
  /// [hookId] is the ID of the target Hook.
  /// [position] is the local position within the Hook.
  /// [zIndex] is the rendering order (default: 0).
  /// [persist] whether to persist this attachment (default: true).
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

    // Check if Node is already attached to a Hook
    if (_nodeToHookIndex.containsKey(nodeId)) {
      throw StateError('Node $nodeId is already attached to Hook ${_nodeToHookIndex[nodeId]}');
    }

    // Create attachment
    final attachment = NodeAttachment(
      nodeId: nodeId,
      localPosition: position,
      zIndex: zIndex,
    );

    // Attach to Hook
    hook.attachNode(attachment);

    // Update index
    _nodeToHookIndex[nodeId] = hookId;

    // Publish event
    _commandBus.publishEvent(NodeAttachedEvent(
      nodeId: nodeId,
      hookId: hookId,
      position: position,
      zIndex: zIndex,
    ));

    debugPrint('Attached Node $nodeId to Hook $hookId at $position');

    // Persist if requested
    if (persist) {
      await _persistLayout();
    }
  }

  /// Detaches a Node from its current Hook.
  ///
  /// [nodeId] is the ID of the Node to detach.
  /// [persist] whether to persist this change (default: true).
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

    // Update index
    _nodeToHookIndex.remove(nodeId);

    // Publish event
    _commandBus.publishEvent(NodeDetachedEvent(
      nodeId: nodeId,
      hookId: hookId,
      oldPosition: attachment.localPosition,
    ));

    debugPrint('Detached Node $nodeId from Hook $hookId');

    // Persist if requested
    if (persist) {
      await _persistLayout();
    }
  }

  /// Moves a Node to a different Hook or position.
  ///
  /// [nodeId] is the ID of the Node to move.
  /// [targetHookId] is the ID of the destination Hook.
  /// [newPosition] is the position in the destination Hook.
  /// [newZIndex] is the new rendering order (optional).
  /// [persist] whether to persist this change (default: true).
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

    // Check if moving to same Hook
    if (currentHookId == targetHookId) {
      // Just update position within same Hook
      final oldPosition = oldAttachment.localPosition;
      currentHook.updateNodePosition(nodeId, newPosition);

      if (newZIndex != null) {
        final updatedAttachment = currentHook.getAttachedNode(nodeId);
        if (updatedAttachment != null) {
          currentHook.detachNode(nodeId);
          currentHook.attachNode(updatedAttachment.copyWith(zIndex: newZIndex));
        }
      }

      // Publish event
      _commandBus.publishEvent(NodePositionUpdatedEvent(
        nodeId: nodeId,
        hookId: currentHookId,
        oldPosition: oldPosition,
        newPosition: newPosition,
      ));

      debugPrint('Updated Node $nodeId position in Hook $currentHookId');
    } else {
      // Moving to different Hook
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

      // Publish event
      _commandBus.publishEvent(NodeMovedEvent(
        nodeId: nodeId,
        oldHookId: currentHookId,
        newHookId: targetHookId,
        oldPosition: oldAttachment.localPosition,
        newPosition: newPosition,
      ));

      debugPrint('Moved Node $nodeId from Hook $currentHookId to Hook $targetHookId');
    }

    // Persist if requested
    if (persist) {
      await _persistLayout();
    }
  }

  /// Updates a Node's position within its current Hook.
  ///
  /// [nodeId] is the ID of the Node to update.
  /// [newPosition] is the new local position.
  /// [persist] whether to persist this change (default: true).
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

    // Publish event
    _commandBus.publishEvent(NodePositionUpdatedEvent(
      nodeId: nodeId,
      hookId: hookId,
      oldPosition: oldAttachment.localPosition,
      newPosition: newPosition,
    ));

    debugPrint('Updated Node $nodeId position in Hook $hookId');

    // Persist if requested
    if (persist) {
      await _persistLayout();
    }
  }

  /// Gets the Hook a Node is attached to.
  ///
  /// [nodeId] is the ID of the Node.
  ///
  /// Returns the Hook ID, or null if the Node is not attached.
  String? getNodeHookId(String nodeId) => _nodeToHookIndex[nodeId];

  /// Gets the attachment for a Node.
  ///
  /// [nodeId] is the ID of the Node.
  ///
  /// Returns the attachment, or null if the Node is not attached.
  NodeAttachment? getNodeAttachment(String nodeId) {
    final hookId = _nodeToHookIndex[nodeId];
    if (hookId == null) return null;

    final hook = _hookIndex[hookId];
    if (hook == null) return null;

    return hook.getAttachedNode(nodeId);
  }

  /// Recalculates layout for a Hook.
  ///
  /// [hookId] is the ID of the Hook to recalculate.
  void recalculateLayout(String hookId) {
    final hook = _hookIndex[hookId];
    if (hook == null) {
      throw ArgumentError('Hook not found: $hookId');
    }

    final calculator = _calculators[hook.layoutConfig.strategy];
    if (calculator == null) {
      throw ArgumentError('No calculator for strategy: ${hook.layoutConfig.strategy}');
    }

    final result = calculator.calculate(hook);

    // Update positions for children
    for (final entry in result.positions.entries) {
      final childId = entry.key;
      final newPosition = entry.value;

      // Check if this is a child Hook or attached Node
      final child = hook.findChild(childId);
      if (child != null) {
        // Child Hook position is immutable after creation
        // (defined in constructor, not updated here)
        continue;
      }

      // This is an attached Node
      final attachment = hook.getAttachedNode(childId);
      if (attachment != null) {
        hook.updateNodePosition(childId, newPosition);
      }
    }

    // Publish event
    _commandBus.publishEvent(LayoutRecalculatedEvent(
      hookId: hookId,
      hasChanges: true,
    ));

    debugPrint('Recalculated layout for Hook $hookId');
  }

  /// Persists the current layout state.
  Future<void> _persistLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create persistence data
      final data = {
        'nodeAttachments': _nodeToHookIndex.map((nodeId, hookId) {
          final hook = _hookIndex[hookId];
          final attachment = hook?.getAttachedNode(nodeId);
          return MapEntry(nodeId, {
            'hookId': hookId,
            'position': {
              'x': attachment?.localPosition.x ?? 0.0,
              'y': attachment?.localPosition.y ?? 0.0,
              'type': attachment?.localPosition.type.name ?? 'absolute',
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

  /// Restores the layout state from persistence.
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

        // Recreate LocalPosition
        final positionType = PositionType.values.firstWhere(
          (e) => e.name == positionData['type'],
          orElse: () => PositionType.absolute,
        );

        final x = positionData['x'] as double;
        final y = positionData['y'] as double;
        final index = positionData['index'] as int?;

        final position = switch (positionType) {
          PositionType.absolute => LocalPosition.absolute(x, y),
          PositionType.proportional => LocalPosition.proportional(x, y),
          PositionType.sequential => LocalPosition.sequential(index: index ?? 0),
          PositionType.fill => const LocalPosition.fill(),
        };

        // Create attachment (this will be recreated by attachNode)
        await attachNode(
          nodeId: nodeId,
          hookId: hookId,
          position: position,
          zIndex: zIndex,
          persist: false, // Don't persist while restoring
        );

        restoredCount++;
      }

      debugPrint('Restored layout state ($restoredCount Nodes)');
    } catch (e) {
      debugPrint('Failed to restore layout state: $e');
    }
  }

  /// Clears all persisted layout state.
  Future<void> clearPersistedLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLayoutPersistenceKey);
      debugPrint('Cleared persisted layout state');
    } catch (e) {
      debugPrint('Failed to clear layout state: $e');
    }
  }

  /// Gets the root Hook of the tree.
  UIHookNode get rootHook => _rootHook;

  /// Gets all Hooks in the tree.
  List<UIHookNode> getAllHooks() => _hookIndex.values.toList();

  /// Gets all Node-to-Hook attachments.
  Map<String, String> getAllNodeAttachments() => Map.unmodifiable(_nodeToHookIndex);

  // ===== Node Template Methods =====

  /// Gets the Node template registry.
  ///
  /// Plugins use this registry to register their Node templates.
  NodeTemplateRegistry get nodeTemplateRegistry => _nodeTemplateRegistry;

  /// Registers a Node template.
  ///
  /// [template] is the template to register.
  ///
  /// This is a convenience method that delegates to the NodeTemplateRegistry.
  /// Plugins typically call this during initialization.
  void registerNodeTemplate(NodeTemplate template) {
    _nodeTemplateRegistry.register(template);
    debugPrint('Registered Node template: ${template.id}');
  }

  /// Creates a Node from a template and attaches it to a Hook.
  ///
  /// [templateId] is the ID of the template to use.
  /// [nodeId] is the unique ID for the new Node.
  /// [title] is the Node's title.
  /// [content] is optional Node content.
  /// [params] are optional additional parameters for the factory.
  /// [hookId] is the target Hook ID (uses template default if not provided).
  /// [position] is the position for the Node (uses template default if not provided).
  /// [zIndex] is the rendering order.
  /// [persist] whether to persist this attachment.
  ///
  /// Throws [ArgumentError] if template not found.
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

    // Create Node from template
    final node = _nodeTemplateRegistry.createNode(
      templateId: templateId,
      id: nodeId,
      title: title,
      content: content,
      params: params,
    );

    // Get template for defaults
    final template = _nodeTemplateRegistry.get(templateId);

    // Determine target Hook
    final targetHookId = hookId ?? template?.defaultHookId;
    if (targetHookId == null) {
      throw ArgumentError(
        'No Hook ID provided and template has no default Hook',
      );
    }

    // Determine position
    final targetPosition = position ?? template?.defaultPosition;
    if (targetPosition == null) {
      throw ArgumentError(
        'No position provided and template has no default position',
      );
    }

    // Attach Node to Hook
    await attachNode(
      nodeId: nodeId,
      hookId: targetHookId,
      position: targetPosition,
      zIndex: zIndex ?? 0,
      persist: persist,
    );

    debugPrint(
      'Created and attached Node $nodeId from template $templateId to Hook $targetHookId',
    );

    return node;
  }

  /// Gets a Node template by ID.
  ///
  /// [templateId] is the template ID.
  ///
  /// Returns the template, or null if not found.
  NodeTemplate? getNodeTemplate(String templateId) => _nodeTemplateRegistry.get(templateId);

  /// Gets all Node templates.
  ///
  /// Returns an unmodifiable list of all registered templates.
  List<NodeTemplate> getAllNodeTemplates() => _nodeTemplateRegistry.getAll();

  /// Gets Node templates by category.
  ///
  /// [category] is the category to filter by.
  ///
  /// Returns a list of templates in the category.
  List<NodeTemplate> getNodeTemplatesByCategory(String category) => _nodeTemplateRegistry.getByCategory(category);

  /// Gets all Node template categories.
  List<String> getNodeTemplateCategories() => _nodeTemplateRegistry.getCategories();

  /// Debug method to print the Hook tree structure.
  void debugPrintTree() {
    debugPrint('=== Hook Tree Structure ===');
    _rootHook.debugPrintTree();
    debugPrint('=========================');
  }
}
