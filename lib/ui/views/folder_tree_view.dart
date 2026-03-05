import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/services/theme_service.dart';
import '../models/models.dart';
import '../pages/markdown_editor_page.dart';
import '../dialogs/connection_dialog.dart';

/// 文件夹树形视图
class FolderTreeView extends StatefulWidget {
  const FolderTreeView({
    super.key,
    required this.nodes,
    required this.folders,
    this.onNodeSelected,
  });

  final List<Node> nodes;
  final List<Node> folders;
  final Function(String? nodeId)? onNodeSelected;

  @override
  State<FolderTreeView> createState() => _FolderTreeViewState();
}

class _FolderTreeViewState extends State<FolderTreeView> {
  final Set<String> _expandedFolders = {};
  String? _draggedNodeId;

  /// 获取文件夹中的直接子节点
  List<Node> _getFolderChildren(Node folder) {
    return widget.nodes.where((node) {
      final ref = folder.references[node.id];
      return ref != null && ref.type == ReferenceType.contains;
    }).toList();
  }

  /// 获取顶层文件夹（没有被其他文件夹包含的文件夹）
  List<Node> _getTopLevelFolders() {
    return widget.folders.where((folder) {
      // 检查是否被其他文件夹包含
      return !widget.folders.any((parent) {
        if (parent.id == folder.id) return false;
        final ref = parent.references[folder.id];
        return ref != null && ref.type == ReferenceType.contains;
      });
    }).toList();
  }

  /// 获取不在任何文件夹中的节点
  List<Node> _getRootNodes() {
    // 从文件夹中获取所有被包含的节点ID
    final folderContainedIds = widget.folders
        .expand((folder) => folder.references.keys)
        .toSet();

    return widget.nodes.where((node) {
      return !folderContainedIds.contains(node.id);
    }).toList();
  }

  /// 将节点添加到文件夹
  Future<void> _addToFolder(Node node, Node folder) async {
    final nodeModel = context.read<NodeModel>();

    // 创建新的引用
    final newReferences = Map<String, NodeReference>.from(folder.references);
    newReferences[node.id] = NodeReference(
      nodeId: node.id,
      type: ReferenceType.contains,
    );

    final updatedFolder = folder.copyWith(references: newReferences);
    await nodeModel.replaceNode(updatedFolder);

    if (mounted) {
      setState(() {
        _expandedFolders.add(folder.id);
      });
    }
  }

  /// 从文件夹中移除节点
  Future<void> _removeFromFolder(Node node, Node folder) async {
    final nodeModel = context.read<NodeModel>();

    final newReferences = Map<String, NodeReference>.from(folder.references);
    newReferences.remove(node.id);

    final updatedFolder = folder.copyWith(references: newReferences);
    await nodeModel.replaceNode(updatedFolder);
  }

  @override
  Widget build(BuildContext context) {
    final rootNodes = _getRootNodes();
    final topLevelFolders = _getTopLevelFolders();
    final allNodes = [...widget.nodes, ...widget.folders];

    if (rootNodes.isEmpty && topLevelFolders.isEmpty) {
      return const Center(child: Text('No nodes yet'));
    }

    return ListView(
      children: [
        // 顶层文件夹列表
        ...topLevelFolders.map((folder) => _buildFolderItem(context, folder, allNodes, 0)),

        // 分隔线
        if (topLevelFolders.isNotEmpty && rootNodes.isNotEmpty)
          const Divider(height: 32),

        // 根节点列表
        ...rootNodes.map((node) => _buildNodeItem(context, node)),
      ],
    );
  }

  Widget _buildFolderItem(BuildContext context, Node folder, List<Node> allNodes, int level) {
    final children = _getFolderChildren(folder);
    final isExpanded = _expandedFolders.contains(folder.id);
    final theme = context.watch<ThemeService>().themeData;
    final nodeModel = context.watch<NodeModel>();
    final isSelected = nodeModel.selectedNode?.id == folder.id;

    return DragTarget<String>(
      onAcceptWithDetails: (details) async {
        final draggedNodeId = details.data;
        if (draggedNodeId != folder.id) {
          // 从所有节点中查找被拖拽的节点
          final draggedNode = allNodes.firstWhere((n) => n.id == draggedNodeId);
          await _addToFolder(draggedNode, folder);
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

        final isValidTarget = isDraggingOver && draggedNodeId != null && draggedNodeId != folder.id;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: isValidTarget
                ? Colors.blue.withValues(alpha: 0.2)
                : null,
            border: Border(
              left: BorderSide(
                color: isSelected ? theme.nodes.folderPrimary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    if (_expandedFolders.contains(folder.id)) {
                      _expandedFolders.remove(folder.id);
                    } else {
                      _expandedFolders.add(folder.id);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.expand_more : Icons.chevron_right,
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
                          folder.title,
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
                        onPressed: () => _showNodeMenu(context, folder),
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded && children.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(left: 32.0 + (level * 16)),
                  child: Column(
                    children: children.map((child) {
                      // 如果子节点是文件夹，递归渲染
                      if (child.isFolder) {
                        return _buildFolderItem(context, child, allNodes, level + 1);
                      } else {
                        return _buildNodeItem(context, child, parentFolder: folder);
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

  Widget _buildNodeItem(BuildContext context, Node node, {Node? parentFolder}) {
    final theme = context.watch<ThemeService>().themeData;
    final nodeModel = context.watch<NodeModel>();
    final isSelected = nodeModel.selectedNode?.id == node.id;
    final isDragging = _draggedNodeId == node.id;

    return Draggable<String>(
      data: node.id,
      onDragStarted: () {
        setState(() {
          _draggedNodeId = node.id;
        });
      },
      onDragEnd: (details) {
        setState(() {
          _draggedNodeId = null;
        });
      },
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
              widget.onNodeSelected?.call(node.id);
              nodeModel.selectNode(node.id);
            },
            onDoubleTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => MarkdownEditorPage(node: node),
                ),
              );
            },
            onLongPress: () => _showNodeMenu(context, node),
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
                if (parentFolder != null)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 16),
                    tooltip: 'Remove from folder',
                    onPressed: () async {
                      await _removeFromFolder(node, parentFolder);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 16),
                  onPressed: () => _showNodeMenu(context, node),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNodeMenu(BuildContext context, Node node) {
    // 使用传入的文件夹列表
    final folders = widget.folders;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Consumer<NodeModel>(
          builder: (ctx, nodeModel, child) {
            // 合并所有节点来查找连接的节点
            final allNodes = [...widget.nodes, ...widget.folders];
            final connectedNodes = allNodes
                .where((n) => node.references.containsKey(n.id))
                .toList();

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => MarkdownEditorPage(node: node),
                      ),
                    );
                  },
                ),
                if (!node.isFolder && folders.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: const Text('Move to Folder...'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showFolderSelector(context, node, folders);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Connect to...'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (ctx) => ConnectionDialog(
                        sourceNode: node,
                        availableNodes: nodeModel.nodes,
                      ),
                    );
                  },
                ),
                if (connectedNodes.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.link_off),
                    title: const Text('Disconnect from...'),
                    trailing: Chip(
                      label: Text('${connectedNodes.length}'),
                      padding: EdgeInsets.zero,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      // TODO: Implement disconnect functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Disconnect feature coming soon')),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('References'),
                  trailing: Chip(
                    label: Text('${node.references.length}'),
                    padding: EdgeInsets.zero,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReferencesInfo(context, node);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) {
                        return AlertDialog(
                          title: const Text('Delete Node'),
                          content: Text('Are you sure you want to delete "${node.title}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmed == true) {
                      if (context.mounted) {
                        final graphModel = context.read<GraphModel>();
                        if (graphModel.hasGraph) {
                          await graphModel.removeNode(node.id);
                        }
                        await nodeModel.deleteNode(node.id);
                      }
                    }
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showFolderSelector(BuildContext context, Node node, List<Node> folders) {
    final theme = context.read<ThemeService>().themeData;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.backgrounds.primary,
        title: const Text('Select Folder'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: ListView.builder(
            itemCount: folders.length,
            itemBuilder: (ctx, i) {
              final folder = folders[i];
              return ListTile(
                leading: Icon(Icons.folder, color: theme.nodes.folderPrimary),
                title: Text(folder.title),
                onTap: () async {
                  Navigator.pop(ctx);
                  // 从旧文件夹移除
                  final oldParent = _getParentFolder(node);
                  if (oldParent != null) {
                    await _removeFromFolder(node, oldParent);
                  }
                  // 添加到新文件夹
                  await _addToFolder(node, folder);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Node? _getParentFolder(Node node) {
    for (final folder in widget.folders) {
      final ref = folder.references[node.id];
      if (ref != null && ref.type == ReferenceType.contains) {
        return folder;
      }
    }
    return null;
  }

  void _showReferencesInfo(BuildContext context, Node node) {
    final theme = context.read<ThemeService>().themeData;

    // 合并 widget.nodes 和 widget.folders 来查找所有可能的节点
    final allNodes = [...widget.nodes, ...widget.folders];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.backgrounds.primary,
        title: Text('References: ${node.title}'),
        content: SizedBox(
          width: 400,
          child: node.references.isEmpty
              ? const Text('No references yet.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: node.references.entries.map((entry) {
                    final ref = entry.value;
                    // 使用 allNodes 来查找节点，包括文件夹
                    final matchingNodes = allNodes.where((n) => n.id == entry.key);
                    final targetNode = matchingNodes.isNotEmpty ? matchingNodes.first : null;

                    // 如果找不到目标节点，显示简化信息
                    if (targetNode == null) {
                      return ListTile(
                        leading: const Icon(Icons.help_outline, size: 16),
                        title: Text('Unknown Node (${entry.key})'),
                        subtitle: Text(_getReferenceTypeLabel(ref.type)),
                        trailing: ref.role != null
                            ? Chip(
                                label: Text(ref.role!),
                                padding: EdgeInsets.zero,
                              )
                            : null,
                      );
                    }

                    return ListTile(
                      leading: Icon(
                        targetNode.isFolder
                            ? Icons.folder
                            : Icons.note,
                        size: 16,
                        color: targetNode.isFolder
                            ? theme.nodes.folderPrimary
                            : null,
                      ),
                      title: Text(targetNode.title),
                      subtitle: Text(_getReferenceTypeLabel(ref.type)),
                      trailing: ref.role != null
                          ? Chip(
                              label: Text(ref.role!),
                              padding: EdgeInsets.zero,
                            )
                          : null,
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getReferenceTypeLabel(ReferenceType type) {
    switch (type) {
      case ReferenceType.mentions:
        return 'Mentions';
      case ReferenceType.contains:
        return 'Contains';
      case ReferenceType.dependsOn:
        return 'Depends On';
      case ReferenceType.causes:
        return 'Causes';
      case ReferenceType.partOf:
        return 'Part Of';
      case ReferenceType.relatesTo:
        return 'Related';
      case ReferenceType.references:
        return 'References';
      case ReferenceType.instanceOf:
        return 'Instance Of';
    }
  }
}
