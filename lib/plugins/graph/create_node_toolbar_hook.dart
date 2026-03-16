import 'package:flutter/material.dart';

import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/ui_hook.dart';
import 'service/create_node_dialog.dart';

/// 创建节点工具栏钩子
class CreateNodeToolbarHook extends MainToolbarHook {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  int get priority => 70;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'create_node_toolbar_hook',
    name: 'Create Node Toolbar Hook',
    version: '1.0.0',
    description: 'Provides create node button in toolbar',
    author: 'Node Graph Notebook',
    enabledByDefault: true,
  );

  @override
  Widget renderToolbar(MainToolbarHookContext context) => IconButton(
      icon: const Icon(Icons.add),
      onPressed: () => _showCreateNodeDialog(context),
      tooltip: 'Create Node',
    );

  void _showCreateNodeDialog(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    showDialog(context: buildContext, builder: (ctx) => const CreateNodeDialog());
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
