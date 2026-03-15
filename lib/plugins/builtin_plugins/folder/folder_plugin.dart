import '../../../core/plugin/plugin.dart';

/// 文件夹插件
///
/// 提供文件夹管理功能
class FolderPlugin extends Plugin {
  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'folder_plugin',
        name: 'Folder Plugin',
        version: '1.0.0',
        description: 'Provides folder management functionality',
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
