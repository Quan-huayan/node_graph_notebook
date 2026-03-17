import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/plugin/api/api_registry.dart';
import 'package:node_graph_notebook/core/plugin/plugin.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_base.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_context.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_metadata.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_priority.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_registry.dart';

class MockPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'mock_plugin',
        name: 'Mock Plugin',
        version: '1.0.0',
        description: 'Mock plugin for testing',
        author: 'Test Author',
        dependencies: [],
        apiDependencies: [],
      );

  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  bool onLoadCalled = false;
  bool onEnableCalled = false;
  bool onDisableCalled = false;
  bool onUnloadCalled = false;

  @override
  Future<void> onLoad(PluginContext context) async {
    onLoadCalled = true;
  }

  @override
  Future<void> onEnable() async {
    onEnableCalled = true;
  }

  @override
  Future<void> onDisable() async {
    onDisableCalled = true;
  }

  @override
  Future<void> onUnload() async {
    onUnloadCalled = true;
  }
}

class MockPluginWithDependency extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'dependent_plugin',
        name: 'Dependent Plugin',
        version: '1.0.0',
        description: 'Plugin with dependency',
        author: 'Test Author',
        dependencies: ['mock_plugin'],
        apiDependencies: [],
      );

  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onUnload() async {}
}

class MockPluginWithAPI extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'api_plugin',
        name: 'API Plugin',
        version: '1.0.0',
        description: 'Plugin that exports API',
        author: 'Test Author',
        dependencies: [],
        apiDependencies: [],
      );

  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onUnload() async {}

  @override
  Map<String, dynamic> exportAPIs() => {
        'test_api': TestAPI(),
      };
}

class MockPluginWithAPIDependency extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'api_dependent_plugin',
        name: 'API Dependent Plugin',
        version: '1.0.0',
        description: 'Plugin that depends on API',
        author: 'Test Author',
        dependencies: [],
        apiDependencies: [APIDependency(apiName: 'test_api')],
      );

  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onUnload() async {}
}

class MockPluginWithService extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'service_plugin',
        name: 'Service Plugin',
        version: '1.0.0',
        description: 'Plugin that provides service',
        author: 'Test Author',
        dependencies: [],
        apiDependencies: [],
      );

  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  List<ServiceBinding> registerServices() => [
        TestServiceBinding(),
      ];

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onUnload() async {}
}

class MockPluginWithHook extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'hook_plugin',
        name: 'Hook Plugin',
        version: '1.0.0',
        description: 'Plugin that provides hook',
        author: 'Test Author',
        dependencies: [],
        apiDependencies: [],
      );

  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  List<HookFactory> registerHooks() => [
        TestHook.new,
      ];

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onUnload() async {}
}

class TestAPI {
  String greet() => 'Hello from TestAPI';
}

class TestService {
  TestService(this.name);
  final String name;
}

class TestServiceBinding extends ServiceBinding<TestService> {
  @override
  TestService createService(ServiceResolver resolver) => TestService('test_service');
}

class TestHook extends UIHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
        id: 'test_hook',
        name: 'Test Hook',
        version: '1.0.0',
      );

  @override
  String get hookPointId => 'test.hook';

  @override
  HookPriority get priority => HookPriority.medium;

  @override
  Widget render(HookContext context) => const SizedBox.shrink();
}

class MockPluginDiscoverer extends PluginDiscoverer {
  final Map<String, Plugin> _plugins = {};

  void registerPlugin(String id, Plugin plugin) {
    _plugins[id] = plugin;
  }

  @override
  Future<Plugin?> discoverPlugin(String pluginId) async => _plugins[pluginId];

  @override
  Future<List<String>> discoverAvailablePlugins() async => _plugins.keys.toList();
}

void main() {
  group('PluginManager', () {
    late PluginManager pluginManager;
    late CommandBus commandBus;
    late MockPluginDiscoverer discoverer;

    setUp(() {
      commandBus = CommandBus();
      discoverer = MockPluginDiscoverer();
      pluginManager = PluginManager(
        commandBus: commandBus,
        discoverer: discoverer,
      );
    });

    tearDown(() {
      commandBus.dispose();
    });

    group('loadPlugin - 基础加载', () {
      test('should load plugin successfully', () async {
        discoverer.registerPlugin('mock_plugin', MockPlugin());
        await pluginManager.loadPlugin('mock_plugin');
        final plugin = pluginManager.getPlugin('mock_plugin');
        expect(plugin, isNotNull);
        expect(plugin!.metadata.id, 'mock_plugin');
      });

      test('should throw error when loading non-existent plugin', () async {
        expect(
          () => pluginManager.loadPlugin('non_existent'),
          throwsA(isA<PluginNotFoundException>()),
        );
      });

      test('should throw error when loading already loaded plugin', () async {
        discoverer.registerPlugin('mock_plugin', MockPlugin());
        await pluginManager.loadPlugin('mock_plugin');
        expect(
          () => pluginManager.loadPlugin('mock_plugin'),
          throwsA(isA<PluginAlreadyExistsException>()),
        );
      });

      test('should call onLoad lifecycle method', () async {
        final mockPlugin = MockPlugin();
        discoverer.registerPlugin('mock_plugin', mockPlugin);
        await pluginManager.loadPlugin('mock_plugin');
        expect(mockPlugin.onLoadCalled, true);
      });
    });

    group('unloadPlugin - 卸载', () {
      test('should unload plugin successfully', () async {
        discoverer.registerPlugin('mock_plugin', MockPlugin());
        await pluginManager.loadPlugin('mock_plugin');
        await pluginManager.unloadPlugin('mock_plugin');
        final plugin = pluginManager.getPlugin('mock_plugin');
        expect(plugin, isNull);
      });

      test('should call onUnload lifecycle method', () async {
        final mockPlugin = MockPlugin();
        discoverer.registerPlugin('mock_plugin', mockPlugin);
        await pluginManager.loadPlugin('mock_plugin');
        await pluginManager.unloadPlugin('mock_plugin');
        expect(mockPlugin.onUnloadCalled, true);
      });

      test('should throw error when unloading non-existent plugin', () async {
        expect(
          () => pluginManager.unloadPlugin('non_existent'),
          throwsA(isA<PluginNotFoundException>()),
        );
      });

      test('should disable plugin before unloading if enabled', () async {
        final mockPlugin = MockPlugin();
        discoverer.registerPlugin('mock_plugin', mockPlugin);
        await pluginManager.loadPlugin('mock_plugin');
        await pluginManager.enablePlugin('mock_plugin');
        await pluginManager.unloadPlugin('mock_plugin');
        expect(mockPlugin.onDisableCalled, true);
        expect(mockPlugin.onUnloadCalled, true);
      });
    });

    group('enablePlugin/disablePlugin - 启用/禁用', () {
      test('should enable plugin successfully', () async {
        final mockPlugin = MockPlugin();
        discoverer.registerPlugin('mock_plugin', mockPlugin);
        await pluginManager.loadPlugin('mock_plugin');
        await pluginManager.enablePlugin('mock_plugin');
        expect(mockPlugin.onEnableCalled, true);
        expect(pluginManager.getPlugin('mock_plugin')!.isEnabled, true);
      });

      test('should disable plugin successfully', () async {
        final mockPlugin = MockPlugin();
        discoverer.registerPlugin('mock_plugin', mockPlugin);
        await pluginManager.loadPlugin('mock_plugin');
        await pluginManager.enablePlugin('mock_plugin');
        await pluginManager.disablePlugin('mock_plugin');
        expect(mockPlugin.onDisableCalled, true);
        expect(pluginManager.getPlugin('mock_plugin')!.isEnabled, false);
      });

      test('should throw error when enabling non-existent plugin', () async {
        expect(
          () => pluginManager.enablePlugin('non_existent'),
          throwsA(isA<PluginNotFoundException>()),
        );
      });

      test('should not call onEnable twice if already enabled', () async {
        final mockPlugin = MockPlugin();
        discoverer.registerPlugin('mock_plugin', mockPlugin);
        await pluginManager.loadPlugin('mock_plugin');
        await pluginManager.enablePlugin('mock_plugin');
        await pluginManager.enablePlugin('mock_plugin');
        expect(mockPlugin.onEnableCalled, true);
      });
    });

    group('discoverAndLoadPlugins - 发现并加载', () {
      test('should discover and load all plugins', () async {
        discoverer.registerPlugin('mock_plugin', MockPlugin());
        await pluginManager.discoverAndLoadPlugins();
        final plugins = pluginManager.getAllPlugins();
        expect(plugins.length, 1);
        expect(plugins[0].metadata.id, 'mock_plugin');
      });
    });

    group('generateBlocProviders - BLoC 生成', () {
      test('should generate bloc providers', () {
        final blocs = pluginManager.generateBlocProviders();
        expect(blocs, isEmpty);
      });
    });

    group('lifecycle methods - 生命周期方法', () {
      test('should call plugin lifecycle methods in correct order', () async {
        final mockPlugin = MockPlugin();
        discoverer.registerPlugin('mock_plugin', mockPlugin);
        await pluginManager.loadPlugin('mock_plugin');
        final plugin = pluginManager.getPlugin('mock_plugin')!;
        final mock = plugin.plugin as MockPlugin;

        expect(mock.onLoadCalled, true);
        expect(mock.onEnableCalled, false);

        await pluginManager.enablePlugin('mock_plugin');
        expect(mock.onEnableCalled, true);

        await pluginManager.unloadPlugin('mock_plugin');
        expect(mock.onUnloadCalled, true);
      });
    });

    group('dependency resolution - 依赖解析', () {
      test('should throw error when enabling plugin with missing dependency', () async {
        final dependentPlugin = MockPluginWithDependency();
        discoverer.registerPlugin('dependent_plugin', dependentPlugin);
        await pluginManager.loadPlugin('dependent_plugin');

        expect(
          () => pluginManager.enablePlugin('dependent_plugin'),
          throwsA(isA<MissingDependencyException>()),
        );
      });

      test('should auto-enable dependency when enabling dependent plugin', () async {
        final mockPlugin = MockPlugin();
        final dependentPlugin = MockPluginWithDependency();
        discoverer..registerPlugin('mock_plugin', mockPlugin)
        ..registerPlugin('dependent_plugin', dependentPlugin);

        await pluginManager.loadPlugin('mock_plugin');
        await pluginManager.loadPlugin('dependent_plugin');
        await pluginManager.enablePlugin('dependent_plugin');

        expect(mockPlugin.onEnableCalled, true);
        expect(pluginManager.getPlugin('mock_plugin')!.isEnabled, true);
      });
    });

    group('API export/import - API 导出/导入', () {
      test('should register plugin APIs on load', () async {
        final apiPlugin = MockPluginWithAPI();
        discoverer.registerPlugin('api_plugin', apiPlugin);
        await pluginManager.loadPlugin('api_plugin');

        expect(pluginManager.apiRegistry.hasAPI('test_api'), true);
      });

      test('should unregister plugin APIs on unload', () async {
        final apiPlugin = MockPluginWithAPI();
        discoverer.registerPlugin('api_plugin', apiPlugin);
        await pluginManager.loadPlugin('api_plugin');
        await pluginManager.unloadPlugin('api_plugin');

        expect(pluginManager.apiRegistry.hasAPI('test_api'), false);
      });

      test('should throw error when loading plugin with missing API dependency', () async {
        final apiDependentPlugin = MockPluginWithAPIDependency();
        discoverer.registerPlugin('api_dependent_plugin', apiDependentPlugin);

        expect(
          () => pluginManager.loadPlugin('api_dependent_plugin'),
          throwsA(isA<MissingAPIDependencyException>()),
        );
      });

      test('should load plugin with API dependency after API provider', () async {
        final apiPlugin = MockPluginWithAPI();
        final apiDependentPlugin = MockPluginWithAPIDependency();
        discoverer..registerPlugin('api_plugin', apiPlugin)
        ..registerPlugin('api_dependent_plugin', apiDependentPlugin);

        await pluginManager.loadPlugin('api_plugin');
        await pluginManager.loadPlugin('api_dependent_plugin');

        expect(pluginManager.getPlugin('api_dependent_plugin'), isNotNull);
      });
    });

    group('service registration - 服务注册', () {
      test('should register plugin services on load', () async {
        final servicePlugin = MockPluginWithService();
        discoverer.registerPlugin('service_plugin', servicePlugin);
        await pluginManager.loadPlugin('service_plugin');

        expect(pluginManager.serviceRegistry.isRegistered<TestService>(), true);
      });

      test('should unregister plugin services on unload', () async {
        final servicePlugin = MockPluginWithService();
        discoverer.registerPlugin('service_plugin', servicePlugin);
        await pluginManager.loadPlugin('service_plugin');
        await pluginManager.unloadPlugin('service_plugin');

        expect(pluginManager.serviceRegistry.isRegistered<TestService>(), false);
      });
    });

    group('hook registration - Hook 注册', () {
      test('should register plugin hooks on load', () async {
        final hookRegistry = HookRegistry();
        pluginManager = PluginManager(
          commandBus: commandBus,
          discoverer: discoverer,
          hookRegistry: hookRegistry,
        );

        final hookPlugin = MockPluginWithHook();
        discoverer.registerPlugin('hook_plugin', hookPlugin);
        await pluginManager.loadPlugin('hook_plugin');

        expect(hookRegistry.hasHooks('test.hook'), true);
      });

      test('should unregister plugin hooks on unload', () async {
        final hookRegistry = HookRegistry();
        pluginManager = PluginManager(
          commandBus: commandBus,
          discoverer: discoverer,
          hookRegistry: hookRegistry,
        );

        final hookPlugin = MockPluginWithHook();
        discoverer.registerPlugin('hook_plugin', hookPlugin);
        await pluginManager.loadPlugin('hook_plugin');
        await pluginManager.unloadPlugin('hook_plugin');

        expect(hookRegistry.hasHooks('test.hook'), false);
      });

      test('should enable hooks when plugin is enabled', () async {
        final hookRegistry = HookRegistry();
        pluginManager = PluginManager(
          commandBus: commandBus,
          discoverer: discoverer,
          hookRegistry: hookRegistry,
        );

        final hookPlugin = MockPluginWithHook();
        discoverer.registerPlugin('hook_plugin', hookPlugin);
        await pluginManager.loadPlugin('hook_plugin');
        await pluginManager.enablePlugin('hook_plugin');

        final wrappers = hookRegistry.getHookWrappers('test.hook');
        expect(wrappers.isNotEmpty, true);
        expect(wrappers.first.isEnabled, true);
      });

      test('should disable hooks when plugin is disabled', () async {
        final hookRegistry = HookRegistry();
        pluginManager = PluginManager(
          commandBus: commandBus,
          discoverer: discoverer,
          hookRegistry: hookRegistry,
        );

        final hookPlugin = MockPluginWithHook();
        discoverer.registerPlugin('hook_plugin', hookPlugin);
        await pluginManager.loadPlugin('hook_plugin');
        await pluginManager.enablePlugin('hook_plugin');
        await pluginManager.disablePlugin('hook_plugin');

        final wrappers = hookRegistry.getHookWrappers('test.hook', includeDisabled: true);
        expect(wrappers.isNotEmpty, true);
        expect(wrappers.first.isEnabled, false);
      });
    });

    group('version compatibility - 版本兼容性', () {
      test('should throw error when plugin version incompatible', () async {
        final mockPlugin = MockPlugin();
        discoverer.registerPlugin('mock_plugin', mockPlugin);
        pluginManager.appVersion = '0.5.0';

        expect(
          () => pluginManager.loadPlugin('mock_plugin'),
          throwsA(isA<PluginVersionException>()),
        );
      });

      test('should load plugin when version compatible', () async {
        final mockPlugin = MockPlugin();
        discoverer.registerPlugin('mock_plugin', mockPlugin);
        pluginManager.appVersion = '1.0.0';

        await pluginManager.loadPlugin('mock_plugin');
        expect(pluginManager.getPlugin('mock_plugin'), isNotNull);
      });
    });
  });
}
