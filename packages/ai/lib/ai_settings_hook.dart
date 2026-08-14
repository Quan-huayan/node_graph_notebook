import 'package:core/infrastructure/i18n.dart';
import 'package:core/infrastructure/settings_registry.dart';
import 'package:flutter/material.dart';
import 'package:node_settings/settings_hook_base.dart';
import 'package:plugin/plugin.dart';
import 'package:provider/provider.dart';

import 'ui/ai_config_dialog.dart';
import 'ui/ai_test_dialog.dart';

/// AI Settings Hook
///
/// Provides AI configuration UI in the settings panel.
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
    final settingsRegistry = context.get<SettingsRegistry>('settingsRegistry');

    if (buildContext == null || settingsRegistry == null) {
      return const SizedBox.shrink();
    }

    final apiKey = settingsRegistry.getOrElse<String?>('ai.apiKey', null);
    final isConfigured = apiKey != null && apiKey.isNotEmpty;
    final provider = settingsRegistry.getOrElse<String>('ai.provider', 'openai');
    final model = settingsRegistry.getOrElse<String>('ai.model', 'gpt-4');

    return Consumer<I18n>(
      builder: (ctx, i18n, child) => Column(
          children: [
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: Text(i18n.t('AI Settings')),
              subtitle: Text(
                isConfigured
                    ? '$provider - $model'
                    : i18n.t('Not configured'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAIConfigDialog(buildContext, settingsRegistry),
            ),
            if (isConfigured)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(i18n.t('Test AI Connection')),
                subtitle: Text(i18n.t('Chat with AI to test the configuration')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAITestDialog(buildContext),
              ),
          ],
        ),
    );
  }

  void _showAIConfigDialog(BuildContext context, SettingsRegistry settingsRegistry) {
    showDialog(
      context: context,
      builder: (ctx) => AIConfigDialog(settingsRegistry: settingsRegistry),
    );
  }

  void _showAITestDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const AITestDialog());
  }
}
