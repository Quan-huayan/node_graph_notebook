import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/services/theme_service.dart';
import '../models/models.dart';
import '../pages/markdown_editor_page.dart';
import 'connection_dialog.dart';

/// 文件夹树形视图
class FolderTreeView extends StatefulWidget {
  const FolderTreeView({
    super.key,
    required this.nodes,
    required this.folders,
  });

  final List<Node> nodes;
  final List<Node> folders;

  @override
  State<FolderTreeView> createState() => _FolderTreeViewState();
}

class _FolderTreeViewState extends State<FolderTreeView> {
  final Set<String> _expandedFolders = {};

  /// 获取文件夹中的子节点
  List<Node> _getFolderChildren(Node folder) {
    return widget.nodes.where((node) {
      final ref = folder.references[node.id];
      return ref != null && ref.type == ReferenceType.contains;
    }).toList();
  }

  /// 获取不在任何文件夹中的节点
  List<Node> _getRootNodes() {
    final folderContainedIds = widget.nodes
        .expand((folder) => folder.references.keys)
        .toSet();

    return widget.nodes.where((node) {
      return !folderContainedIds.contains(node.id);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rootNodes = _getRootNodes();
    final folders = widget.folders;

    if (rootNodes.isEmpty && folders.isEmpty) {
      return const Center(child: Text('No nodes yet'));
    }

    return ListView(
      children: [
        // 文件夹列表
        ...folders.map((folder) => _buildFolderItem(context, folder)),

        // 分隔线
        if (folders.isNotEmpty && rootNodes.isNotEmpty)
          const Divider(height: 32),

        // 根节点列表
        ...rootNodes.map((node) => _buildNodeItem(context, node)),
      ],
    );
  }

  Widget _buildFolderItem(BuildContext context, Node folder) {
    final children = _getFolderChildren(folder);
    final isExpanded = _expandedFolders.contains(folder.id);
    final theme = context.watch<ThemeService>().themeData;

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedFolders.remove(folder.id);
              } else {
                _expandedFolders.add(folder.id);
              }
            });
          },
          onLongPress: () => _showNodeMenu(context, folder),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 20,
                ),
                Icon(Icons.folder, color: theme.nodes.folderPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    folder.title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (children.isNotEmpty)
                  Chip(
                    label: Text('${children.length}'),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
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
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              children: children.map((child) => _buildNodeItem(context, child)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildNodeItem(BuildContext context, Node node) {
    final theme = context.watch<ThemeService>().themeData;
    return InkWell(
      onTap: () {
        context.read<NodeModel>().selectNode(node.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => MarkdownEditorPage(node: node),
          ),
        );
      },
      onLongPress: () => _showNodeMenu(context, node),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            const SizedBox(width: 28),
            Icon(
              node.isConcept ? Icons.category : Icons.note,
              size: 16,
              color: node.isConcept ? theme.nodes.conceptPrimary : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                node.title,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 16),
              onPressed: () => _showNodeMenu(context, node),
            ),
          ],
        ),
      ),
    );
  }

  void _showNodeMenu(BuildContext context, Node node) {
    final nodeModel = context.read<NodeModel>();

    // 找出所有文件夹（概念节点）
    final folders = nodeModel.nodes.where((n) => n.isFolder).toList();

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Consumer<NodeModel>(
          builder: (ctx, nodeModel, child) {
            final connectedNodes = nodeModel.nodes
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
                // 转换为文件夹（仅概念节点）
                if (!node.isFolder && node.isConcept)
                  ListTile(
                    leading: const Icon(Icons.folder),
                    title: const Text('Convert to Folder'),
                    subtitle: const Text('Use as folder to organize nodes'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _convertToFolder(context, node);
                    },
                  ),
                // 添加到文件夹
                if (!node.isFolder && folders.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: const Text('Add to Folder...'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showFolderSelector(context, node, folders);
                    },
                  ),
                // 从文件夹移除
                if (!_isRootNode(node))
                  ListTile(
                    leading: const Icon(Icons.remove_circle_outline),
                    title: const Text('Remove from Folder'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _removeFromFolder(context, node);
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
                      showDialog(
                        context: context,
                        builder: (ctx) => DisconnectDialog(
                          sourceNode: node,
                          connectedNodes: connectedNodes,
                        ),
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
                  leading: Builder(
                    builder: (ctx) {
                      final theme = ctx.watch<ThemeService>().themeData;
                      return Icon(Icons.delete, color: theme.status.error);
                    },
                  ),
                  title: const Text('Delete'),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: ctx,
                      builder: (dialogCtx) {
                        final theme = context.read<ThemeService>().themeData;
                        return AlertDialog(
                          backgroundColor: theme.backgrounds.primary,
                          title: const Text('Delete Node'),
                          content: Text(
                              'Are you sure you want to delete "${node.title}"?'),
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

                    if (confirmed == true && ctx.mounted) {
                      Navigator.pop(ctx);
                      final graphModel = context.read<GraphModel>();

                      if (graphModel.hasGraph) {
                        await graphModel.removeNode(node.id);
                      }

                      await context.read<NodeModel>().deleteNode(node.id);
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

  /// 检查节点是否在某个文件夹中
  bool _isRootNode(Node node) {
    for (final folder in widget.folders) {
      if (folder.references.containsKey(node.id) &&
          folder.references[node.id]!.type == ReferenceType.contains) {
        return false;
      }
    }
    return true;
  }

  /// 获取包含此节点的文件夹
  Node? _getParentFolder(Node node) {
    for (final folder in widget.folders) {
      final ref = folder.references[node.id];
      if (ref != null && ref.type == ReferenceType.contains) {
        return folder;
      }
    }
    return null;
  }

  /// 转换为文件夹
  Future<void> _convertToFolder(BuildContext context, Node node) async {
    final nodeModel = context.read<NodeModel>();

    // 更新节点的 metadata 标记为文件夹
    final updatedNode = node.copyWith(
      metadata: {...node.metadata, 'isFolder': true},
    );

    await nodeModel.replaceNode(updatedNode);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${node.title}" is now a folder')),
      );
    }
  }

  /// 显示文件夹选择器
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
                  await _addToFolder(context, node, folder);
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

  /// 添加节点到文件夹
  Future<void> _addToFolder(BuildContext context, Node node, Node folder) async {
    final nodeModel = context.read<NodeModel>();

    // 创建 contains 引用
    final updatedFolder = folder.copyWith(
      references: {
        ...folder.references,
        node.id: NodeReference(
          nodeId: node.id,
          type: ReferenceType.contains,
        ),
      },
    );

    await nodeModel.replaceNode(updatedFolder);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added "${node.title}" to "${folder.title}"')),
      );
    }
  }

  /// 从文件夹移除节点
  Future<void> _removeFromFolder(BuildContext context, Node node) async {
    final nodeModel = context.read<NodeModel>();
    final parentFolder = _getParentFolder(node);

    if (parentFolder == null) return;

    // 移除引用
    final newReferences = Map<String, NodeReference>.from(parentFolder.references);
    newReferences.remove(node.id);

    final updatedFolder = parentFolder.copyWith(references: newReferences);

    await nodeModel.replaceNode(updatedFolder);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "${node.title}" from "${parentFolder.title}"')),
      );
    }
  }

  void _showReferencesInfo(BuildContext context, Node node) {
    final theme = context.read<ThemeService>().themeData;
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
                    final nodeModel = context.read<NodeModel>();
                    final targetNode = nodeModel.nodes.firstWhere(
                      (n) => n.id == entry.key,
                      orElse: () => ref as Node,
                    );

                    return ListTile(
                      leading: Icon(
                        targetNode.isFolder
                            ? Icons.folder
                            : (targetNode.isConcept ? Icons.category : Icons.note),
                        size: 16,
                        color: targetNode.isFolder ? theme.nodes.folderPrimary : null,
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

/// Node 扩展 - 检查是否为文件夹
extension NodeExtension on Node {
  bool get isFolder {
    return metadata['isFolder'] == true || isConcept;
  }
}
