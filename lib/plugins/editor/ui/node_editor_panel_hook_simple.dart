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

/// Node编辑面板Hook（简化版）
///
/// **职责：**
/// - 在Sidebar中显示节点编辑面板
/// - 支持文本编辑
class NodeEditorPanelHook extends SidebarTabHookBase {
  /// 创建Node编辑面板Hook（简化版）
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
    final editingNodeId = context.get<String>('editingNodeId');
    return editingNodeId != null && editingNodeId.isNotEmpty;
  }

  @override
  Widget buildContent(HookContext context) {
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
class _NodeEditorPanelContent extends StatefulWidget {
  const _NodeEditorPanelContent({
    required this.hookContext,
  });

  final HookContext hookContext;

  @override
  State<_NodeEditorPanelContent> createState() => _NodeEditorPanelContentState();
}

class _NodeEditorPanelContentState extends State<_NodeEditorPanelContent> {
  final GlobalKey _key = GlobalKey();
  UILayoutService? _layoutService;
  bool _isBoundsRegistered = false;

  late TextEditingController _titleController;
  late TextEditingController _contentController;

  /// 当前编辑的节点（类型安全）
  NodeEditorData? _currentNode;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _registerHookBounds();
    });
  }

  @override
  void didUpdateWidget(_NodeEditorPanelContent oldWidget) {
    super.didUpdateWidget(oldWidget);

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

  void _initializeControllers() {
    final editingNodeId = widget.hookContext.get<String>('editingNodeId');

    if (editingNodeId != null && editingNodeId.isNotEmpty) {
      final buildContext = widget.hookContext.get<BuildContext>('buildContext');
      if (buildContext == null) {
        _currentNode = null;
        _titleController = TextEditingController();
        _contentController = TextEditingController();
        return;
      }

      final nodeBloc = buildContext.read<NodeBloc>();
      final nodeState = nodeBloc.state;

      // 类型安全：使用whereType过滤节点，然后使用firstWhereOrNull
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

  void _registerHookBounds() {
    if (!mounted) return;

    try {
      final context = _key.currentContext;
      if (context == null) return;

      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final buildContext = widget.hookContext.get<BuildContext>('buildContext');
      if (buildContext == null) return;

      _layoutService = buildContext.read<UILayoutService>();

      final localBounds = Offset.zero & renderBox.size;
      final screenBounds = renderBox.localToGlobal(Offset.zero) & localBounds.size;

      _layoutService?.registerHookBounds('sidebar.nodeEditor', screenBounds);
      _isBoundsRegistered = true;

      _log.debug('Registered bounds for sidebar.nodeEditor: $screenBounds');
    } catch (e) {
      _log.error('Failed to register hook bounds: $e');
    }
  }

  void _unregisterHookBounds() {
    if (_isBoundsRegistered && _layoutService != null) {
      _layoutService?.unregisterHookBounds('sidebar.nodeEditor');
      _isBoundsRegistered = false;
    }
  }

  void _saveNode() {
    if (_currentNode == null) return;

    // 类型安全：直接访问接口属性
    final nodeId = _currentNode!.id;
    if (nodeId.isEmpty) return;

    final buildContext = widget.hookContext.get<BuildContext>('buildContext');
    if (buildContext == null) return;

    // 发送更新节点事件到NodeBloc
    final nodeBloc = buildContext.read<NodeBloc>();
    nodeBloc.add(
      NodeUpdateEvent(
        nodeId,
        title: _titleController.text,
        content: _contentController.text,
      ),
    );

    _log.info('Saved node: $nodeId');

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
          TextField(
            controller: _titleController,
            style: Theme.of(context).textTheme.titleLarge,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
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
          ElevatedButton.icon(
            onPressed: _saveNode,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

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
}
