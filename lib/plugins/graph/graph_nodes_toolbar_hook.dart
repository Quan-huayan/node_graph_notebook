import 'package:flutter/material.dart';

import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/ui_hook.dart';
import 'ui/graph_nodes_dialog.dart';

/// 图节点管理工具栏钩子
class GraphNodesToolbarHook extends MainToolbarHook {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  int get priority => 50;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'graph_nodes_toolbar_hook',
    name: 'Graph Nodes Toolbar Hook',
    version: '1.0.0',
    description: 'Provides graph nodes management button in toolbar',
    author: 'Node Graph Notebook',
    enabledByDefault: true,
  );

  @override
  Widget renderToolbar(MainToolbarHookContext context) => IconButton(
      icon: const Icon(Icons.playlist_add_check),
      onPressed: () => _showGraphNodesDialog(context),
      tooltip: 'Manage Graph Nodes',
    );

  void _showGraphNodesDialog(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    final bloc = context.data['graphBloc'] as dynamic;
    final nodeBloc = context.data['nodeBloc'] as dynamic;

    showDialog(
      context: buildContext,
      builder: (ctx) => GraphNodesDialog(graphBloc: bloc, nodeBloc: nodeBloc),
    );
  }

  @override
  Future<void> onInit() async {}

  @override
  Future<void> onDispose() async {}

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onUnload() async {}
}
