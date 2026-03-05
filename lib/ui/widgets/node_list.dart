import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/models.dart';
import '../../core/services/theme_service.dart';
import '../blocs/blocs.dart';
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
        Icons.note,
        color: theme.nodes.nodePrimary,
      ),
      title: Text(node.title),
      subtitle: Text(
        'Content',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () {
        context.read<NodeBloc>().add(NodeSelectEvent(node.id));

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
        child: BlocBuilder<NodeBloc, NodeState>(
          builder: (ctx, nodeState) {
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
                        availableNodes: nodeState.nodes,
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
                      final graphBloc = context.read<GraphBloc>();

                      // 先从图中移除
                      final state = graphBloc.state;
                      if (state.hasGraph) {
                        graphBloc.add(NodeDeleteEvent(node.id));
                      }

                      // 再删除节点本身
                      context.read<NodeBloc>().add(NodeDeleteEvent(node.id));
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
      builder: (ctx) => BlocBuilder<NodeBloc, NodeState>(
        builder: (ctx, nodeState) {
          return AlertDialog(
            title: Text('References: ${node.title}'),
            content: SizedBox(
              width: 400,
              child: node.references.isEmpty
                  ? const Text('No references yet.')
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: node.references.entries.map((entry) {
                        final ref = entry.value;
                        final targetNode = nodeState.nodes.firstWhere(
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
          );
        },
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