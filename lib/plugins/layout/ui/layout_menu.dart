import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/i18n.dart';
import '../../graph/bloc/graph_bloc.dart';
import '../../graph/bloc/graph_event.dart';

/// 布局菜单
class LayoutMenu {
  /// 显示布局菜单
  ///
  /// [context] - 构建上下文
  static void show(BuildContext context) {
    final i18n = I18n.of(context);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(i18n.t('Layout Algorithm')),
              tileColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: Text(i18n.t('Force Directed')),
              subtitle: Text(i18n.t('Physics-based layout')),
              onTap: () {
                Navigator.pop(ctx);
                _applyLayout(context, LayoutAlgorithm.forceDirected);
              },
            ),
            ListTile(
              leading: const Icon(Icons.stacked_line_chart),
              title: Text(i18n.t('Hierarchical')),
              subtitle: Text(i18n.t('Tree-based layout')),
              onTap: () {
                Navigator.pop(ctx);
                _applyLayout(context, LayoutAlgorithm.hierarchical);
              },
            ),
            ListTile(
              leading: const Icon(Icons.circle_outlined),
              title: Text(i18n.t('Circular')),
              subtitle: Text(i18n.t('Circle arrangement')),
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
    final i18n = I18n.of(context);
    final bloc = context.read<GraphBloc>();

    // 检查是否有节点
    if (bloc.state.nodes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(i18n.t('No nodes to layout. Create some nodes first.')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 应用布局
    bloc.add(LayoutApplyEvent(algorithm));
  }
}
