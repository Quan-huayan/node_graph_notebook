import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/theme_service.dart';
import '../../graph/bloc/node_bloc.dart';
import '../../graph/bloc/node_event.dart';
import '../../graph/ui/node_menu.dart';
import 'node_item.dart';

/// 文件夹项组件
///
/// 展示单个文件夹的UI组件，支持展开/折叠、拖拽操作和子节点管理
class FolderItem extends StatefulWidget {
  /// 创建文件夹项组件
  ///
  /// [folder] 当前文件夹节点
  /// [allNodes] 所有节点列表
  /// [level] 文件夹层级
  /// [expandedFolders] 已展开的文件夹集合
  /// [onExpandedFoldersChanged] 展开状态变更回调
  /// [draggedNodeId] 当前拖拽的节点ID
  /// [onDragStarted] 拖拽开始回调
  /// [onDragEnd] 拖拽结束回调
  /// [onNodeSelected] 节点选择回调
  const FolderItem({
    super.key,
    required this.folder,
    required this.allNodes,
    required this.level,
    required this.expandedFolders,
    required this.onExpandedFoldersChanged,
    required this.draggedNodeId,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onNodeSelected,
  });

  /// 当前文件夹节点
  final Node folder;
  /// 所有节点列表
  final List<Node> allNodes;
  /// 文件夹层级
  final int level;
  /// 已展开的文件夹集合
  final Set<String> expandedFolders;
  /// 展开状态变更回调
  final Function(Set<String>) onExpandedFoldersChanged;
  /// 当前拖拽的节点ID
  final String? draggedNodeId;
  /// 拖拽开始回调
  final Function(String) onDragStarted;
  /// 拖拽结束回调
  final Function(DraggableDetails) onDragEnd;
  /// 节点选择回调
  final Function(String?)? onNodeSelected;

  @override
  State<FolderItem> createState() => _FolderItemState();
}

class _FolderItemState extends State<FolderItem> {
  /// 获取文件夹中的直接子节点
  ///
  /// 基于引用结构：文件夹引用的所有节点都是其子节点
  /// 不再使用 ref.type 进行过滤
  List<Node> _getFolderChildren(Node folder, List<Node> nodes) 
    => nodes.where((node) => folder.references.containsKey(node.id)).toList();

  /// 检测是否存在循环 contains 关系
  bool _hasCircularContains(Node node, Node folder, List<Node> allNodes) {
    // 检查是否将节点拖拽到自身
    if (node.id == folder.id) {
      return true;
    }

    // 检查是否将文件夹拖拽到其子文件夹中
    if (node.isFolder) {
      // 检查目标文件夹是否是当前节点的子文件夹
      return _isChildFolder(folder, node, allNodes);
    }

    return false;
  }

  /// 检查 folder 是否是 parentFolder 的子文件夹
  bool _isChildFolder(Node folder, Node parentFolder, List<Node> allNodes) {
    // 检查 folder 是否直接被 parentFolder 引用
    if (parentFolder.references.containsKey(folder.id)) {
      return true;
    }

    // 递归检查 parentFolder 的所有直接子文件夹
    for (final entry in parentFolder.references.entries) {
      final childNode = allNodes.firstWhere(
        (n) => n.id == entry.key,
        orElse: () => parentFolder,
      );
      if (childNode.id.isNotEmpty &&
          childNode.isFolder &&
          _isChildFolder(folder, childNode, allNodes)) {
        return true;
      }
    }

    return false;
  }

  /// 将节点添加到文件夹
  Future<void> _addToFolder(Node node, Node folder) async {
    final nodeBloc = context.read<NodeBloc>();
    final allNodes = nodeBloc.state.nodes;

    // 检测循环 contains 关系
    if (_hasCircularContains(node, folder, allNodes)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot create circular folder structure'),
          ),
        );
      }
      return;
    }

    // 从旧文件夹中移除节点
    final oldParent = _getParentFolder(node);
    if (oldParent != null) {
      await _removeFromFolder(node, oldParent);
    }

    // 创建新的引用（使用通用关系类型）
    final newReferences = Map<String, NodeReference>.from(folder.references);
    newReferences[node.id] = NodeReference(
      nodeId: node.id,
      properties: {'type': 'relatesTo'},
    );

    final updatedFolder = folder.copyWith(references: newReferences);
    nodeBloc.add(NodeReplaceEvent(updatedFolder));

    if (mounted) {
      widget.onExpandedFoldersChanged({...widget.expandedFolders, folder.id});
    }
  }

  /// 从文件夹中移除节点
  Future<void> _removeFromFolder(Node node, Node folder) async {
    final nodeBloc = context.read<NodeBloc>();

    final newReferences = Map<String, NodeReference>.from(folder.references)
    ..remove(node.id);

    final updatedFolder = folder.copyWith(references: newReferences);
    nodeBloc.add(NodeReplaceEvent(updatedFolder));
  }

  Node? _getParentFolder(Node node) {
    final nodeBloc = context.read<NodeBloc>();
    final folders = nodeBloc.state.nodes.where((n) => n.isFolder).toList();
    for (final folder in folders) {
      // 找到第一个引用该节点的文件夹
      if (folder.references.containsKey(node.id)) {
        return folder;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final children = _getFolderChildren(widget.folder, widget.allNodes);
    final isExpanded = widget.expandedFolders.contains(widget.folder.id);
    final theme = context.watch<ThemeService>().themeData;
    final nodeBloc = context.watch<NodeBloc>();
    final isSelected = nodeBloc.state.selectedNode?.id == widget.folder.id;
    final isDragging = widget.draggedNodeId == widget.folder.id;

    return DragTarget<String>(
      onAcceptWithDetails: (details) async {
        final draggedNodeId = details.data;
        if (draggedNodeId != widget.folder.id) {
          // 从所有节点中查找被拖拽的节点
          final draggedNode = widget.allNodes.firstWhere(
            (n) => n.id == draggedNodeId,
          );
          if (draggedNode.id.isNotEmpty) {
            await _addToFolder(draggedNode, widget.folder);
          }
        }
      },
      builder: (context, candidateData, rejected) {
        // candidateData 是 Iterable<Object?>，需要提取数据
        final isDraggingOver = candidateData.isNotEmpty;

        // 提取第一个拖拽的节点ID
        String? draggedNodeId;
        if (candidateData.isNotEmpty) {
          final first = candidateData.first;
          // 如果 first 本身就是 String，直接使用
          if (first is String) {
            draggedNodeId = first;
          }
        }

        final isValidTarget =
            isDraggingOver &&
            draggedNodeId != null &&
            draggedNodeId != widget.folder.id;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: isValidTarget ? Colors.blue.withValues(alpha: 0.2) : null,
            border: Border(
              left: BorderSide(
                color: isSelected
                    ? theme.nodes.folderPrimary
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            children: [
              Draggable<String>(
                data: widget.folder.id,
                onDragStarted: () {
                  widget.onDragStarted(widget.folder.id);
                },
                onDragEnd: (details) {
                  widget.onDragEnd(details);
                },
                feedback: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder,
                          size: 16,
                          color: theme.nodes.folderPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(widget.folder.title),
                      ],
                    ),
                  ),
                ),
                child: Opacity(
                  opacity: isDragging ? 0.5 : 1.0,
                  child: InkWell(
                    onTap: () {
                      if (widget.expandedFolders.contains(widget.folder.id)) {
                        final updated = Set<String>.from(
                          widget.expandedFolders,
                        )
                        ..remove(widget.folder.id);
                        widget.onExpandedFoldersChanged(updated);
                      } else {
                        final updated = Set<String>.from(
                          widget.expandedFolders,
                        )
                        ..add(widget.folder.id);
                        widget.onExpandedFoldersChanged(updated);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.folder,
                            size: 16,
                            color: theme.nodes.folderPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.folder.title,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.nodes.folderPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '(${children.length})',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert, size: 16),
                            onPressed: () =>
                                showNodeMenu(context, widget.folder),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (isExpanded && children.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(left: 32.0 + (widget.level * 16)),
                  child: Column(
                    children: children.map((child) {
                      // 如果子节点是文件夹，递归渲染
                      if (child.isFolder) {
                        return FolderItem(
                          folder: child,
                          allNodes: widget.allNodes,
                          level: widget.level + 1,
                          expandedFolders: widget.expandedFolders,
                          onExpandedFoldersChanged:
                              widget.onExpandedFoldersChanged,
                          draggedNodeId: widget.draggedNodeId,
                          onDragStarted: widget.onDragStarted,
                          onDragEnd: widget.onDragEnd,
                          onNodeSelected: widget.onNodeSelected,
                        );
                      } else {
                        return NodeItem(
                          node: child,
                          parentFolder: widget.folder,
                          onNodeSelected: widget.onNodeSelected,
                          draggedNodeId: widget.draggedNodeId,
                          onDragStarted: widget.onDragStarted,
                          onDragEnd: widget.onDragEnd,
                          onRemoveFromFolder: () async {
                            await _removeFromFolder(child, widget.folder);
                          },
                        );
                      }
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
