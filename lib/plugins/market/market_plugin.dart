import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_base.dart';
import 'market_toolbar_hook.dart';

/// Market 插件
///
/// 提供插件市场相关的 UI Hooks
class MarketPlugin extends Plugin {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'market',
    name: 'Market',
    version: '1.0.0',
    description: 'Plugin market and extension management',
    author: 'Node Graph Notebook',
    enabledByDefault: true,
  );

  @override
  List<HookFactory> registerHooks() => [
    MarketToolbarHook.new,
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
