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
/// - 支持节点点击
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
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取节点数据
    final nodes = widget.hookContext.get<List<Object>>('nodes') ?? [];

    if (nodes.isEmpty) {
      return _buildEmptyState(context);
    }

    // 转换为类型安全的NodeData
    final nodeDataList = nodes.whereType<NodeData>().toList();

    return Container(
      key: _key,
      child: ListView.builder(
        itemCount: nodeDataList.length,
        itemBuilder: (context, index) {
          final nodeData = nodeDataList[index];
          final isSelected = _selectedNodeId == nodeData.id;

          return _NodeListItem(
            nodeData: nodeData,
            isSelected: isSelected,
            onTap: () => _handleNodeTap(nodeData),
          );
        },
      ),
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
  }
}

/// 节点列表项组件（类型安全）
class _NodeListItem extends StatelessWidget {
  const _NodeListItem({
    required this.nodeData,
    required this.isSelected,
    required this.onTap,
  });

  final NodeData nodeData;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = nodeData.title;
    final isFolder = nodeData.isFolder;

    return InkWell(
      onTap: onTap,
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
