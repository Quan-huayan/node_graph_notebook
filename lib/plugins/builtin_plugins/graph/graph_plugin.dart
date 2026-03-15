import '../../../core/plugin/plugin.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'service/graph_service_bindings.dart';
import 'bloc/graph_bloc.dart';
import 'bloc/node_bloc.dart';
import 'bloc/graph_event.dart';
import 'bloc/node_event.dart';
import 'handler/create_node_handler.dart';
import 'handler/update_node_handler.dart';
import 'handler/delete_node_handler.dart';
import 'handler/connect_nodes_handler.dart';
import 'handler/disconnect_nodes_handler.dart';
import 'handler/move_node_handler.dart';
import 'handler/resize_node_handler.dart';
import 'handler/load_graph_handler.dart';
import 'handler/create_graph_handler.dart';
import 'handler/update_graph_handler.dart';
import 'handler/rename_graph_handler.dart';
import 'handler/add_node_to_graph_handler.dart';
import 'handler/remove_node_from_graph_handler.dart';
import 'handler/update_node_position_handler.dart';
import 'command/node_commands.dart';
import 'command/graph_commands.dart';
import '../../../core/repositories/node_repository.dart';
import '../../../core/repositories/graph_repository.dart';
import '../../../core/events/app_events.dart';
import '../../../core/commands/command_bus.dart';
import 'service/node_service.dart';
import 'service/graph_service.dart';

/// Graph 插件
///
/// 提供图相关功能：节点管理、图管理、连接管理等
class GraphPlugin extends Plugin {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'graph',
        name: 'Graph',
        version: '1.0.0',
        description: 'Graph management and node operations',
        author: 'Node Graph Notebook',
        enabledByDefault: true,
      );

  @override
  List<ServiceBinding> registerServices() => [
        NodeServiceBinding(),
        GraphServiceBinding(),
      ];

  @override
  List<BlocProvider> registerBlocs() => [
        BlocProvider<NodeBloc>(
          create: (ctx) => NodeBloc(
            commandBus: ctx.read<CommandBus>(),
            nodeRepository: ctx.read<NodeRepository>(),
            eventBus: ctx.read<AppEventBus>(),
          )..add(const NodeLoadEvent()),
        ),
        BlocProvider<GraphBloc>(
          create: (ctx) => GraphBloc(
            commandBus: ctx.read<CommandBus>(),
            graphRepository: ctx.read<GraphRepository>(),
            nodeRepository: ctx.read<NodeRepository>(),
            eventBus: ctx.read<AppEventBus>(),
          )..add(const GraphInitializeEvent()),
        ),
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
    final nodeRepository = context.read<NodeRepository>();
    final graphRepository = context.read<GraphRepository>();
    final nodeService = context.read<NodeService>();
    final graphService = context.read<GraphService>();

    // 注册节点命令处理器
    commandBus.registerHandler<CreateNodeCommand>(
      CreateNodeHandler(nodeService),
      CreateNodeCommand,
    );
    commandBus.registerHandler<UpdateNodeCommand>(
      UpdateNodeHandler(nodeService),
      UpdateNodeCommand,
    );
    commandBus.registerHandler<DeleteNodeCommand>(
      DeleteNodeHandler(nodeService),
      DeleteNodeCommand,
    );
    commandBus.registerHandler<ConnectNodesCommand>(
      ConnectNodesHandler(nodeRepository),
      ConnectNodesCommand,
    );
    commandBus.registerHandler<DisconnectNodesCommand>(
      DisconnectNodesHandler(nodeRepository),
      DisconnectNodesCommand,
    );
    commandBus.registerHandler<MoveNodeCommand>(
      MoveNodeHandler(nodeRepository),
      MoveNodeCommand,
    );
    commandBus.registerHandler<ResizeNodeCommand>(
      ResizeNodeHandler(nodeRepository),
      ResizeNodeCommand,
    );

    // 注册图命令处理器
    commandBus.registerHandler<LoadGraphCommand>(
      LoadGraphHandler(graphService),
      LoadGraphCommand,
    );
    commandBus.registerHandler<CreateGraphCommand>(
      CreateGraphHandler(graphService),
      CreateGraphCommand,
    );
    commandBus.registerHandler<UpdateGraphCommand>(
      UpdateGraphHandler(graphService),
      UpdateGraphCommand,
    );
    commandBus.registerHandler<RenameGraphCommand>(
      RenameGraphHandler(graphService),
      RenameGraphCommand,
    );
    commandBus.registerHandler<AddNodeToGraphCommand>(
      AddNodeToGraphHandler(graphService),
      AddNodeToGraphCommand,
    );
    commandBus.registerHandler<RemoveNodeFromGraphCommand>(
      RemoveNodeFromGraphHandler(graphService),
      RemoveNodeFromGraphCommand,
    );
    commandBus.registerHandler<UpdateNodePositionCommand>(
      UpdateNodePositionHandler(graphRepository),
      UpdateNodePositionCommand,
    );
  }
}
