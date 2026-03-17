import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/plugin/plugin.dart';
import 'package:node_graph_notebook/plugins/editor/editor_plugin.dart';

void main() {
  group('EditorPlugin', () {
    late EditorPlugin editorPlugin;

    setUp(() {
      editorPlugin = EditorPlugin();
    });

    test('should have correct metadata', () {
      expect(editorPlugin.metadata.id, 'editor_plugin');
      expect(editorPlugin.metadata.name, 'Editor Plugin');
      expect(editorPlugin.metadata.version, '1.0.0');
      expect(editorPlugin.metadata.description, 'Provides node content editing functionality');
      expect(editorPlugin.metadata.author, 'Node Graph Notebook');
    });

    test('should start in unloaded state', () {
      expect(editorPlugin.state, PluginState.unloaded);
    });

    test('should allow state changes', () {
      editorPlugin.state = PluginState.loaded;
      expect(editorPlugin.state, PluginState.loaded);

      editorPlugin.state = PluginState.enabled;
      expect(editorPlugin.state, PluginState.enabled);

      editorPlugin.state = PluginState.disabled;
      expect(editorPlugin.state, PluginState.disabled);
    });

    test('onLoad should complete without errors', () async {
      final mockContext = MockPluginContext();
      await expectLater(
        editorPlugin.onLoad(mockContext),
        completes,
      );
    });

    test('onEnable should complete without errors', () async {
      await expectLater(
        editorPlugin.onEnable(),
        completes,
      );
    });

    test('onDisable should complete without errors', () async {
      await expectLater(
        editorPlugin.onDisable(),
        completes,
      );
    });

    test('onUnload should complete without errors', () async {
      await expectLater(
        editorPlugin.onUnload(),
        completes,
      );
    });

    test('should handle full lifecycle', () async {
      final mockContext = MockPluginContext();

      expect(editorPlugin.state, PluginState.unloaded);

      await editorPlugin.onLoad(mockContext);
      editorPlugin.state = PluginState.loaded;
      expect(editorPlugin.state, PluginState.loaded);

      editorPlugin.state = PluginState.enabled;
      await editorPlugin.onEnable();
      expect(editorPlugin.state, PluginState.enabled);

      editorPlugin.state = PluginState.disabled;
      await editorPlugin.onDisable();
      expect(editorPlugin.state, PluginState.disabled);

      await editorPlugin.onUnload();
      editorPlugin.state = PluginState.unloaded;
      expect(editorPlugin.state, PluginState.unloaded);
    });
  });
}

class MockPluginContext extends PluginContext {
  MockPluginContext() : super(
    pluginId: 'test_plugin',
    commandBus: MockCommandBus(),
    logger: MockPluginLogger(),
  );
}

class MockCommandBus extends CommandBus {
  @override
  void dispose() {}
}

class MockPluginLogger extends PluginLogger {
  MockPluginLogger() : super('test_plugin');

  @override
  void debug(String message) {}

  @override
  void info(String message) {}

  @override
  void warning(String message) {}

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
}
