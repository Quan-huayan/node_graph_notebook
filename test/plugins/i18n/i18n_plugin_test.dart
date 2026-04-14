import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:node_graph_notebook/core/cqrs/commands/command_bus.dart';
import 'package:node_graph_notebook/core/plugin/plugin.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_registry.dart';
import 'package:node_graph_notebook/core/services/i18n.dart';
import 'package:node_graph_notebook/plugins/i18n/i18n_plugin.dart';

@GenerateMocks([
  CommandBus,
])
import 'i18n_plugin_test.mocks.dart';

void main() {
  group('I18nPlugin', () {
    late PluginManager pluginManager;
    late HookRegistry hookRegistry;
    late MockCommandBus mockCommandBus;
    late ServiceRegistry serviceRegistry;

    setUp(() {
      mockCommandBus = MockCommandBus();
      hookRegistry = HookRegistry();
      serviceRegistry = ServiceRegistry();

      pluginManager = PluginManager(
        commandBus: mockCommandBus,
        hookRegistry: hookRegistry,
        serviceRegistry: serviceRegistry,
      );

      // 注册 I18nPlugin 工厂
      pluginManager.discoverer.registerFactory(
        'i18n',
        I18nPlugin.new,
      );
    });

    test('应该注册 I18n 服务', () {
      final plugin = I18nPlugin();
      final services = plugin.registerServices();

      expect(services.length, 1);
      expect(services.first.serviceType, I18n);
    });

    test('应该注册语言切换 Hook', () {
      final plugin = I18nPlugin();
      final hooks = plugin.registerHooks();

      expect(hooks.length, 1);
      expect(hooks.first().metadata.id, 'i18n.language_toggle');
    });

    test('应该能够成功加载插件', () async {
      await pluginManager.loadPlugin('i18n');

      final plugin = pluginManager.getPlugin('i18n');
      expect(plugin, isNotNull);
      expect(plugin?.plugin.metadata.id, 'i18n');
      expect(plugin?.state, PluginState.loaded);
    });

    test('应该能够成功启用插件', () async {
      await pluginManager.loadPlugin('i18n');
      await pluginManager.enablePlugin('i18n');

      final plugin = pluginManager.getPlugin('i18n');
      expect(plugin?.state, PluginState.enabled);
    });

    test('应该注册 Hook 到 HookRegistry', () async {
      await pluginManager.loadPlugin('i18n');
      await pluginManager.enablePlugin('i18n');

      final hooks = hookRegistry.getHookWrappers('main.toolbar');
      expect(hooks.isNotEmpty, true);

      final i18nHook = hooks.firstWhere(
        (h) => h.hook.metadata.id == 'i18n.language_toggle',
      );
      expect(i18nHook, isNotNull);
    });

    tearDown(() async {
      // 只在插件已加载的情况下才卸载
      final plugin = pluginManager.getPlugin('i18n');
      if (plugin != null) {
        await pluginManager.unloadPlugin('i18n');
      }
    });
  });
}
