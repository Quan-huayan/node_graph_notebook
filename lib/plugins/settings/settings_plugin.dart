import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_point_registry.dart';
import 'settings_toolbar_hook.dart';

/// Settings 插件
///
/// 提供设置相关的 UI Hooks
class SettingsPlugin extends Plugin {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'settings',
    name: 'Settings',
    version: '1.0.0',
    description: 'Settings and configuration functionality',
    author: 'Node Graph Notebook',
    enabledByDefault: true,
  );

  @override
  List<HookFactory> registerHooks() => [
    SettingsToolbarHook.new,
  ];

  @override
  List<HookPointDefinition> registerHookPoints() => [
    const HookPointDefinition(
      id: 'settings',
      name: 'Settings',
      description: 'Application settings',
      category: 'settings',
      contextType: SettingsHookContext,
    ),
  ];

  @override
  Future<void> onLoad(PluginContext context) async {
    // 加载时的逻辑
  }

  @override
  Future<void> onEnable() async {
    // 启用时的逻辑
  }

  @override
  Future<void> onDisable() async {
    // 禁用时的逻辑
  }

  @override
  Future<void> onUnload() async {
    // 卸载时的逻辑
  }
}
