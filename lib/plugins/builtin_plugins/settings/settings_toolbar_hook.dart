import 'package:flutter/material.dart';
import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/ui_hook.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../ui/dialogs/settings_dialog.dart';

/// 设置工具栏钩子
class SettingsToolbarHook extends MainToolbarHook {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  int get priority => 40;

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'settings_toolbar_hook',
        name: 'Settings Toolbar Hook',
        version: '1.0.0',
        description: 'Provides settings button in toolbar',
        author: 'Node Graph Notebook',
      );

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    return IconButton(
      icon: const Icon(Icons.settings),
      onPressed: () => _openSettingsDialog(context),
      tooltip: 'Settings',
    );
  }

  void _openSettingsDialog(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    showDialog(
      context: buildContext,
      builder: (ctx) => const SettingsDialog(),
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
