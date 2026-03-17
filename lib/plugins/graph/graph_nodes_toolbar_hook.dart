import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_priority.dart';
import 'bloc/graph_bloc.dart';
import 'bloc/node_bloc.dart';
import 'ui/graph_nodes_dialog.dart';

/// 图节点管理工具栏钩子
class GraphNodesToolbarHook extends MainToolbarHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'graph_nodes_toolbar_hook',
    name: 'Graph Nodes Toolbar Hook',
    version: '1.0.0',
    description: 'Provides graph nodes management button in toolbar',
  );

  @override
  HookPriority get priority => HookPriority.medium;

  @override
  Widget renderToolbar(MainToolbarHookContext context) => IconButton(
        icon: const Icon(Icons.playlist_add_check),
        onPressed: () => _showGraphNodesDialog(context),
        tooltip: 'Manage Graph Nodes',
      );

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
