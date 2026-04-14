/// 核心UI布局服务，用于管理Hook树和节点附着。
///
/// UILayoutService是新UI布局系统的中央协调器。
/// 它管理分层Hook树，处理节点的附着/分离，
/// 并协调布局重新计算。
///
/// ## 主要职责
///
/// - **Hook树管理**：创建和维护分层Hook结构
/// - **节点附着**：在Hook之间附着/分离/移动节点
/// - **布局协调**：状态变化时触发布局重新计算
/// - **持久化**：保存和恢复布局状态
/// - **事件发布**：发布UI更新事件
///
/// ## 架构
///
/// ```
/// UILayoutService
///   ├─ Hook树 (UIHookNode层级)
///   ├─ 节点到Hook索引 (nodeId → hookId)
///   ├─ Hook注册表 (hookId → UIHookNode)
///   └─ 布局计算器 (策略实现)
/// ```
///
/// ## 使用方式
///
/// ```dart
/// // 初始化服务
/// final layoutService = UILayoutService(eventBus: eventBus);
/// await layoutService.initialize();
///
/// // 将节点附着到Hook
/// await layoutService.attachNode(
///   nodeId: 'node-1',
///   hookId: 'sidebar',
///   position: LocalPosition.absolute(10, 20),
/// );
///
/// // 在Hook之间移动节点
/// await layoutService.moveNode(
///   nodeId: 'node-1',
///   targetHookId: 'graph.view',
///   position: LocalPosition.absolute(100, 200),
/// );
///
/// // 获取Hook用于渲染
/// final sidebarHook = layoutService.getHook('sidebar');
/// ```
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cqrs/commands/command_bus.dart';
import '../models/node.dart';
import 'coordinate_system.dart';
import 'events/layout_events.dart';
import 'layout_strategy.dart';
import 'node_attachment.dart';
import 'node_template.dart';
import 'ui_hook_tree.dart';

/// 用于管理带有Hook树和节点附着的UI布局的服务。
///
/// 此服务是所有布局操作的中央入口点。
/// 它维护Hook树结构并跟踪节点附着。
class UILayoutService {
  /// 创建UI布局服务。
  ///
  /// [commandBus] 用于发布布局事件。
  /// [nodeTemplateRegistry] 可选的自定义模板注册表。
  UILayoutService({
    required CommandBus commandBus,
    NodeTemplateRegistry? nodeTemplateRegistry,
  })  : _commandBus = commandBus,
        _nodeTemplateRegistry = nodeTemplateRegistry ?? NodeTemplateRegistry() {
    _registerDefaultCalculators();
  }

  /// 用于发布布局事件的命令总线。
  final CommandBus _commandBus;

  /// Hook树的根Hook。
  late final UIHookNode _rootHook;

  /// 所有Hook的ID索引，用于快速查找。
  final Map<String, UIHookNode> _hookIndex = {};

  /// Hook的屏幕边界索引 (hookId → screenBounds)
  /// 用于快速查找位置下的Hook
  final Map<String, Rect> _hookBoundsIndex = {};

  /// 节点到Hook附着的索引 (nodeId → hookId)。
  final Map<String, String> _nodeToHookIndex = {};

  /// 按策略分类的布局计算器注册表。
  final Map<LayoutStrategy, LayoutCalculator> _calculators = {};

  /// 节点模板注册表。
  final NodeTemplateRegistry _nodeTemplateRegistry;

  /// 服务是否已初始化。
  bool _isInitialized = false;

  /// 布局状态的持久化键。
  static const String _kLayoutPersistenceKey = 'ui_layout_state';

  /// 初始化布局服务。
  ///
  /// 创建Hook树结构并恢复持久化的布局状态。
  /// 必须在执行任何其他操作之前调用。
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

  /// 创建根Hook树结构。
  ///
  /// 为应用程序设置基本的Hook层次结构。
  void createHookTree() {
    _rootHook = UIHookNode.root();
    debugPrint('Created root Hook');
  }

  /// 注册应用程序使用的标准Hook点。
  ///
  /// 这些是大多数插件将使用的通用Hook点。
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

  /// 为快速查找索引树中的所有Hook。
  ///
  /// 递归遍历树并构建扁平索引。
  void _indexHooks(UIHookNode hook) {
    _hookIndex[hook.id] = hook;

    hook.children.forEach(_indexHooks);
  }

  /// 注册默认布局计算器。
  void _registerDefaultCalculators() {
    _calculators[LayoutStrategy.absolute] = const AbsoluteLayoutCalculator();
    _calculators[LayoutStrategy.sequential] = const SequentialLayoutCalculator();
    _calculators[LayoutStrategy.flow] = const FlowLayoutCalculator();
    _calculators[LayoutStrategy.grid] = const GridLayoutCalculator();

    debugPrint('Registered default layout calculators');
  }

  /// 通过ID获取Hook。
  ///
  /// [hookId] 是要检索的Hook的唯一ID。
  ///
  /// 返回Hook，如果未找到则返回null。
  UIHookNode? getHook(String hookId) => _hookIndex[hookId];

  /// 通过Hook点ID（语义ID）获取Hook。
  ///
  /// [hookPointId] 是Hook的语义ID。
  ///
  /// 返回第一个匹配的Hook，如果未找到则返回null。
  UIHookNode? getHookByPointId(String hookPointId) => _rootHook.findByHookPointId(hookPointId);

  /// 将节点附着到Hook。
  ///
  /// [nodeId] 是要附着的节点的ID。
  /// [hookId] 是目标Hook的ID。
  /// [position] 是Hook内的本地位置。
  /// [zIndex] 是渲染顺序（默认：0）。
  /// [persist] 是否持久化此附着（默认：true）。
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

  /// 从当前Hook分离节点。
  ///
  /// [nodeId] 是要分离的节点的ID。
  /// [persist] 是否持久化此更改（默认：true）。
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

  /// 将节点移动到不同的Hook或位置。
  ///
  /// [nodeId] 是要移动的节点的ID。
  /// [targetHookId] 是目标Hook的ID。
  /// [newPosition] 是目标Hook中的位置。
  /// [newZIndex] 是新的渲染顺序（可选）。
  /// [persist] 是否持久化此更改（默认：true）。
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

  /// Updates the position of a Node within its current Hook.
  ///
  /// [nodeId] is the ID of the Node to update.
  /// [newPosition] is the new local position.
  /// [persist] Whether to persist this change (default: true).
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

  /// Updates the render state of a Node.
  ///
  /// [nodeId] is the ID of the Node to update.
  /// [renderState] is the new render state (e.g., 'dragging', 'hovering', 'rendering').
  ///
  /// **Architecture:**
  /// - Stores render state in NodeAttachment metadata
  /// - Hooks can read this state to adjust visual effects
  /// - Example: dragging → semi-transparent, hovering → highlighted
  ///
  /// **Usage:**
  /// ```dart
  /// // Set node to dragging state
  /// await layoutService.updateNodeRenderState(
  ///   nodeId: 'node-1',
  ///   renderState: 'dragging',
  /// );
  ///
  /// // Reset to normal rendering
  /// await layoutService.updateNodeRenderState(
  ///   nodeId: 'node-1',
  ///   renderState: 'rendering',
  /// );
  /// ```
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

    // Update metadata with new render state
    final updatedMetadata = Map<String, dynamic>.from(attachment.metadata ?? {});
    updatedMetadata['renderState'] = renderState;

    hook.updateNodeMetadata(nodeId, updatedMetadata);

    debugPrint('Updated Node $nodeId render state to: $renderState');
  }

  /// 获取节点所附着的Hook。
  ///
  /// [nodeId] 是节点的ID。
  ///
  /// 返回Hook ID，如果节点未附着则返回null。
  String? getNodeHookId(String nodeId) => _nodeToHookIndex[nodeId];

  /// 获取节点当前所在的Hook（别名方法，用于Flowing UI）
  ///
  /// [nodeId] 是节点的ID。
  ///
  /// 返回Hook ID，如果节点未附着则返回null。
  ///
  /// **架构说明：**
  /// - 这是getNodeHookId的别名，提供更语义化的名称
  /// - 用于NodeDragController检测节点的当前Hook
  String? getNodeHook(String nodeId) => getNodeHookId(nodeId);

  /// 获取指定屏幕位置下的Hook
  ///
  /// [screenPosition] - 屏幕坐标位置
  ///
  /// 返回包含该位置的Hook ID，如果位置不在任何Hook内则返回null
  ///
  /// **架构说明：**
  /// - 遍历所有已注册边界的Hook
  /// - 检查位置是否在Hook边界内
  /// - 优先返回最具体的Hook（子Hook优先于父Hook）
  /// - 用于NodeDragController检测拖拽目标
  ///
  /// **使用示例：**
  /// ```dart
  /// final hookId = layoutService.getHookAtPosition(Offset(100, 200));
  /// if (hookId == 'sidebar.nodeList') {
  ///   // 拖拽到sidebar节点列表
  /// }
  /// ```
  String? getHookAtPosition(Offset screenPosition) {
    String? foundHookId;
    var foundDepth = -1;

    // 遍历所有Hook，找到包含该位置且最具体的Hook
    for (final entry in _hookBoundsIndex.entries) {
      final hookId = entry.key;
      final bounds = entry.value;

      if (bounds.contains(screenPosition)) {
        // 计算Hook的深度（根据ID中的点数）
        // 例如：'sidebar.bottom.nodeList' 深度为2
        final depth = hookId.split('.').length - 1;

        // 选择最具体的Hook（深度最大的）
        if (depth > foundDepth) {
          foundHookId = hookId;
          foundDepth = depth;
        }
      }
    }

    return foundHookId;
  }

  /// 获取Hook的屏幕边界
  ///
  /// [hookId] - Hook ID
  ///
  /// 返回Hook的屏幕边界矩形，如果Hook未注册边界则返回null
  ///
  /// **架构说明：**
  /// - 从边界索引中查找Hook的屏幕边界
  /// - 用于NodeDragController高亮显示目标区域
  /// - Hook渲染器负责注册边界（通过registerHookBounds）
  ///
  /// **使用示例：**
  /// ```dart
  /// final bounds = layoutService.getHookBounds('sidebar');
  /// if (bounds != null) {
  ///   print('Sidebar bounds: $bounds');
  /// }
  /// ```
  Rect? getHookBounds(String hookId) => _hookBoundsIndex[hookId];

  /// 注册Hook的屏幕边界
  ///
  /// [hookId] - Hook ID
  /// [bounds] - Hook的屏幕边界（屏幕坐标）
  ///
  /// **架构说明：**
  /// - Hook渲染器调用此方法注册其屏幕边界
  /// - 边界用于getHookAtPosition快速查找
  /// - 应在Hook渲染时或窗口大小变化时更新
  ///
  /// **使用示例：**
  /// ```dart
  /// // 在Sidebar的build方法中
  /// @override
  /// Widget build(BuildContext context) {
  ///   // 渲染后注册边界
  ///   WidgetsBinding.instance.addPostFrameCallback((_) {
  ///     final renderBox = context.findRenderObject() as RenderBox;
  ///     final bounds = renderBox.localToGlobal(Offset.zero) &
  ///                   renderBox.size;
  ///     layoutService.registerHookBounds('sidebar', bounds);
  ///   });
  ///
  ///   return Container(...);
  /// }
  /// ```
  void registerHookBounds(String hookId, Rect bounds) {
    _hookBoundsIndex[hookId] = bounds;
    debugPrint('Registered bounds for Hook $hookId: $bounds');
  }

  /// 注销Hook的屏幕边界
  ///
  /// [hookId] - Hook ID
  ///
  /// **架构说明：**
  /// - Hook卸载时调用此方法清理边界
  /// - 避免内存泄漏和错误的边界数据
  void unregisterHookBounds(String hookId) {
    _hookBoundsIndex.remove(hookId);
    debugPrint('Unregistered bounds for Hook $hookId');
  }

  /// 获取节点的附着信息。
  ///
  /// [nodeId] 是节点的ID。
  ///
  /// 返回附着信息，如果节点未附着则返回null。
  NodeAttachment? getNodeAttachment(String nodeId) {
    final hookId = _nodeToHookIndex[nodeId];
    if (hookId == null) return null;

    final hook = _hookIndex[hookId];
    if (hook == null) return null;

    return hook.getAttachedNode(nodeId);
  }

  /// 重新计算Hook的布局。
  ///
  /// [hookId] 是要重新计算的Hook的ID。
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

  /// 持久化当前布局状态。
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

  /// 从持久化恢复布局状态。
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

  /// 清除所有持久化的布局状态。
  Future<void> clearPersistedLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLayoutPersistenceKey);
      debugPrint('Cleared persisted layout state');
    } catch (e) {
      debugPrint('Failed to clear layout state: $e');
    }
  }

  /// 获取树的根Hook。
  UIHookNode get rootHook => _rootHook;

  /// 获取树中的所有Hook。
  List<UIHookNode> getAllHooks() => _hookIndex.values.toList();

  /// 获取所有节点到Hook的附着关系。
  Map<String, String> getAllNodeAttachments() => Map.unmodifiable(_nodeToHookIndex);

  // ===== 节点模板方法 =====

  /// 获取节点模板注册表。
  ///
  /// 插件使用此注册表注册它们的节点模板。
  NodeTemplateRegistry get nodeTemplateRegistry => _nodeTemplateRegistry;

  /// 注册节点模板。
  ///
  /// [template] 是要注册的模板。
  ///
  /// 这是一个便捷方法，委托给NodeTemplateRegistry。
  /// 插件通常在初始化期间调用此方法。
  void registerNodeTemplate(NodeTemplate template) {
    _nodeTemplateRegistry.register(template);
    debugPrint('已注册节点模板: ${template.id}');
  }

  /// 从模板创建节点并将其附着到Hook。
  ///
  /// [templateId] 是要使用的模板ID。
  /// [nodeId] 是新节点的唯一ID。
  /// [title] 是节点的标题。
  /// [content] 是可选的节点内容。
  /// [params] 是工厂的可选附加参数。
  /// [hookId] 是目标Hook ID（如果未提供则使用模板默认值）。
  /// [position] 是节点的位置（如果未提供则使用模板默认值）。
  /// [zIndex] 是渲染顺序。
  /// [persist] 是否持久化此附着。
  ///
  /// 如果未找到模板则抛出 [ArgumentError]。
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
      '已从模板 $templateId 创建并附着节点 $nodeId 到 Hook $targetHookId',
    );

    return node;
  }

  /// 通过ID获取节点模板。
  ///
  /// [templateId] 是模板ID。
  ///
  /// 返回模板，如果未找到则返回null。
  NodeTemplate? getNodeTemplate(String templateId) => _nodeTemplateRegistry.get(templateId);

  /// 获取所有节点模板。
  ///
  /// 返回所有已注册模板的不可修改列表。
  List<NodeTemplate> getAllNodeTemplates() => _nodeTemplateRegistry.getAll();

  /// 按类别获取节点模板。
  ///
  /// [category] 是要筛选的类别。
  ///
  /// 返回该类别中的模板列表。
  List<NodeTemplate> getNodeTemplatesByCategory(String category) => _nodeTemplateRegistry.getByCategory(category);

  /// 获取所有节点模板类别。
  List<String> getNodeTemplateCategories() => _nodeTemplateRegistry.getCategories();

  /// 调试方法，打印Hook树结构。
  void debugPrintTree() {
    debugPrint('=== Hook树结构 ===');
    _rootHook.debugPrintTree();
    debugPrint('=========================');
  }
}
