import '../../../core/plugin/plugin.dart';
import 'service/layout_service_bindings.dart';
import 'handler/apply_layout_handler.dart';
import 'command/layout_commands.dart';
import 'service/layout_service.dart';
import '../graph/service/graph_service.dart';

/// Layout 插件
///
/// 提供布局相关功能：应用布局、批量移动节点等
class LayoutPlugin extends Plugin {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'layout',
        name: 'Layout',
        version: '1.0.0',
        description: 'Graph layout and node positioning',
        author: 'Node Graph Notebook',
        enabledByDefault: true,
      );

  @override
  List<ServiceBinding> registerServices() => [
        LayoutServiceBinding(),
      ];

  @override
  Future<void> onLoad(PluginContext context) async {
    // 注册命令处理器
    _registerCommandHandlers(context);
  }

  @override
  Future<void> onEnable() async {
    // 启用时的逻辑
  }

  @override
  Future<void> onDisable() async {
    // 禁用时的逻辑
  }

  @override
  Future<void> onUnload() async {
    // 卸载时的逻辑
  }

  /// 注册命令处理器
  void _registerCommandHandlers(PluginContext context) {
    final commandBus = context.commandBus;
    final graphService = context.read<GraphService>();
    final layoutService = context.read<LayoutService>();

    // 注册布局命令处理器
    commandBus.registerHandler<ApplyLayoutCommand>(
      ApplyLayoutHandler(graphService, layoutService, commandBus),
      ApplyLayoutCommand,
    );
  }
}
