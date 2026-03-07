import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:node_graph_notebook/ui/dialogs/node_connections_dialog.dart';
import '../../core/models/models.dart';
import '../../bloc/blocs.dart';
import '../pages/markdown_editor_page.dart';
import '../dialogs/connection_dialog.dart';

/// 显示节点菜单
void showNodeMenu(BuildContext context, Node node) {
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
                  showDialog(
                    context: context,
                    builder: (ctx) => NodeConnectionsDialog(
                      node: node,
                    ),
                  );
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

