import '../../../core/plugin/plugin.dart';

/// 侧边栏节点插件
///
/// 提供侧边栏节点管理功能
class SidebarNodePlugin extends Plugin {
  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'sidebar_node_plugin',
        name: 'Sidebar Node Plugin',
        version: '1.0.0',
        description: 'Provides sidebar node management functionality',
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
