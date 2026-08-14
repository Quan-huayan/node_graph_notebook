import 'package:core/core.dart' hide Plugin, PluginManager;
import 'package:flutter/material.dart';
import 'package:node_graph/flame/graph_world.dart' as graph_world;
import 'package:node_graph/service/node_service.dart';
import 'package:plugin/plugin.dart';

import 'ai_integration_hook.dart';
import 'ai_settings_hook.dart';
import 'ai_toolbar_hook.dart';
import 'command/ai_commands.dart';
import 'handler/analyze_node_handler.dart';
import 'service/ai_service.dart';
import 'ui/ai_chat_dialog.dart';

/// AI Plugin
class AIPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'ai_plugin',
    name: 'AI Plugin',
    version: '2.0.0',
    description: 'Provides AI-powered features with function calling support',
    author: 'Node Graph Notebook',
  );

  @override
  List<ServiceRegistration> registerServices() => [];

  @override
  List<HookFactory> registerHooks() => [
    AIIntegrationHook.new,
    AISettingsHook.new,
    AIToolbarHook.new,
  ];

  @override
  Future<void> onLoad(PluginContext context) async {
    _registerCommandHandlers(context);

    final registry = context.tryGet<SettingsRegistry>();
    if (registry != null) {
      _registerAISettings(registry);
    }
    await _migrateLegacySettings(context);

    graph_world.GraphWorld.onAIChatTap = (aiNode, connectedNodes, buildContext) {
      showDialog(
        context: buildContext,
        builder: (dialogContext) =>
            AIChatDialog(aiNode: aiNode, connectedNodes: connectedNodes),
      );
    };

    debugPrint('[AIPlugin] AI Plugin loaded');
  }

  void _registerCommandHandlers(PluginContext context) {
    final commandBus = context.get<CommandBus>();
    final aiService = context.get<AIService>();
    final nodeService = context.get<NodeService>();

    commandBus.registerHandlers({
      AnalyzeNodeCommand: AnalyzeNodeHandler(aiService),
      SuggestConnectionsCommand: SuggestConnectionsHandler(aiService),
      GenerateGraphSummaryCommand: GenerateGraphSummaryHandler(aiService),
      GenerateNodeCommand: GenerateNodeHandler(aiService, nodeService),
    });
  }

  void _registerAISettings(SettingsRegistry registry) {
    registry.register(SettingDefinition<String>(
      key: 'ai.provider', defaultValue: 'openai',
      displayName: 'AI Provider', description: 'AI service provider', category: 'AI',
      validator: (value) => ['openai', 'anthropic', 'zhipuai'].contains(value) ? value : 'openai',
    ));
    registry.register(const SettingDefinition<String>(
      key: 'ai.baseUrl', defaultValue: 'https://api.openai.com/v1',
      displayName: 'AI Base URL', description: 'AI API base URL', category: 'AI',
    ));
    registry.register(const SettingDefinition<String>(
      key: 'ai.model', defaultValue: 'gpt-4',
      displayName: 'AI Model', description: 'AI model name', category: 'AI',
    ));
    registry.register(const SettingDefinition<String?>(
      key: 'ai.apiKey', defaultValue: null,
      displayName: 'AI API Key', description: 'AI API key', category: 'AI', isSensitive: true,
    ));
  }

  Future<void> _migrateLegacySettings(PluginContext context) async {
    final prefs = context.tryGet<SharedPreferencesAsync>();
    final registry = context.tryGet<SettingsRegistry>();
    if (prefs == null || registry == null) return;
    for (final key in ['ai_api_key', 'ai_provider', 'ai_base_url', 'ai_model', 'ai_temperature']) {
      final old = await prefs.getString(key);
      if (old != null) {
        final newKey = key.replaceFirst('ai_', 'ai.');
        await registry.set(newKey, old);
        await prefs.remove(key);
      }
    }
  }
}
