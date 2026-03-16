import 'package:flutter/material.dart';

import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/ui_hook.dart';
import 'ui/layout_menu.dart';

/// 布局工具栏钩子
class LayoutToolbarHook extends MainToolbarHook {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  int get priority => 60;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'layout_toolbar_hook',
    name: 'Layout Toolbar Hook',
    version: '1.0.0',
    description: 'Provides layout button in toolbar',
    author: 'Node Graph Notebook',
    enabledByDefault: true,
  );

  @override
  Widget renderToolbar(MainToolbarHookContext context) => IconButton(
      icon: const Icon(Icons.account_tree),
      onPressed: () => _showLayoutMenu(context),
      tooltip: 'Layout',
    );

  void _showLayoutMenu(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    LayoutMenu.show(buildContext);
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
