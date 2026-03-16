import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vector_math/vector_math.dart';
import '../../../core/commands/command_bus.dart';
import '../../../core/events/app_events.dart';
import '../../../core/models/models.dart';
import '../../../core/plugin/plugin.dart';
import '../../../core/repositories/graph_repository.dart';
import '../../../core/repositories/node_repository.dart';
import 'bloc/graph_bloc.dart';
import 'bloc/graph_event.dart';
import 'bloc/node_bloc.dart';
import 'bloc/node_event.dart';
import 'command/graph_commands.dart';
import 'command/node_commands.dart';
import 'handler/add_node_to_graph_handler.dart';
import 'handler/connect_nodes_handler.dart';
import 'handler/create_graph_handler.dart';
import 'handler/create_node_handler.dart';
import 'handler/delete_node_handler.dart';
import 'handler/disconnect_nodes_handler.dart';
import 'handler/load_graph_handler.dart';
import 'handler/move_node_handler.dart';
import 'handler/remove_node_from_graph_handler.dart';
import 'handler/rename_graph_handler.dart';
import 'handler/resize_node_handler.dart';
import 'handler/update_graph_handler.dart';
import 'handler/update_node_handler.dart';
import 'handler/update_node_position_handler.dart';
import 'service/graph_service.dart';
import 'service/graph_service_bindings.dart';
import 'service/node_service.dart';
import 'tasks/connection_path_task.dart';
import 'tasks/node_sizing_task.dart';
import 'tasks/text_layout_task.dart';

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
    // 注册任务类型
    _registerTaskTypes(context);

    // 注册命令处理器
    _registerCommandHandlers(context);
  }

  /// 注册任务类型到 TaskRegistry
  void _registerTaskTypes(PluginContext context) {
    final taskRegistry = context.taskRegistry;
    if (taskRegistry == null) {
      context.logger?.warning('TaskRegistry not available, skipping task registration');
      return;
    }

    // 注册 TextLayout 任务
    taskRegistry..registerTaskType(
      'TextLayout',
      TextLayoutTaskSerialized.new,
      (result) => TextLayoutResult(
        width: result['width'] as double,
        height: result['height'] as double,
        didExceedMaxWidth: result['didExceedMaxWidth'] as bool? ?? false,
        lineCount: const [],
      ),
    )

    // 注册 NodeSizing 任务
    ..registerTaskType(
      'NodeSizing',
      NodeSizingTaskSerialized.new,
      (result) => NodeSizeResult(
        width: result['width'] as double,
        height: result['height'] as double,
        isFolder: result['isFolder'] as bool? ?? false,
        viewMode: result['viewMode'] != null
            ? NodeViewMode.values.firstWhere(
                (e) => e.name == result['viewMode'],
                orElse: () => NodeViewMode.titleOnly,
              )
            : null,
      ),
    )

    // 注册 ConnectionPath 任务
    ..registerTaskType(
      'ConnectionPath',
      ConnectionPathTaskSerialized.new,
      (result) {
        final pathData = result['path'] as List;
        final points = pathData
            .map((p) => Vector2(
                  (p as Map)['x'] as double,
                  p['y'] as double,
                ))
            .toList();
        final controlPointData = result['controlPoint'] as Map<String, dynamic>?;
        return ConnectionPathResult(
          path: points,
          length: result['length'] as double,
          controlPoint: controlPointData != null
              ? Vector2(
                  controlPointData['x'] as double,
                  controlPointData['y'] as double,
                )
              : null,
        );
      },
    );
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

    // 注册命令处理器
    commandBus.registerHandlers({
      // 节点命令处理器
      CreateNodeCommand: CreateNodeHandler(nodeService),
      UpdateNodeCommand: UpdateNodeHandler(nodeService),
      DeleteNodeCommand: DeleteNodeHandler(nodeService),
      ConnectNodesCommand: ConnectNodesHandler(nodeRepository),
      DisconnectNodesCommand: DisconnectNodesHandler(nodeRepository),
      MoveNodeCommand: MoveNodeHandler(nodeRepository),
      ResizeNodeCommand: ResizeNodeHandler(nodeRepository),
      
      // 图命令处理器
      LoadGraphCommand: LoadGraphHandler(graphService),
      CreateGraphCommand: CreateGraphHandler(graphService),
      UpdateGraphCommand: UpdateGraphHandler(graphService),
      RenameGraphCommand: RenameGraphHandler(graphService),
      AddNodeToGraphCommand: AddNodeToGraphHandler(graphService),
      RemoveNodeFromGraphCommand: RemoveNodeFromGraphHandler(graphService),
      UpdateNodePositionCommand: UpdateNodePositionHandler(graphRepository),
    });
  }
}
