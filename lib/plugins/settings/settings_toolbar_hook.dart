import 'package:flutter/material.dart';

import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_priority.dart';
import '../../../ui/dialogs/settings_dialog.dart';

/// 设置工具栏钩子
class SettingsToolbarHook extends MainToolbarHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'settings_toolbar_hook',
    name: 'Settings Toolbar Hook',
    version: '1.0.0',
    description: 'Provides settings button in toolbar',
  );

  @override
  HookPriority get priority => HookPriority.medium;

  @override
  Widget renderToolbar(MainToolbarHookContext context) => IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () => _openSettingsDialog(context),
        tooltip: 'Settings',
      );

  void _openSettingsDialog(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    showDialog(context: buildContext, builder: (ctx) => const SettingsDialog());
  }
}
