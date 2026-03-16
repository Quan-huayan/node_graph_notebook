import 'package:flutter/material.dart';

import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/ui_hook.dart';
import 'ui/ai_config_dialog.dart';
import 'ui/ai_test_dialog.dart';

/// AI设置钩子
class AISettingsHook extends SettingsHook {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  int get priority => 10;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'ai_settings_hook',
    name: 'AI Settings Hook',
    version: '1.0.0',
    description: 'Provides AI configuration in settings',
    author: 'Node Graph Notebook',
    enabledByDefault: true,
  );

  @override
  Widget renderSettings(SettingsHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    final settingsService = context.data['settingsService'] as dynamic;

    if (buildContext == null || settingsService == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.smart_toy_outlined),
          title: const Text('AI Settings'),
          subtitle: Text(
            settingsService.isAIConfigured
                ? '${settingsService.aiProvider} - ${settingsService.aiModel}'
                : 'Not configured',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showAIConfigDialog(buildContext, settingsService),
        ),
        if (settingsService.isAIConfigured)
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Test AI Connection'),
            subtitle: const Text('Chat with AI to test the configuration'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAITestDialog(buildContext),
          ),
      ],
    );
  }

  void _showAIConfigDialog(BuildContext context, dynamic settingsService) {
    showDialog(
      context: context,
      builder: (ctx) => AIConfigDialog(settingsService: settingsService),
    );
  }

  void _showAITestDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const AITestDialog());
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
