import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/plugin/plugin.dart';

// Mock plugin class
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

// Mock plugin discoverer
class MockPluginDiscoverer extends PluginDiscoverer {
  final Map<String, Plugin> _plugins = {
    'mock_plugin': MockPlugin(),
  };

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

    test('should load plugin successfully', () async {
      await pluginManager.loadPlugin('mock_plugin');
      final plugin = pluginManager.getPlugin('mock_plugin');
      expect(plugin, isNotNull);
      expect(plugin!.metadata.id, 'mock_plugin');
    });

    test('should throw error when loading non-existent plugin', () async {
      expect(() => pluginManager.loadPlugin('non_existent'), throwsA(isA<PluginNotFoundException>()));
    });

    test('should throw error when loading already loaded plugin', () async {
      await pluginManager.loadPlugin('mock_plugin');
      expect(() => pluginManager.loadPlugin('mock_plugin'), throwsA(isA<PluginAlreadyExistsException>()));
    });

    test('should unload plugin successfully', () async {
      await pluginManager.loadPlugin('mock_plugin');
      await pluginManager.unloadPlugin('mock_plugin');
      final plugin = pluginManager.getPlugin('mock_plugin');
      expect(plugin, null);
    });

    test('should discover and load plugins', () async {
      await pluginManager.discoverAndLoadPlugins();
      final plugins = pluginManager.getAllPlugins();
      expect(plugins.length, 1);
      expect(plugins[0].metadata.id, 'mock_plugin');
    });

    test('should generate bloc providers', () {
      final blocs = pluginManager.generateBlocProviders();
      expect(blocs, isEmpty); // Mock plugin doesn't register any blocs
    });

    test('should call plugin lifecycle methods', () async {
      await pluginManager.loadPlugin('mock_plugin');
      final plugin = pluginManager.getPlugin('mock_plugin')!;
      final mockPlugin = plugin.plugin as MockPlugin;
      
      expect(mockPlugin.onLoadCalled, true);
      expect(mockPlugin.onEnableCalled, false);
      
      await pluginManager.enablePlugin('mock_plugin');
      expect(mockPlugin.onEnableCalled, true);
      
      await pluginManager.unloadPlugin('mock_plugin');
      expect(mockPlugin.onUnloadCalled, true);
    });
  });
}
