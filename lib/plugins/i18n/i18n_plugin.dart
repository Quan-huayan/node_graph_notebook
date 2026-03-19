import '../../core/plugin/plugin.dart';
import '../../core/plugin/ui_hooks/hook_base.dart';
import 'hooks/language_toggle_hook.dart';
import 'service/i18n_service_binding.dart';

/// I18n 插件
///
/// 提供应用国际化支持，包括：
/// - 多语言翻译服务（I18n）
/// - 工具栏语言切换按钮
/// - 动态语言切换功能
///
/// 支持语言：
/// - English (en)
/// - 简体中文 (zh)
///
/// 架构说明：
/// - 通过 I18nServiceBinding 注册 I18n 服务
/// - 通过 LanguageToggleHook 提供语言切换 UI
/// - I18n 服务为全局单例，可在应用任何位置访问
class I18nPlugin extends Plugin {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'i18n',
    name: '国际化',
    version: '1.0.0',
    description: '提供多语言支持和界面汉化',
    author: 'Node Graph Notebook',
    enabledByDefault: true, // 默认启用
  );

  @override
  List<ServiceBinding> registerServices() => [I18nServiceBinding()];

  @override
  List<HookFactory> registerHooks() => [LanguageToggleHook.new];

  @override
  Future<void> onLoad(PluginContext context) async {
    // 插件加载时的初始化逻辑
    // 注意：此时 I18n 服务还未注入到 Provider 树
    // 初始化会在 onEnable 中进行
    context.info('I18n plugin loaded');
  }

  @override
  Future<void> onEnable() async {
    // 插件启用时的逻辑
    // UI Hook 自动注册到工具栏
    // I18n 服务初始化在 ServiceBinding 中自动进行
  }

  @override
  Future<void> onDisable() async {
    // 插件禁用时的逻辑
    // UI Hook 自动从工具栏移除
  }

  @override
  Future<void> onUnload() async {
    // 插件卸载时的清理逻辑
  }
}
