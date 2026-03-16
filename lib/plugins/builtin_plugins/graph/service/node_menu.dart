import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/models.dart';
import '../../editor/ui/markdown_editor_page.dart';
import '../bloc/node_bloc.dart';
import '../bloc/node_event.dart';
import '../bloc/node_state.dart';

/// 显示节点菜单
void showNodeMenu(BuildContext context, Node node) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: BlocBuilder<NodeBloc, NodeState>(
        builder: (ctx, nodeState) => Column(
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
              const ListTile(
                leading: Icon(Icons.link),
                title: Text('Connect to...'),
                trailing: Icon(Icons.chevron_right),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('References'),
                trailing: Chip(
                  label: Text('${node.references.length}'),
                  padding: EdgeInsets.zero,
                ),
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
                        'Are you sure you want to delete "${node.title}"?',
                      ),
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

                  if ((confirmed ?? false) && ctx.mounted) {
                    Navigator.pop(ctx);
                    context.read<NodeBloc>().add(NodeDeleteEvent(node.id));
                  }
                },
              ),
            ],
          ),
      ),
    ),
  );
}
