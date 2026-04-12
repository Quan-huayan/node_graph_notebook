import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../../core/plugin/ui_hooks/sidebar_tab_hook_base.dart';
import '../../../../core/services/i18n.dart';
import '../../../../core/ui_layout/ui_layout_service.dart';
import '../../../../core/utils/logger.dart';

const _log = AppLogger('SidebarHookRenderer');

/// Sidebar节点列表Hook（类型安全版本）
///
/// **职责：**
/// - 在Sidebar中显示节点列表
/// - 支持节点点击、双击、右键菜单
/// - 支持从Sidebar拖出节点到Graph
/// - 注册Hook边界以支持拖放检测
class SidebarNodeListHook extends SidebarTabHookBase {
  /// 创建Sidebar节点列表Hook
  SidebarNodeListHook();

  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'sidebarNode.nodeList',
    name: 'Sidebar Node List',
    version: '1.0.0',
    description: 'Displays nodes in sidebar as a list',
  );

  @override
  String get tabId => 'nodes';

  @override
  String get tabLabel => 'Nodes';

  @override
  IconData get tabIcon => Icons.list;

  @override
  bool isTabVisible(HookContext context) => true;

  @override
  Widget buildContent(HookContext context) {
    // 获取BuildContext
    final buildContext = context.get<BuildContext>('buildContext');
    if (buildContext == null) {
      _log.warning('BuildContext not found in HookContext');
      return const SizedBox.shrink();
    }

    return _SidebarNodeListContent(
      hookContext: context,
    );
  }
}

/// 节点数据接口（类型安全）
abstract class NodeData {
  /// 节点唯一标识符
  String get id;

  /// 节点标题
  String get title;

  /// 是否为文件夹
  bool get isFolder;
}

/// Sidebar节点列表内容组件
class _SidebarNodeListContent extends StatefulWidget {
  const _SidebarNodeListContent({
    required this.hookContext,
  });

  final HookContext hookContext;

  @override
  State<_SidebarNodeListContent> createState() => _SidebarNodeListContentState();
}

class _SidebarNodeListContentState extends State<_SidebarNodeListContent> {
  final GlobalKey _key = GlobalKey();
  UILayoutService? _layoutService;
  bool _isBoundsRegistered = false;

  /// 当前选中的节点ID
  String? _selectedNodeId;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _registerHookBounds();
    });
  }

  @override
  void dispose() {
    _unregisterHookBounds();
    super.dispose();
  }

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

      final buildContext = widget.hookContext.get<BuildContext>('buildContext');
      if (buildContext == null) {
        _log.warning('BuildContext not found in HookContext');
        return;
      }

      _layoutService = buildContext.read<UILayoutService>();

      final localBounds = Offset.zero & renderBox.size;
      final screenBounds = renderBox.localToGlobal(Offset.zero) & localBounds.size;

      _layoutService?.registerHookBounds('sidebar.bottom', screenBounds);
      _isBoundsRegistered = true;

      _log.debug('Registered bounds for sidebar.bottom: $screenBounds');
    } catch (e) {
      _log.error('Failed to register hook bounds: $e');
    }
  }

  void _unregisterHookBounds() {
    if (_isBoundsRegistered && _layoutService != null) {
      _layoutService?.unregisterHookBounds('sidebar.bottom');
      _isBoundsRegistered = false;
      _log.debug('Unregistered bounds for sidebar.bottom');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取节点数据
    final nodes = widget.hookContext.get<List<Object>>('nodes') ?? [];

    // 类型安全：过滤并转换节点数据
    final nodeDataList = nodes.whereType<NodeData>().toList();

    if (nodeDataList.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      key: _key,
      itemCount: nodeDataList.length,
      itemBuilder: (context, index) {
        final nodeData = nodeDataList[index];
        final isSelected = _selectedNodeId == nodeData.id;

        return _NodeListItem(
          nodeData: nodeData,
          isSelected: isSelected,
          onTap: () => _handleNodeTap(nodeData),
          onDoubleTap: () => _handleNodeDoubleTap(nodeData),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final i18n = I18n.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            i18n.t('No nodes yet'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            i18n.t('Create your first node to get started'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _handleNodeTap(NodeData nodeData) {
    _log.debug('Node tapped: ${nodeData.id}');

    // 更新选中状态
    setState(() {
      _selectedNodeId = nodeData.id;
    });

    // 高亮选中的节点
    // 可以通过UILayoutService更新节点的渲染状态
    if (_layoutService != null) {
      try {
        // 清除之前选中节点的高亮
        if (_selectedNodeId != null && _selectedNodeId != nodeData.id) {
          _layoutService!.updateNodeRenderState(
            nodeId: _selectedNodeId!,
            renderState: 'rendering',
          );
        }

        // 高亮当前选中的节点
        _layoutService!.updateNodeRenderState(
          nodeId: nodeData.id,
          renderState: 'hovering',
        );

        _log.info('Selected node: ${nodeData.id}');
      } catch (e) {
        _log.error('Failed to update node render state: $e');
      }
    }

    // 可选：发送选择事件到GraphBloc
    // 这可以让Graph view也高亮显示选中的节点
    // final buildContext = widget.hookContext.get<BuildContext>('buildContext');
    // if (buildContext != null) {
    //   final graphBloc = buildContext.read<GraphBloc>();
    //   graphBloc.add(SelectNodeEvent(nodeId: nodeData.id));
    // }
  }

  void _handleNodeDoubleTap(NodeData nodeData) {
    _log.debug('Node double-tapped: ${nodeData.id}');

    // 双击打开编辑器
    // 通过设置editingNodeId来触发编辑器面板显示
    widget.hookContext.set('editingNodeId', nodeData.id);

    _log.info('Opening editor for node: ${nodeData.id}');

    // 可选：导航到编辑页面或展开编辑面板
    // 这取决于应用的导航结构

    // 方案1: 如果编辑器在Sidebar中，触发重建
    // setState(() {});

    // 方案2: 如果编辑器是独立的页面，导航到编辑页面
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (context) => NodeEditorPage(nodeId: nodeData.id),
    //   ),
    // );

    // 方案3: 发送事件到NodeBloc
    // final buildContext = widget.hookContext.get<BuildContext>('buildContext');
    // if (buildContext != null) {
    //   final nodeBloc = buildContext.read<NodeBloc>();
    //   nodeBloc.add(EditNodeEvent(nodeId: nodeData.id));
    // }
  }
}

/// 节点列表项组件（类型安全）
class _NodeListItem extends StatelessWidget {
  const _NodeListItem({
    required this.nodeData,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final NodeData nodeData;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final title = nodeData.title;
    final isFolder = nodeData.isFolder;

    return InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
          border: isSelected
              ? Border(
                  left: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isFolder ? Icons.folder : Icons.description,
              size: 20,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
