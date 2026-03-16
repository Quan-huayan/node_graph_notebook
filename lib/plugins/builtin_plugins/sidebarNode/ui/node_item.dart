import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/theme_service.dart';
import '../../editor/ui/markdown_editor_page.dart';
import '../../graph/bloc/graph_bloc.dart';
import '../../graph/bloc/graph_event.dart';
import '../../graph/bloc/node_bloc.dart';
import '../../graph/service/node_menu.dart';

/// 节点项组件
///
/// 用于在侧边栏中显示单个节点的组件，支持拖拽、选择、编辑等操作
class NodeItem extends StatelessWidget {
  /// 创建节点项组件
  ///
  /// [key]: 组件键
  /// [node]: 节点数据
  /// [parentFolder]: 父文件夹节点
  /// [onNodeSelected]: 节点选中回调
  /// [draggedNodeId]: 当前拖动的节点ID
  /// [onDragStarted]: 拖动开始回调
  /// [onDragEnd]: 拖动结束回调
  /// [onRemoveFromFolder]: 从文件夹中移除回调
  const NodeItem({
    super.key,
    required this.node,
    this.parentFolder,
    this.onNodeSelected,
    this.draggedNodeId,
    this.onDragStarted,
    this.onDragEnd,
    this.onRemoveFromFolder,
  });

  /// 节点数据
  final Node node;
  
  /// 父文件夹节点
  final Node? parentFolder;
  
  /// 节点选中回调
  final Function(String? nodeId)? onNodeSelected;
  
  /// 当前拖动的节点ID
  final String? draggedNodeId;
  
  /// 拖动开始回调
  final Function(String)? onDragStarted;
  
  /// 拖动结束回调
  final Function(DraggableDetails)? onDragEnd;
  
  /// 从文件夹中移除回调
  final Function()? onRemoveFromFolder;

  /// 构建组件
  ///
  /// [context]: 构建上下文
  ///
  /// 返回构建的节点项组件
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>().themeData;
    final nodeBloc = context.watch<NodeBloc>();
    final isSelected = nodeBloc.state.selectedNode?.id == node.id;
    final isDragging = draggedNodeId == node.id;

    return Draggable<String>(
      data: node.id,
      onDragStarted: () => onDragStarted?.call(node.id),
      onDragEnd: onDragEnd,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.note, size: 16, color: null),
              const SizedBox(width: 8),
              Text(node.title),
            ],
          ),
        ),
      ),
      child: Opacity(
        opacity: isDragging ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? theme.backgrounds.secondary : null,
            border: Border(
              left: BorderSide(
                color: isSelected
                    ? theme.nodes.nodePrimary
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: InkWell(
            onTap: () {
              onNodeSelected?.call(node.id);
              context.read<GraphBloc>().add(NodeSelectEvent(node.id));
            },
            onDoubleTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => MarkdownEditorPage(node: node),
                ),
              );
            },
            onLongPress: () => showNodeMenu(context, node),
            child: Row(
              children: [
                if (parentFolder == null) const SizedBox(width: 28),
                // === 架构说明：自定义图标显示 ===
                // 设计意图：如果节点有自定义图标（metadata['icon']），显示 emoji
                // 否则显示默认的 note 图标
                // 实现方式：检查 metadata['icon']，使用 Text widget 显示 emoji
                if (node.metadata.containsKey('icon') &&
                    node.metadata['icon'] != null &&
                    node.metadata['icon'].toString().isNotEmpty)
                  Text(
                    node.metadata['icon'].toString(),
                    style: const TextStyle(fontSize: 16),
                  )
                else
                  const Icon(Icons.note, size: 16, color: null),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(node.title, style: const TextStyle(fontSize: 12)),
                ),
                if (parentFolder != null && onRemoveFromFolder != null)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 16),
                    tooltip: 'Remove from folder',
                    onPressed: onRemoveFromFolder,
                  ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 16),
                  onPressed: () => showNodeMenu(context, node),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Node 扩展 - 检查是否为文件夹
extension NodeExtension on Node {
  /// 检查节点是否为文件夹
  ///
  /// 返回节点是否为文件夹的布尔值
  bool get isFolder => metadata['isFolder'] == true ||
        (metadata['isFolder'] is bool && metadata['isFolder'] as bool);
}
