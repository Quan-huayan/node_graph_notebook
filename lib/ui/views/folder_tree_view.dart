import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../bloc/blocs.dart';
import '../pages/markdown_editor_page.dart';

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
  Map<String, int>? _nodeDepths;

  @override
  void initState() {
    super.initState();
    _calculateDepths();
  }

  @override
  void didUpdateWidget(FolderTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodes != widget.nodes || oldWidget.folders != widget.folders) {
      _calculateDepths();
    }
  }

  /// 计算所有节点的深度
  Future<void> _calculateDepths() async {
    final nodeService = context.read<NodeService>();
    final allNodes = [...widget.nodes, ...widget.folders];
    _nodeDepths = await nodeService.calculateNodeDepths(allNodes);
    setState(() {});
  }

  /// 获取文件夹中的直接子节点
  ///
  /// 基于深度计算：找到被该文件夹直接引用的节点
  /// 且这些节点的深度恰好比文件夹深度大1
  List<Node> _getFolderChildren(Node folder, List<Node> nodes) {
    if (_nodeDepths == null) return [];

    final folderDepth = _nodeDepths![folder.id] ?? 0;
    return nodes.where((node) {
      // 检查节点是否被文件夹引用
      if (!folder.references.containsKey(node.id)) return false;

      // 检查节点深度是否为文件夹深度+1（直接子节点）
      final nodeDepth = _nodeDepths![node.id] ?? -1;
      return nodeDepth == folderDepth + 1;
    }).toList();
  }

  /// 获取顶层文件夹（没有被其他文件夹包含的文件夹）
  ///
  /// 基于深度计算：顶层文件夹是深度为0的文件夹
  List<Node> _getTopLevelFolders(List<Node> folders) {
    if (_nodeDepths == null) return [];

    return folders.where((folder) {
      final depth = _nodeDepths![folder.id] ?? -1;
      return depth == 0; // 顶层文件夹深度为0
    }).toList();
  }

  /// 获取不在任何文件夹中的节点
  List<Node> _getRootNodes(List<Node> nodes, List<Node> folders) {
    // 从文件夹中获取所有被包含的节点ID
    final folderContainedIds = folders
        .expand((folder) => folder.references.keys)
        .toSet();

    return nodes.where((node) {
      return !folderContainedIds.contains(node.id);
    }).toList();
  }

  /// 检测是否存在循环关系
  ///
  /// 基于深度检测：如果节点已经在文件夹的子树中，则不能再次添加
  bool _hasCircularContains(Node node, Node folder, List<Node> allNodes) {
    if (_nodeDepths == null) return false;

    // 检查是否将节点拖拽到自身
    if (node.id == folder.id) {
      return true;
    }

    // 检查是否将文件夹拖拽到其子文件夹中
    if (node.isFolder) {
      final folderDepth = _nodeDepths![folder.id] ?? 0;
      final nodeDepth = _nodeDepths![node.id] ?? -1;

      // 如果节点已经是文件夹的子孙节点，不能添加
      // 即：节点的深度大于文件夹深度，且节点被文件夹引用（直接或间接）
      if (nodeDepth > folderDepth) {
        return _isDescendant(folder, node, allNodes);
      }
    }

    return false;
  }

  /// 检查 descendant 是否是 ancestor 的子孙节点
  bool _isDescendant(Node ancestor, Node descendant, List<Node> allNodes) {
    if (_nodeDepths == null) return false;

    final ancestorDepth = _nodeDepths![ancestor.id] ?? 0;
    final descendantDepth = _nodeDepths![descendant.id] ?? -1;

    // 如果后代深度不大于祖先深度，不可能是子孙
    if (descendantDepth <= ancestorDepth) return false;

    // BFS检查是否存在从祖先到后代的路径
    final visited = <String>{};
    final queue = <String>[ancestor.id];

    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      if (currentId == descendant.id) return true;
      if (visited.contains(currentId)) continue;
      visited.add(currentId);

      final currentNode = allNodes.firstWhere((n) => n.id == currentId, orElse: () => ancestor);
      for (final refId in currentNode.references.keys) {
        if (!visited.contains(refId)) {
          queue.add(refId);
        }
      }
    }

    return false;
  }

  /// 将节点添加到文件夹
  Future<void> _addToFolder(Node node, Node folder) async {
    final nodeBloc = context.read<NodeBloc>();
    final allNodes = nodeBloc.state.nodes;

    // 检测循环关系
    if (_hasCircularContains(node, folder, allNodes)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot create circular folder structure')),
        );
      }
      return;
    }

    // 从旧文件夹中移除节点
    final oldParent = _getParentFolder(node);
    if (oldParent != null) {
      await _removeFromFolder(node, oldParent);
    }

    // 创建新的引用（使用 relatesTo 作为通用关系类型）
    final newReferences = Map<String, NodeReference>.from(folder.references);
    newReferences[node.id] = NodeReference(
      nodeId: node.id,
      properties: {'type': 'relatesTo'},
    );

    final updatedFolder = folder.copyWith(references: newReferences);
    nodeBloc.add(NodeReplaceEvent(updatedFolder));

    // 重新计算深度
    await _calculateDepths();

    if (mounted) {
      setState(() {
        _expandedFolders.add(folder.id);
      });
    }
  }

  /// 从文件夹中移除节点
  Future<void> _removeFromFolder(Node node, Node folder) async {
    final nodeBloc = context.read<NodeBloc>();

    final newReferences = Map<String, NodeReference>.from(folder.references);
    newReferences.remove(node.id);

    final updatedFolder = folder.copyWith(references: newReferences);
    nodeBloc.add(NodeReplaceEvent(updatedFolder));

    // 重新计算深度
    await _calculateDepths();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NodeBloc, NodeState>(
      builder: (context, nodeState) {
        // 从 NodeBloc 状态中获取最新的节点和文件夹
        final allNodes = nodeState.nodes;
        final folders = allNodes.where((n) => n.isFolder).toList();

        // 过滤掉 AI 节点
        final nodes = allNodes.where((n) {
          // 排除文件夹
          if (n.isFolder) return false;

          // 检查是否是 AI 节点
          final isAI = n.metadata['isAI'];
          if (isAI == true) return false;
          if (isAI == 'true') return false;

          return true;
        }).toList();

        final rootNodes = _getRootNodes(nodes, folders);
        final topLevelFolders = _getTopLevelFolders(folders);
        final allNodesList = [...nodes, ...folders];

        if (rootNodes.isEmpty && topLevelFolders.isEmpty) {
          return const Center(child: Text('No nodes yet'));
        }

        return ListView(
          children: [
            // 顶层文件夹列表
            ...topLevelFolders.map((folder) => _buildFolderItem(context, folder, allNodesList, 0)),

            // 分隔线
            if (topLevelFolders.isNotEmpty && rootNodes.isNotEmpty)
              const Divider(height: 32),

            // 根节点列表
            ...rootNodes.map((node) => _buildNodeItem(context, node)),
          ],
        );
      },
    );
  }

  Widget _buildFolderItem(BuildContext context, Node folder, List<Node> allNodes, int level) {
    final children = _getFolderChildren(folder, allNodes);
    final isExpanded = _expandedFolders.contains(folder.id);
    final theme = context.watch<ThemeService>().themeData;
    final nodeBloc = context.watch<NodeBloc>();
    final isSelected = nodeBloc.state.selectedNode?.id == folder.id;
    final isDragging = _draggedNodeId == folder.id;

    return DragTarget<String>(
      onAcceptWithDetails: (details) async {
        final draggedNodeId = details.data;
        if (draggedNodeId != folder.id) {
          // 从所有节点中查找被拖拽的节点
          final draggedNode = allNodes.firstWhere((n) => n.id == draggedNodeId);
          if (draggedNode.id.isNotEmpty) {
            await _addToFolder(draggedNode, folder);
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
              Draggable<String>(
                data: folder.id,
                onDragStarted: () {
                  setState(() {
                    _draggedNodeId = folder.id;
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
                        Icon(
                          Icons.folder,
                          size: 16,
                          color: theme.nodes.folderPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(folder.title),
                      ],
                    ),
                  ),
                ),
                child: Opacity(
                  opacity: isDragging ? 0.5 : 1.0,
                  child: InkWell(
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
    final nodeBloc = context.watch<NodeBloc>();
    final isSelected = nodeBloc.state.selectedNode?.id == node.id;
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
    final nodeBloc = context.read<NodeBloc>();
    final folders = nodeBloc.state.nodes.where((n) => n.isFolder).toList();

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: BlocBuilder<NodeBloc, NodeState>(
          builder: (ctx, nodeState) {
            // 合并所有节点来查找连接的节点
            final allNodes = nodeState.nodes;
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
                const ListTile(
                  leading: Icon(Icons.link),
                  title: Text('Connect to...'),
                  trailing: Icon(Icons.chevron_right),
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
                        context.read<NodeBloc>().add(NodeDeleteEvent(node.id));
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
    if (_nodeDepths == null) return null;

    final nodeBloc = context.read<NodeBloc>();
    final allNodes = nodeBloc.state.nodes;

    // 找到引用该节点的文件夹，且该文件夹的深度恰好比节点深度小1
    final nodeDepth = _nodeDepths![node.id] ?? -1;

    for (final folder in allNodes) {
      if (!folder.isFolder) continue;
      if (!folder.references.containsKey(node.id)) continue;

      final folderDepth = _nodeDepths![folder.id] ?? -1;
      if (folderDepth == nodeDepth - 1) {
        return folder;
      }
    }

    return null;
  }

  void _showReferencesInfo(BuildContext context, Node node) {
    final theme = context.read<ThemeService>().themeData;

    showDialog(
      context: context,
      builder: (ctx) => BlocBuilder<NodeBloc, NodeState>(
        builder: (ctx, nodeState) {
          // 合并所有节点来查找所有可能的节点
          final allNodes = nodeState.nodes;

          return AlertDialog(
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
                            subtitle: Text(_getRelationTypesLabel(ref.type)),
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
                          subtitle: Text(_getRelationTypesLabel(ref.type)),
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
          );
        },
      ),
    );
  }

  String _getRelationTypesLabel(String type) {
    switch (type) {
      case 'mentions':
        return 'Mentions';
      case 'contains':
        return 'Contains';
      case 'dependsOn':
        return 'Depends On';
      case 'causes':
        return 'Causes';
      case 'partOf':
        return 'Part Of';
      case 'relatesTo':
        return 'Related';
      case 'references':
        return 'References';
      case 'instanceOf':
        return 'Instance Of';
      default:
        return type;
    }
  }
}

/// Node 扩展 - 检查是否为文件夹
extension NodeExtension on Node {
  bool get isFolder {
    return metadata['isFolder'] == true ||
        (metadata['isFolder'] is bool && metadata['isFolder'] as bool);
  }
}
