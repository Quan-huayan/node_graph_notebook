import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_priority.dart';
import '../../../core/services/i18n.dart';
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
  HookPriority get priority => HookPriority.custom400;

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return const SizedBox.shrink();

    // 使用Consumer监听语言变化
    return Consumer<I18n>(
      builder: (ctx, i18n, child) => IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _openSettingsDialog(context),
          tooltip: i18n.t('Settings'),
        ),
    );
  }

  void _openSettingsDialog(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    showDialog(context: buildContext, builder: (ctx) => const SettingsDialog());
  }
}
