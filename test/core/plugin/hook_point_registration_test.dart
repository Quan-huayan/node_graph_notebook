import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/plugin/plugin.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_point_registry.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_registry.dart';

void main() {
  group('Plugin Hook Point Registration', () {
    late PluginManager pluginManager;
    late HookRegistry hookRegistry;
    late ServiceRegistry serviceRegistry;
    late CommandBus commandBus;

    setUp(() {
      commandBus = CommandBus();
      hookRegistry = HookRegistry();
      serviceRegistry = ServiceRegistry();

      pluginManager = PluginManager(
        commandBus: commandBus,
        hookRegistry: hookRegistry,
        serviceRegistry: serviceRegistry,
      );
    });

    tearDown(() async {
      await pluginManager.dispose();
    });

    test('Plugin should be able to register custom hook points', () async {
      final testPlugin = TestPluginWithHookPoints();
      pluginManager.discoverer.registerFactory(testPlugin.metadata.id, () => testPlugin);

      await pluginManager.loadPlugin(testPlugin.metadata.id);

      final hookPoint = hookRegistry.getHookPoint('test_plugin.custom_hook');
      expect(hookPoint, isNotNull);
      expect(hookPoint!.id, 'test_plugin.custom_hook');
      expect(hookPoint.name, 'Custom Hook');
      expect(hookPoint.category, 'custom');
    });

    test('Plugin hook points should be unregistered on unload', () async {
      final testPlugin = TestPluginWithHookPoints();
      pluginManager.discoverer.registerFactory(testPlugin.metadata.id, () => testPlugin);

      await pluginManager.loadPlugin(testPlugin.metadata.id);
      expect(hookRegistry.hasHookPoint('test_plugin.custom_hook'), isTrue);

      await pluginManager.unloadPlugin(testPlugin.metadata.id);
      expect(hookRegistry.hasHookPoint('test_plugin.custom_hook'), isFalse);
    });

    test('Plugin without hook points should work normally', () async {
      final testPlugin = TestPluginWithoutHookPoints();
      pluginManager.discoverer.registerFactory(testPlugin.metadata.id, () => testPlugin);

      await pluginManager.loadPlugin(testPlugin.metadata.id);
      expect(pluginManager.getPlugin(testPlugin.metadata.id), isNotNull);
    });

    test('Multiple plugins can register hook points', () async {
      final plugin1 = TestPluginWithHookPoints();
      final plugin2 = AnotherTestPluginWithHookPoints();
      pluginManager.discoverer.registerFactory(plugin1.metadata.id, () => plugin1);
      pluginManager.discoverer.registerFactory(plugin2.metadata.id, () => plugin2);

      await pluginManager.loadPlugin(plugin1.metadata.id);
      await pluginManager.loadPlugin(plugin2.metadata.id);

      expect(hookRegistry.hasHookPoint('test_plugin.custom_hook'), isTrue);
      expect(hookRegistry.hasHookPoint('another_plugin.another_hook'), isTrue);
    });
  });
}

class TestPluginWithHookPoints extends Plugin {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'test_plugin',
    name: 'Test Plugin',
    version: '1.0.0',
  );

  @override
  List<HookPointDefinition> registerHookPoints() => [
    const HookPointDefinition(
      id: 'test_plugin.custom_hook',
      name: 'Custom Hook',
      description: 'A custom hook point for testing',
      category: 'custom',
    ),
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

class TestPluginWithoutHookPoints extends Plugin {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'test_plugin_no_hooks',
    name: 'Test Plugin Without Hooks',
    version: '1.0.0',
  );

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onUnload() async {}
}

class AnotherTestPluginWithHookPoints extends Plugin {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'another_plugin',
    name: 'Another Test Plugin',
    version: '1.0.0',
  );

  @override
  List<HookPointDefinition> registerHookPoints() => [
    const HookPointDefinition(
      id: 'another_plugin.another_hook',
      name: 'Another Hook',
      description: 'Another custom hook point for testing',
      category: 'custom',
    ),
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
