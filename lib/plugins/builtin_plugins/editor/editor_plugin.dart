import '../../../core/plugin/plugin.dart';

/// 编辑器插件
///
/// 提供节点内容编辑功能
class EditorPlugin extends Plugin {
  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'editor_plugin',
        name: 'Editor Plugin',
        version: '1.0.0',
        description: 'Provides node content editing functionality',
        author: 'Node Graph Notebook',
      );

  @override
  Future<void> onLoad(PluginContext context) async {
    // 注册命令处理器
  }

  @override
  Future<void> onEnable() async {
    // 启用功能
  }

  @override
  Future<void> onDisable() async {
    // 禁用功能
  }

  @override
  Future<void> onUnload() async {
    // 清理资源
  }
}
