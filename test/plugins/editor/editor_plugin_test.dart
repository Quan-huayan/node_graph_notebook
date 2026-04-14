import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/cqrs/commands/command_bus.dart';
import 'package:node_graph_notebook/core/plugin/plugin.dart';
import 'package:node_graph_notebook/plugins/editor/editor_plugin.dart';

void main() {
  group('EditorPlugin', () {
    late EditorPlugin editorPlugin;

    setUp(() {
      editorPlugin = EditorPlugin();
    });

    test('应该具有正确的元数据', () {
      expect(editorPlugin.metadata.id, 'editor_plugin');
      expect(editorPlugin.metadata.name, 'Editor Plugin');
      expect(editorPlugin.metadata.version, '1.0.0');
      expect(editorPlugin.metadata.description, 'Provides node content editing functionality');
      expect(editorPlugin.metadata.author, 'Node Graph Notebook');
    });

    test('初始状态应该为未加载', () {
      expect(editorPlugin.state, PluginState.unloaded);
    });

    test('应该允许状态变更', () {
      editorPlugin.state = PluginState.loaded;
      expect(editorPlugin.state, PluginState.loaded);

      editorPlugin.state = PluginState.enabled;
      expect(editorPlugin.state, PluginState.enabled);

      editorPlugin.state = PluginState.disabled;
      expect(editorPlugin.state, PluginState.disabled);
    });

    test('onLoad 应该无错误完成', () async {
      final mockContext = MockPluginContext();
      await expectLater(
        editorPlugin.onLoad(mockContext),
        completes,
      );
    });

    test('onEnable 应该无错误完成', () async {
      await expectLater(
        editorPlugin.onEnable(),
        completes,
      );
    });

    test('onDisable 应该无错误完成', () async {
      await expectLater(
        editorPlugin.onDisable(),
        completes,
      );
    });

    test('onUnload 应该无错误完成', () async {
      await expectLater(
        editorPlugin.onUnload(),
        completes,
      );
    });

    test('应该处理完整的生命周期', () async {
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
