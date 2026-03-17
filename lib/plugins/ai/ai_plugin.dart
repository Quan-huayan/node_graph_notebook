import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_base.dart';
import 'ai_integration_plugin.dart';
import 'ai_settings_hook.dart';
import 'ai_toolbar_hook.dart';

/// AI 插件
///
/// 提供 AI 相关的服务和 Hooks
/// 这个 Plugin 类负责注册服务和 UI Hooks
class AIPlugin extends Plugin {
  /// 插件状态
  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'ai_plugin',
    name: 'AI Plugin',
    version: '1.0.0',
    description: 'Provides AI-powered features for node analysis and connection suggestions',
    author: 'Node Graph Notebook',
    dependencies: [],
  );

  @override
  List<HookFactory> registerHooks() => [
        AIIntegrationPlugin.new,
        AISettingsHook.new,
        AIToolbarHook.new,
      ];

  @override
  Future<void> onLoad(PluginContext context) async {
    // 初始化插件
    context.info('AI Plugin loaded');
  }

  @override
  Future<void> onEnable() async {
    // 启用功能
  }

  @override
  Future<void> onDisable() async {
    // 禁用功能
  }

  @override
  Future<void> onUnload() async {
    // 清理资源
  }
}
