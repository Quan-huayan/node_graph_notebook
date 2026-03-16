import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/models.dart';
import '../../graph/bloc/graph_bloc.dart';
import '../../graph/bloc/graph_event.dart';

/// 布局菜单
class LayoutMenu {
  /// 显示布局菜单
  ///
  /// [context] - 构建上下文
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Layout Algorithm'),
              tileColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: const Text('Force Directed'),
              subtitle: const Text('Physics-based layout'),
              onTap: () {
                Navigator.pop(ctx);
                _applyLayout(context, LayoutAlgorithm.forceDirected);
              },
            ),
            ListTile(
              leading: const Icon(Icons.stacked_line_chart),
              title: const Text('Hierarchical'),
              subtitle: const Text('Tree-based layout'),
              onTap: () {
                Navigator.pop(ctx);
                _applyLayout(context, LayoutAlgorithm.hierarchical);
              },
            ),
            ListTile(
              leading: const Icon(Icons.circle_outlined),
              title: const Text('Circular'),
              subtitle: const Text('Circle arrangement'),
              onTap: () {
                Navigator.pop(ctx);
                _applyLayout(context, LayoutAlgorithm.circular);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _applyLayout(
    BuildContext context,
    LayoutAlgorithm algorithm,
  ) async {
    final bloc = context.read<GraphBloc>();

    // 检查是否有节点
    if (bloc.state.nodes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No nodes to layout. Create some nodes first.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 应用布局
    bloc.add(LayoutApplyEvent(algorithm));
  }
}
