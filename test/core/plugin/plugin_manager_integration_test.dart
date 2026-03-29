import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/commands/models/command.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/commands/models/command_handler.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';
import 'package:node_graph_notebook/core/plugin/api/api_registry.dart';
import 'package:node_graph_notebook/core/plugin/plugin.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_base.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_context.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_metadata.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_priority.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_registry.dart';

class TestPluginA extends Plugin {
  TestPluginA();

  PluginState _state = PluginState.unloaded;
  List<String> lifecycleCalls = [];

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'plugin_a',
        name: 'Plugin A',
        version: '1.0.0',
        description: 'Test plugin A',
        author: 'Test',
        dependencies: [],
        apiDependencies: [],
      );

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  Future<void> onLoad(PluginContext context) async {
    lifecycleCalls.add('onLoad');
  }

  @override
  Future<void> onEnable() async {
    lifecycleCalls.add('onEnable');
  }

  @override
  Future<void> onDisable() async {
    lifecycleCalls.add('onDisable');
  }

  @override
  Future<void> onUnload() async {
    lifecycleCalls.add('onUnload');
  }
}

class TestPluginB extends Plugin {
  TestPluginB();

  PluginState _state = PluginState.unloaded;
  List<String> lifecycleCalls = [];

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'plugin_b',
        name: 'Plugin B',
        version: '1.0.0',
        description: 'Test plugin B that depends on A',
        author: 'Test',
        dependencies: ['plugin_a'],
        apiDependencies: [],
      );

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  Future<void> onLoad(PluginContext context) async {
    lifecycleCalls.add('onLoad');
  }

  @override
  Future<void> onEnable() async {
    lifecycleCalls.add('onEnable');
  }

  @override
  Future<void> onDisable() async {
    lifecycleCalls.add('onDisable');
  }

  @override
  Future<void> onUnload() async {
    lifecycleCalls.add('onUnload');
  }
}

class TestPluginC extends Plugin {
  TestPluginC();

  PluginState _state = PluginState.unloaded;

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'plugin_c',
        name: 'Plugin C',
        version: '1.0.0',
        description: 'Test plugin C with circular dependency',
        author: 'Test',
        dependencies: ['plugin_d'],
        apiDependencies: [],
      );

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

class TestPluginD extends Plugin {
  TestPluginD();

  PluginState _state = PluginState.unloaded;

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'plugin_d',
        name: 'Plugin D',
        version: '1.0.0',
        description: 'Test plugin D with circular dependency',
        author: 'Test',
        dependencies: ['plugin_c'],
        apiDependencies: [],
      );

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

class TestPluginWithService extends Plugin {
  TestPluginWithService();

  PluginState _state = PluginState.unloaded;

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'service_plugin',
        name: 'Service Plugin',
        version: '1.0.0',
        description: 'Plugin that provides a service',
        author: 'Test',
        dependencies: [],
        apiDependencies: [],
      );

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  List<ServiceBinding> registerServices() => [
        TestIntegrationServiceBinding(),
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

class TestIntegrationService {
  TestIntegrationService(this.name);
  final String name;
}

class TestIntegrationServiceBinding extends ServiceBinding<TestIntegrationService> {
  @override
  TestIntegrationService createService(ServiceResolver resolver) =>
      TestIntegrationService('integration_test_service');
}

class TestPluginWithCommandHandler extends Plugin {
  TestPluginWithCommandHandler();

  PluginState _state = PluginState.unloaded;
  bool handlerRegistered = false;

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'command_plugin',
        name: 'Command Plugin',
        version: '1.0.0',
        description: 'Plugin that provides command handlers',
        author: 'Test',
        dependencies: [],
        apiDependencies: [],
      );

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  Future<void> onLoad(PluginContext context) async {
    context.commandBus.registerHandler<TestIntegrationCommand>(
      TestIntegrationCommandHandler(),
      TestIntegrationCommand,
    );
    handlerRegistered = true;
  }

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onUnload() async {}
}

class TestIntegrationCommand extends Command<String> {
  @override
  String get name => 'TestIntegrationCommand';

  @override
  String get description => 'Test integration command';

  @override
  Future<CommandResult<String>> execute(CommandContext context) async =>
      CommandResult.success('test_result');
}

class TestIntegrationCommandHandler extends CommandHandler<TestIntegrationCommand> {
  @override
  Future<CommandResult<String>> execute(
    TestIntegrationCommand command,
    CommandContext context,
  ) async =>
      CommandResult.success('handled');
}

class TestPluginWithHook extends Plugin {
  TestPluginWithHook();

  PluginState _state = PluginState.unloaded;

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'hook_plugin',
        name: 'Hook Plugin',
        version: '1.0.0',
        description: 'Plugin that provides hooks',
        author: 'Test',
        dependencies: [],
        apiDependencies: [],
      );

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  List<HookFactory> registerHooks() => [
        TestIntegrationHook.new,
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

class TestIntegrationHook extends UIHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
        id: 'test_integration_hook',
        name: 'Test Integration Hook',
        version: '1.0.0',
      );

  @override
  String get hookPointId => 'test.integration';

  @override
  HookPriority get priority => HookPriority.medium;

  @override
  Widget render(HookContext context) => const SizedBox.shrink();
}

class TestPluginWithAPI extends Plugin {
  TestPluginWithAPI();

  PluginState _state = PluginState.unloaded;

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'api_provider_plugin',
        name: 'API Provider Plugin',
        version: '1.0.0',
        description: 'Plugin that exports APIs',
        author: 'Test',
        dependencies: [],
        apiDependencies: [],
      );

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  Map<String, dynamic> exportAPIs() => {
        'test_api': TestIntegrationAPI(),
      };

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onUnload() async {}
}

class TestIntegrationAPI {
  String doSomething() => 'api_result';
}

class TestPluginWithAPIDependency extends Plugin {
  TestPluginWithAPIDependency();

  PluginState _state = PluginState.unloaded;

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'api_consumer_plugin',
        name: 'API Consumer Plugin',
        version: '1.0.0',
        description: 'Plugin that depends on API',
        author: 'Test',
        dependencies: [],
        apiDependencies: [APIDependency(apiName: 'test_api')],
      );

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
  group('PluginManager Integration Tests', () {
    late PluginManager pluginManager;
    late CommandBus commandBus;
    late MockPluginDiscoverer discoverer;
    late HookRegistry hookRegistry;
    late ServiceRegistry serviceRegistry;

    setUp(() {
      commandBus = CommandBus();
      hookRegistry = HookRegistry();
      serviceRegistry = ServiceRegistry(coreDependencies: {});
      discoverer = MockPluginDiscoverer();
      pluginManager = PluginManager(
        commandBus: commandBus,
        discoverer: discoverer,
        hookRegistry: hookRegistry,
        serviceRegistry: serviceRegistry,
      );
    });

    tearDown(() {
      commandBus.dispose();
    });

    group('Plugin Lifecycle Integration', () {
      test('should call lifecycle methods in correct order', () async {
        final pluginA = TestPluginA();
        discoverer.registerPlugin('plugin_a', pluginA);

        await pluginManager.loadPlugin('plugin_a');
        expect(pluginA.lifecycleCalls, ['onLoad']);

        await pluginManager.enablePlugin('plugin_a');
        expect(pluginA.lifecycleCalls, ['onLoad', 'onEnable']);

        await pluginManager.disablePlugin('plugin_a');
        expect(pluginA.lifecycleCalls, ['onLoad', 'onEnable', 'onDisable']);

        await pluginManager.unloadPlugin('plugin_a');
        expect(pluginA.lifecycleCalls, ['onLoad', 'onEnable', 'onDisable', 'onUnload']);
      });

      test('should handle multiple plugins with dependencies', () async {
        final pluginA = TestPluginA();
        final pluginB = TestPluginB();
        discoverer..registerPlugin('plugin_a', pluginA)
        ..registerPlugin('plugin_b', pluginB);

        await pluginManager.loadPlugin('plugin_a');
        await pluginManager.loadPlugin('plugin_b');

        await pluginManager.enablePlugin('plugin_b');

        expect(pluginA.lifecycleCalls, contains('onEnable'));
        expect(pluginB.lifecycleCalls, contains('onEnable'));
      });
    });

    group('Service Registration Integration', () {
      test('should register and unregister services correctly', () async {
        final servicePlugin = TestPluginWithService();
        discoverer.registerPlugin('service_plugin', servicePlugin);

        await pluginManager.loadPlugin('service_plugin');
        expect(serviceRegistry.isRegistered<TestIntegrationService>(), true);

        await pluginManager.unloadPlugin('service_plugin');
        expect(serviceRegistry.isRegistered<TestIntegrationService>(), false);
      });

      test('should allow plugins to access services from other plugins', () async {
        final servicePlugin = TestPluginWithService();
        discoverer.registerPlugin('service_plugin', servicePlugin);

        await pluginManager.loadPlugin('service_plugin');

        final service = serviceRegistry.getServiceDirect<TestIntegrationService>();
        expect(service, isNotNull);
        expect(service.name, 'integration_test_service');
      });
    });

    group('Command Handler Registration Integration', () {
      test('should register command handlers on plugin load', () async {
        final commandPlugin = TestPluginWithCommandHandler();
        discoverer.registerPlugin('command_plugin', commandPlugin);

        await pluginManager.loadPlugin('command_plugin');
        expect(commandPlugin.handlerRegistered, true);
      });
    });

    group('Hook Registration Integration', () {
      test('should register and unregister hooks correctly', () async {
        final hookPlugin = TestPluginWithHook();
        discoverer.registerPlugin('hook_plugin', hookPlugin);

        await pluginManager.loadPlugin('hook_plugin');
        expect(hookRegistry.hasHooks('test.integration'), true);

        await pluginManager.unloadPlugin('hook_plugin');
        expect(hookRegistry.hasHooks('test.integration'), false);
      });

      test('should enable and disable hooks with plugin', () async {
        final hookPlugin = TestPluginWithHook();
        discoverer.registerPlugin('hook_plugin', hookPlugin);

        await pluginManager.loadPlugin('hook_plugin');
        await pluginManager.enablePlugin('hook_plugin');

        var wrappers = hookRegistry.getHookWrappers('test.integration');
        expect(wrappers.isNotEmpty, true);
        expect(wrappers.first.isEnabled, true);

        await pluginManager.disablePlugin('hook_plugin');

        wrappers = hookRegistry.getHookWrappers('test.integration', includeDisabled: true);
        expect(wrappers.first.isEnabled, false);
      });
    });

    group('API Export/Import Integration', () {
      test('should export and import APIs correctly', () async {
        final apiPlugin = TestPluginWithAPI();
        discoverer.registerPlugin('api_provider_plugin', apiPlugin);

        await pluginManager.loadPlugin('api_provider_plugin');
        expect(pluginManager.apiRegistry.hasAPI('test_api'), true);

        await pluginManager.unloadPlugin('api_provider_plugin');
        expect(pluginManager.apiRegistry.hasAPI('test_api'), false);
      });

      test('should allow plugin to depend on API from another plugin', () async {
        final apiPlugin = TestPluginWithAPI();
        final consumerPlugin = TestPluginWithAPIDependency();
        discoverer..registerPlugin('api_provider_plugin', apiPlugin)
        ..registerPlugin('api_consumer_plugin', consumerPlugin);

        await pluginManager.loadPlugin('api_provider_plugin');
        await pluginManager.loadPlugin('api_consumer_plugin');

        expect(pluginManager.getPlugin('api_consumer_plugin'), isNotNull);
      });

      test('should fail to load plugin when API dependency is missing', () async {
        final consumerPlugin = TestPluginWithAPIDependency();
        discoverer.registerPlugin('api_consumer_plugin', consumerPlugin);

        expect(
          () => pluginManager.loadPlugin('api_consumer_plugin'),
          throwsA(isA<MissingAPIDependencyException>()),
        );
      });
    });

    group('Error Handling Integration', () {
      test('should handle plugin load failure gracefully', () async {
        expect(
          () => pluginManager.loadPlugin('non_existent_plugin'),
          throwsA(isA<PluginNotFoundException>()),
        );

        expect(pluginManager.getPlugin('non_existent_plugin'), isNull);
      });

      test('should handle duplicate plugin load', () async {
        final pluginA = TestPluginA();
        discoverer.registerPlugin('plugin_a', pluginA);

        await pluginManager.loadPlugin('plugin_a');

        expect(
          () => pluginManager.loadPlugin('plugin_a'),
          throwsA(isA<PluginAlreadyExistsException>()),
        );
      });

      test('should handle missing dependency on enable', () async {
        final pluginB = TestPluginB();
        discoverer.registerPlugin('plugin_b', pluginB);

        await pluginManager.loadPlugin('plugin_b');

        expect(
          () => pluginManager.enablePlugin('plugin_b'),
          throwsA(isA<MissingDependencyException>()),
        );
      });
    });

    group('Event Bus Integration', () {
      test('should publish plugin lifecycle events', () async {
        final pluginA = TestPluginA();
        discoverer.registerPlugin('plugin_a', pluginA);

        final events = <AppEvent>[];

        // 订阅 CommandBus 的事件流
        final subscription = commandBus.eventStream.listen((event) {
          events.add(event);
        });

        await pluginManager.loadPlugin('plugin_a');
        await pluginManager.enablePlugin('plugin_a');

        await Future.delayed(const Duration(milliseconds: 100));

        await subscription.cancel();

        expect(events.isNotEmpty, true);
      });
    });

    group('Multiple Plugin Interaction', () {
      test('should handle multiple plugins loading and unloading', () async {
        final pluginA = TestPluginA();
        final servicePlugin = TestPluginWithService();
        final hookPlugin = TestPluginWithHook();

        discoverer..registerPlugin('plugin_a', pluginA)
        ..registerPlugin('service_plugin', servicePlugin)
        ..registerPlugin('hook_plugin', hookPlugin);

        await pluginManager.loadPlugin('plugin_a');
        await pluginManager.loadPlugin('service_plugin');
        await pluginManager.loadPlugin('hook_plugin');

        expect(pluginManager.getAllPlugins().length, 3);
        expect(serviceRegistry.isRegistered<TestIntegrationService>(), true);
        expect(hookRegistry.hasHooks('test.integration'), true);

        await pluginManager.unloadPlugin('hook_plugin');
        expect(pluginManager.getAllPlugins().length, 2);
        expect(hookRegistry.hasHooks('test.integration'), false);

        await pluginManager.unloadPlugin('service_plugin');
        expect(serviceRegistry.isRegistered<TestIntegrationService>(), false);

        await pluginManager.unloadPlugin('plugin_a');
        expect(pluginManager.getAllPlugins().isEmpty, true);
      });
    });
  });
}
