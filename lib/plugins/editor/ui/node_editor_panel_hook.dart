import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../../core/plugin/ui_hooks/sidebar_tab_hook_base.dart';
import '../../../../core/ui_layout/ui_layout_service.dart';
import '../../../../core/utils/logger.dart';
import '../../graph/bloc/node_bloc.dart';
import '../../graph/bloc/node_event.dart';

const _log = AppLogger('NodeEditorPanelHook');

/// 节点编辑器数据接口（类型安全）
abstract class NodeEditorData {
  /// 节点唯一标识符
  String get id;

  /// 节点标题
  String get title;

  /// 节点内容（可选）
  String? get content;
}

/// Node编辑面板Hook
///
/// **职责：**
/// - 在Sidebar中显示节点编辑面板
/// - 支持Markdown编辑和预览
/// - 可以拖拽回Graph view
/// - 注册Hook边界以支持拖放检测
///
/// **架构说明：**
/// - 实现SidebarTabHookBase接口
/// - 通过HookContext获取编辑的节点ID
/// - 集成Markdown编辑组件
/// - 使用PostFrameCallback注册屏幕边界
class NodeEditorPanelHook extends SidebarTabHookBase {
  /// 创建Node编辑面板Hook
  NodeEditorPanelHook();

  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'editor.nodeEditorPanel',
    name: 'Node Editor Panel',
    version: '1.0.0',
    description: 'Displays node editor in sidebar panel',
  );

  @override
  String get tabId => 'editor';

  @override
  String get tabLabel => 'Editor';

  @override
  IconData get tabIcon => Icons.edit;

  @override
  bool isTabVisible(HookContext context) {
    // 只有在编辑节点时才显示此Hook
    final editingNodeId = context.get<String>('editingNodeId');
    return editingNodeId != null && editingNodeId.isNotEmpty;
  }

  @override
  Widget buildContent(HookContext context) {
    // 获取BuildContext
    final buildContext = context.get<BuildContext>('buildContext');
    if (buildContext == null) {
      _log.warning('BuildContext not found in HookContext');
      return const SizedBox.shrink();
    }

    return _NodeEditorPanelContent(
      hookContext: context,
    );
  }
}

/// Node编辑面板内容组件
///
/// **职责：**
/// - 渲染编辑面板
/// - 注册Hook边界
/// - 处理编辑操作
class _NodeEditorPanelContent extends StatefulWidget {
  /// 创建Node编辑面板内容
  const _NodeEditorPanelContent({
    required this.hookContext,
  });

  /// Hook上下文
  final HookContext hookContext;

  @override
  State<_NodeEditorPanelContent> createState() => _NodeEditorPanelContentState();
}

class _NodeEditorPanelContentState extends State<_NodeEditorPanelContent> {
  /// 全局Key用于获取RenderBox
  final GlobalKey _key = GlobalKey();

  /// UILayoutService实例
  UILayoutService? _layoutService;

  /// 是否已注册边界
  bool _isBoundsRegistered = false;

  /// 编辑控制器
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  /// 当前编辑的节点（类型安全）
  NodeEditorData? _currentNode;

  @override
  void initState() {
    super.initState();
    // 初始化编辑控制器
    _initializeControllers();

    // 在下一帧注册边界
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _registerHookBounds();
    });
  }

  @override
  void didUpdateWidget(_NodeEditorPanelContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果编辑的节点变化，更新控制器
    final editingNodeId = widget.hookContext.get<String>('editingNodeId');
    final oldEditingNodeId = oldWidget.hookContext.get<String>('editingNodeId');

    if (editingNodeId != oldEditingNodeId) {
      _initializeControllers();
    }
  }

  @override
  void dispose() {
    _unregisterHookBounds();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// 初始化编辑控制器
  void _initializeControllers() {
    final editingNodeId = widget.hookContext.get<String>('editingNodeId');

    if (editingNodeId != null && editingNodeId.isNotEmpty) {
      // 从HookContext获取BuildContext和节点
      final buildContext = widget.hookContext.get<BuildContext>('buildContext');
      if (buildContext == null) {
        _log.warning('BuildContext not found in HookContext');
        _currentNode = null;
        _titleController = TextEditingController();
        _contentController = TextEditingController();
        return;
      }

      final nodeBloc = buildContext.read<NodeBloc>();
      final nodeState = nodeBloc.state;

      // 类型安全：使用whereType过滤节点，然后手动查找
      final nodeDataList = nodeState.nodes.whereType<NodeEditorData>();
      NodeEditorData? node;

      for (final n in nodeDataList) {
        if (n.id == editingNodeId) {
          node = n;
          break;
        }
      }

      _currentNode = node;

      if (node != null) {
        _titleController = TextEditingController(text: node.title);
        _contentController = TextEditingController(text: node.content ?? '');
      } else {
        _titleController = TextEditingController();
        _contentController = TextEditingController();
      }
    } else {
      _currentNode = null;
      _titleController = TextEditingController();
      _contentController = TextEditingController();
    }
  }

  /// 注册Hook屏幕边界
  ///
  /// **架构说明：**
  /// - 通过GlobalKey获取RenderBox
  /// - 计算屏幕边界（localToGlobal）
  /// - 注册到UILayoutService用于拖拽检测
  void _registerHookBounds() {
    if (!mounted) return;

    try {
      final context = _key.currentContext;
      if (context == null) {
        _log.warning('Cannot register bounds: context is null');
        return;
      }

      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) {
        _log.warning('Cannot register bounds: renderBox is null');
        return;
      }

      // 获取BuildContext和UILayoutService
      final buildContext = widget.hookContext.get<BuildContext>('buildContext');
      if (buildContext == null) {
        _log.warning('BuildContext not found in HookContext');
        return;
      }

      _layoutService = buildContext.read<UILayoutService>();

      // 计算屏幕边界
      final localBounds = Offset.zero & renderBox.size;
      final screenBounds = renderBox.localToGlobal(Offset.zero) & localBounds.size;

      // 注册边界
      _layoutService?.registerHookBounds('sidebar.nodeEditor', screenBounds);
      _isBoundsRegistered = true;

      _log.debug('Registered bounds for sidebar.nodeEditor: $screenBounds');
    } catch (e) {
      _log.error('Failed to register hook bounds: $e');
    }
  }

  /// 注销Hook屏幕边界
  void _unregisterHookBounds() {
    if (_isBoundsRegistered && _layoutService != null) {
      _layoutService?.unregisterHookBounds('sidebar.nodeEditor');
      _isBoundsRegistered = false;
      _log.debug('Unregistered bounds for sidebar.nodeEditor');
    }
  }

  /// 保存节点编辑
  void _saveNode() {
    if (_currentNode == null) return;

    // 类型安全：直接访问接口属性
    final nodeId = _currentNode!.id;
    if (nodeId.isEmpty) return;

    final buildContext = widget.hookContext.get<BuildContext>('buildContext');
    if (buildContext == null) {
      _log.warning('BuildContext not found in HookContext');
      return;
    }

    final nodeBloc = buildContext.read<NodeBloc>();

    // 发送更新节点事件
    // 使用NodeUpdateEvent更新节点数据
    nodeBloc.add(
      NodeUpdateEvent(
        nodeId,
        title: _titleController.text,
        content: _contentController.text,
      ),
    );

    _log.info('Saved node: $nodeId');

    // 显示保存成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Node saved'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentNode == null) {
      return _buildEmptyState(context);
    }

    return Container(
      key: _key,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 工具栏（包含拖拽手柄）
          _buildToolbar(context),

          const SizedBox(height: 16),

          // 标题编辑
          TextField(
            controller: _titleController,
            style: Theme.of(context).textTheme.titleLarge,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          // 内容编辑
          Expanded(
            child: TextField(
              controller: _contentController,
              maxLines: null,
              expands: true,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: const InputDecoration(
                labelText: 'Content (Markdown)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 保存按钮
          ElevatedButton.icon(
            onPressed: _saveNode,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// 构建工具栏
  Widget _buildToolbar(BuildContext context) => Row(
      children: [
        // 拖拽手柄
        MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: GestureDetector(
            onPanStart: (_) => _handleDragStart(),
            child: const Icon(Icons.drag_handle),
          ),
        ),
        const SizedBox(width: 8),
        // 标题
        Expanded(
          child: Text(
            'Editing: ${_currentNode?.title ?? ''}',
            style: Theme.of(context).textTheme.titleSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 关闭按钮
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: _handleClose,
          tooltip: 'Close editor',
        ),
      ],
    );

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) => Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.edit_note, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No node selected for editing',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Double-click a node in the sidebar to edit it',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );

  /// 处理拖拽开始
  ///
  /// **架构说明：**
  /// - 从编辑面板拖拽节点时触发
  /// - 将节点拖回Graph view
  void _handleDragStart() {
    if (_currentNode == null) return;

    // 类型安全：直接访问接口属性
    final nodeId = _currentNode!.id;
    if (nodeId.isEmpty) return;

    _log.debug('Dragging node from editor: $nodeId');

    // 获取UILayoutService
    if (_layoutService == null) {
      _log.warning('UILayoutService not available');
      return;
    }

    // 获取节点当前所在的Hook
    final currentHookId = _layoutService!.getNodeHook(nodeId);
    _log.debug('Node $nodeId is currently in hook: $currentHookId');

    // 触发拖拽事件
    // 这里可以发送一个事件到NodeBloc，通知节点开始拖拽
    // 或者直接调用UILayoutService的方法
    // 由于这是从编辑器拖拽，我们可能需要：
    // 1. 更新节点的渲染状态为'dragging'
    // 2. 准备将节点移动到graph hook

    try {
      // 更新节点渲染状态
      _layoutService!.updateNodeRenderState(
        nodeId: nodeId,
        renderState: 'dragging',
      );

      _log.info('Started dragging node $nodeId from editor');
    } catch (e) {
      _log.error('Failed to start drag: $e');
    }
  }

  /// 处理关闭编辑器
  void _handleClose() {
    // 清除编辑的节点ID
    // 这需要更新HookContext的metadata
    _log.debug('Closing editor for node: ${_currentNode?.id}');

    // 获取BuildContext
    final buildContext = widget.hookContext.get<BuildContext>('buildContext');
    if (buildContext == null) {
      _log.warning('BuildContext not found in HookContext');
      return;
    }

    try {
      // 方案1: 通过HookContext更新状态
      // 清除editingNodeId，这会让isTabVisible返回false
      widget.hookContext.set('editingNodeId', null);

      // 方案2: 发送事件到NodeBloc
      // 通知节点编辑完成
      final nodeBloc = buildContext.read<NodeBloc>();
      if (_currentNode != null) {
        // 发送节点更新事件（如果有修改）
        nodeBloc.add(NodeUpdateEvent(
          _currentNode!.id,
          title: _titleController.text,
          content: _contentController.text,
        ));
      }

      // 方案3: 如果需要，将节点移回graph
      if (_layoutService != null && _currentNode != null) {
        final currentHook = _layoutService!.getNodeHook(_currentNode!.id);
        if (currentHook != null && currentHook != 'graph') {
          // 节点不在graph中，可以选择移回
          // 这取决于业务逻辑
          _log.debug('Node ${_currentNode!.id} is in hook: $currentHook');
        }
      }

      _log.info('Closed editor for node: ${_currentNode?.id}');

      // 触发重建以隐藏编辑器
      setState(() {});
    } catch (e) {
      _log.error('Failed to close editor: $e');
    }
  }
}

// Hook通过EditorPlugin的registerHooks()方法注册
// 不需要手动注册到HookRegistry
