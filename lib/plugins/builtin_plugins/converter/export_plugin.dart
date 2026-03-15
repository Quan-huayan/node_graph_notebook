import '../../../core/plugin/plugin.dart';

/// 导出插件
/// 支持将图导出为各种格式
class ExportPlugin extends Plugin {
  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'export',
        name: 'Export',
        version: '1.0.0',
        description: 'Export graph to various formats (JSON, PNG, Markdown)',
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
    // 清理
  }
}
