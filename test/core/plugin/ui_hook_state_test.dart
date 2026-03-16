import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/plugin/plugin.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/ui_hook.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_point.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_context.dart';

// Mock UI Hook for testing
class MockUIHook extends UIHook {
  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'mock_ui_hook',
        name: 'Mock UI Hook',
        version: '1.0.0',
        description: 'Mock UI hook for testing',
        author: 'Test Author',
        dependencies: [],
        apiDependencies: [],
      );

  @override
  HookPointId get hookPoint => HookPointId.mainToolbar;

  @override
  Widget render(HookContext context) => const SizedBox.shrink();

  bool onInitCalled = false;
  bool onDisposeCalled = false;
  bool onEnableCalled = false;
  bool onDisableCalled = false;
  bool onLoadCalled = false;
  bool onUnloadCalled = false;

  @override
  Future<void> onInit() async {
    onInitCalled = true;
  }

  @override
  Future<void> onDispose() async {
    onDisposeCalled = true;
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
  Future<void> onLoad(PluginContext context) async {
    onLoadCalled = true;
  }

  @override
  Future<void> onUnload() async {
    onUnloadCalled = true;
  }
}

// Create a hook that fails on enable
class FailingHook extends UIHook {
  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'failing_hook',
        name: 'Failing Hook',
        version: '1.0.0',
        description: 'Hook that fails on enable',
        author: 'Test Author',
        dependencies: [],
        apiDependencies: [],
      );

  @override
  HookPointId get hookPoint => HookPointId.mainToolbar;

  @override
  Widget render(HookContext context) => const SizedBox.shrink();

  @override
  Future<void> onInit() async {}

  @override
  Future<void> onDispose() async {}

  @override
  Future<void> onEnable() async {
    throw Exception('Enable failed');
  }

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onUnload() async {}
}

// Mock plugin discoverer for UI Hook
class MockHookDiscoverer extends PluginDiscoverer {
  final Map<String, Plugin> _plugins = {};

  @override
  Future<Plugin?> discoverPlugin(String pluginId) async => _plugins[pluginId];

  @override
  Future<List<String>> discoverAvailablePlugins() async => _plugins.keys.toList();

  void registerPlugin(String id, Plugin plugin) {
    _plugins[id] = plugin;
  }
}

void main() {
  group('UIHook State Synchronization', () {
    late PluginManager pluginManager;
    late CommandBus commandBus;
    late MockHookDiscoverer discoverer;

    setUp(() {
      commandBus = CommandBus();
      discoverer = MockHookDiscoverer();
      discoverer.registerPlugin('mock_ui_hook', MockUIHook());
      pluginManager = PluginManager(
        commandBus: commandBus,
        discoverer: discoverer,
      );
    });

    tearDown(() {
      commandBus.dispose();
    });

    test('should synchronize UIHook state with PluginLifecycleManager', () async {
      await pluginManager.loadPlugin('mock_ui_hook');
      final wrapper = pluginManager.getPlugin('mock_ui_hook');
      expect(wrapper, isNotNull);
      
      final hook = wrapper!.plugin as MockUIHook;
      
      // After loading, the hook's state should be loaded
      expect(hook.state, PluginState.loaded);
      expect(wrapper.state, PluginState.loaded);
      expect(wrapper.state, hook.state);
      
      // Enable the hook
      await pluginManager.enablePlugin('mock_ui_hook');
      
      // After enabling, the hook's state should be enabled
      expect(hook.state, PluginState.enabled);
      expect(wrapper.state, PluginState.enabled);
      expect(wrapper.state, hook.state);
      expect(hook.onEnableCalled, true);
      
      // Disable the hook
      await pluginManager.disablePlugin('mock_ui_hook');
      
      // After disabling, the hook's state should be disabled
      expect(hook.state, PluginState.disabled);
      expect(wrapper.state, PluginState.disabled);
      expect(wrapper.state, hook.state);
      expect(hook.onDisableCalled, true);
    });

    test('should maintain state consistency after enable failure', () async {
      discoverer.registerPlugin('failing_hook', FailingHook());
      await pluginManager.loadPlugin('failing_hook');
      
      final wrapper = pluginManager.getPlugin('failing_hook');
      final hook = wrapper!.plugin as FailingHook;
      
      // Try to enable the hook (should fail)
      try {
        await pluginManager.enablePlugin('failing_hook');
        fail('Expected PluginEnableException to be thrown');
      } catch (e) {
        expect(e, isA<PluginEnableException>());
      }
      
      // After enable failure, the hook's state should be enableFailed
      expect(hook.state, PluginState.enableFailed);
      expect(wrapper.state, PluginState.enableFailed);
      expect(wrapper.state, hook.state);
    });

    test('should correctly report isEnabled based on state', () async {
      await pluginManager.loadPlugin('mock_ui_hook');
      final wrapper = pluginManager.getPlugin('mock_ui_hook');
      final hook = wrapper!.plugin as MockUIHook;
      
      // Initially, hook is loaded but not enabled
      expect(hook.isEnabled, false);
      expect(wrapper.isEnabled, false);
      
      // Enable the hook
      await pluginManager.enablePlugin('mock_ui_hook');
      
      // After enabling, hook should be enabled
      expect(hook.isEnabled, true);
      expect(wrapper.isEnabled, true);
      
      // Disable the hook
      await pluginManager.disablePlugin('mock_ui_hook');
      
      // After disabling, hook should not be enabled
      expect(hook.isEnabled, false);
      expect(wrapper.isEnabled, false);
    });
  });
}
