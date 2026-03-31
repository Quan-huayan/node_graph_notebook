import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_base.dart';
import 'ai_integration_plugin.dart';
import 'ai_settings_hook.dart';
import 'ai_toolbar_hook.dart';
import 'function_calling/tool/ai_tool_registry.dart';

/// AI 插件
///
/// 提供 AI 相关的服务和 Hooks
/// 这个 Plugin 类负责注册服务和 UI Hooks
/// 支持 Function Calling 功能
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
    version: '2.0.0',
    description: 'Provides AI-powered features with function calling support',
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
    // 初始化内置工具
    AIToolRegistry.instance.initializeBuiltinTools();

    context.info('AI Plugin loaded with function calling support');
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
