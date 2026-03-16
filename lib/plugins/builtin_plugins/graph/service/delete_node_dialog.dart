import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/services.dart';
import '../bloc/node_bloc.dart';
import '../bloc/node_event.dart';

/// 删除节点对话框
class DeleteNodeDialog {
  /// 显示删除节点对话框
  ///
  /// [context] - 构建上下文
  static Future<void> show(BuildContext context) async {
    final nodeBloc = context.read<NodeBloc>();
    final nodeState = nodeBloc.state;

    // 检查是否有选中的节点
    if (nodeState.selectedNode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No node selected. Click a node to select it first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final node = nodeState.selectedNode!;

    // 确认删除
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = context.read<ThemeService>().themeData;
        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: const Text('Delete Node'),
          content: Text('Are you sure you want to delete "${node.title}"?'),
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
        );
      },
    );

    if (confirmed ?? false) {
      try {
        // 再删除节点本身
        nodeBloc.add(NodeDeleteEvent(node.id));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted: ${node.title}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          final theme = context.read<ThemeService>().themeData;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete node: $e'),
              backgroundColor: theme.status.error,
            ),
          );
        }
      }
    }
  }
}
