import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_priority.dart';
import '../../../core/services/i18n.dart';
import 'bloc/graph_bloc.dart';
import 'bloc/node_bloc.dart';
import 'ui/graph_nodes_dialog.dart';

/// 图节点管理工具栏钩子
///
/// 注册到 graph.toolbar hook point，用于可拖动工具栏
class GraphNodesToolbarHook extends GraphToolbarHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'graph_nodes_toolbar_hook',
    name: 'Graph Nodes Toolbar Hook',
    version: '1.0.0',
    description: 'Provides graph nodes management button in graph toolbar',
  );

  @override
  HookPriority get priority => HookPriority.custom150;

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return const SizedBox.shrink();

    // 使用Consumer监听语言变化
    return Consumer<I18n>(
      builder: (ctx, i18n, child) => IconButton(
          icon: const Icon(Icons.playlist_add_check),
          onPressed: () => _showGraphNodesDialog(context),
          tooltip: i18n.t('Manage Graph Nodes'),
        ),
    );
  }

  void _showGraphNodesDialog(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    // 直接从 BuildContext 读取 BLoC，确保类型安全
    final graphBloc = buildContext.read<GraphBloc>();
    final nodeBloc = buildContext.read<NodeBloc>();

    showDialog(
      context: buildContext,
      builder: (ctx) => GraphNodesDialog(graphBloc: graphBloc, nodeBloc: nodeBloc),
    );
  }
}
