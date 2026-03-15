import '../../../core/plugin/plugin.dart';
import '../../../core/repositories/repositories.dart';
import 'command/graph_commands.dart';
import 'command/node_commands.dart';
import 'handler/connect_nodes_handler.dart';
import 'handler/disconnect_nodes_handler.dart';
import 'handler/move_node_handler.dart';
import 'handler/resize_node_handler.dart';
import 'handler/update_node_position_handler.dart';

/// 图形插件
///
/// 提供图形可视化和操作功能
class GraphPlugin extends Plugin {
  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'graph_plugin',
        name: 'Graph Plugin',
        version: '1.0.0',
        description: 'Provides graph visualization and manipulation',
        author: 'Node Graph Notebook',
      );

  @override
  Future<void> onLoad(PluginContext context) async {
    // 获取服务实例
    final nodeRepository = context.read<NodeRepository>();
    final graphRepository = context.read<GraphRepository>();
    // 注意：GraphService 和 NodeService 可能需要通过依赖注入获取

    // 注册命令处理器
    context.commandBus.registerHandler(
      ConnectNodesHandler(nodeRepository),
      ConnectNodesCommand,
    );
    context.commandBus.registerHandler(
      DisconnectNodesHandler(nodeRepository),
      DisconnectNodesCommand,
    );
    context.commandBus.registerHandler(
      MoveNodeHandler(nodeRepository),
      MoveNodeCommand,
    );
    context.commandBus.registerHandler(
      ResizeNodeHandler(nodeRepository),
      ResizeNodeCommand,
    );
    context.commandBus.registerHandler(
      UpdateNodePositionHandler(graphRepository),
      UpdateNodePositionCommand,
    );
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
