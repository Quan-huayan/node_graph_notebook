import 'package:flutter/material.dart';
import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/ui_hook.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';

/// AI助手工具栏钩子
class AIToolbarHook extends MainToolbarHook {
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
        id: 'ai_toolbar_hook',
        name: 'AI Toolbar Hook',
        version: '1.0.0',
        description: 'Provides AI assistant button in toolbar',
        author: 'Node Graph Notebook',
      );

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    return IconButton(
      icon: const Icon(Icons.smart_toy),
      onPressed: () => _addAIAssistant(context),
      tooltip: 'AI Assistant',
    );
  }

  void _addAIAssistant(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    try {
      // 通过命令总线执行创建AI助手节点的命令
      // 这里需要在AI插件中实现相应的命令和处理器
      ScaffoldMessenger.of(buildContext).showSnackBar(
        const SnackBar(content: Text('AI Assistant functionality coming soon!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(buildContext).showSnackBar(
        SnackBar(content: Text('Failed to add AI Assistant: $e')),
      );
    }
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
