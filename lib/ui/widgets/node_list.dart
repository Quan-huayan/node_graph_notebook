import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/services/theme_service.dart';
import '../models/models.dart';
import '../pages/markdown_editor_page.dart';
import '../dialogs/connection_dialog.dart';

/// 节点列表项
class NodeListItem extends StatelessWidget {
  const NodeListItem({super.key, required this.node});

  final Node node;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>().themeData;
    return ListTile(
      leading: Icon(
        node.isConcept ? Icons.category : Icons.note,
        color: node.isConcept
            ? theme.nodes.conceptPrimary
            : theme.nodes.contentPrimary,
      ),
      title: Text(node.title),
      subtitle: Text(
        node.isConcept ? 'Concept' : 'Content',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () {
        context.read<NodeModel>().selectNode(node.id);

        // 打开编辑器
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => MarkdownEditorPage(node: node),
          ),
        );
      },
      onLongPress: () {
        // 显示菜单
        _showNodeMenu(context, node);
      },
    );
  }

  void _showNodeMenu(BuildContext context, Node node) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Consumer<NodeModel>(
          builder: (ctx, nodeModel, child) {
            // 找出已连接的节点
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
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete'),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: ctx,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Node'),
                        content: Text(
                            'Are you sure you want to delete "${node.title}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && ctx.mounted) {
                      Navigator.pop(ctx);
                      final graphModel = context.read<GraphModel>();

                      // 先从图中移除
                      if (graphModel.hasGraph) {
                        await graphModel.removeNode(node.id);
                      }

                      // 再删除节点本身
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

  void _showReferencesInfo(BuildContext context, Node node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                        targetNode.isConcept
                            ? Icons.category
                            : Icons.note,
                        size: 16,
                      ),
                      title: Text(entry.key),
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