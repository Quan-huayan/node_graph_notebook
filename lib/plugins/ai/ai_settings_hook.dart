import 'package:flutter/material.dart';

import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_priority.dart';
import '../../../core/services/settings_service.dart';
import 'ui/ai_config_dialog.dart';
import 'ui/ai_test_dialog.dart';

/// AI设置钩子
class AISettingsHook extends SettingsHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'ai_settings_hook',
    name: 'AI Settings Hook',
    version: '1.0.0',
    description: 'Provides AI configuration in settings',
  );

  @override
  HookPriority get priority => HookPriority.medium;

  @override
  Widget renderSettings(SettingsHookContext context) {
    final buildContext = context.get<BuildContext>('buildContext');
    final settingsService = context.get<SettingsService>('settingsService');

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

  void _showAIConfigDialog(BuildContext context, SettingsService settingsService) {
    showDialog(
      context: context,
      builder: (ctx) => AIConfigDialog(settingsService: settingsService),
    );
  }

  void _showAITestDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const AITestDialog());
  }
}
