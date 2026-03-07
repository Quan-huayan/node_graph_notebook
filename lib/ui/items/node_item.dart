import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/models.dart';
import '../../core/services/theme_service.dart';
import '../../bloc/blocs.dart';
import '../pages/markdown_editor_page.dart';
import '../menus/node_menu.dart';

/// 节点项组件
class NodeItem extends StatelessWidget {
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

  final Node node;
  final Node? parentFolder;
  final Function(String? nodeId)? onNodeSelected;
  final String? draggedNodeId;
  final Function(String)? onDragStarted;
  final Function(DraggableDetails)? onDragEnd;
  final Function()? onRemoveFromFolder;

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
        elevation: 8.0,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.note,
                size: 16,
                color: null,
              ),
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
                color: isSelected ? theme.nodes.nodePrimary : Colors.transparent,
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
                const Icon(
                  Icons.note,
                  size: 16,
                  color: null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.title,
                    style: const TextStyle(fontSize: 12),
                  ),
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
  bool get isFolder {
    return metadata['isFolder'] == true ||
        (metadata['isFolder'] is bool && metadata['isFolder'] as bool);
  }
}
