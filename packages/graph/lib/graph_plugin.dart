import 'package:core/core.dart'
    hide Plugin, PluginManager, PluginContext, PluginMetadata, LoadGraphHandler;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plugin/plugin.dart';
import 'package:vector_math/vector_math.dart';

import 'bloc/graph_bloc.dart';
import 'bloc/graph_event.dart';
import 'bloc/node_bloc.dart';
import 'bloc/node_event.dart';
import 'command/graph_commands.dart';
import 'command/node_commands.dart';
import 'handler/add_node_to_graph_handler.dart';
import 'handler/batch_node_operations_handler.dart';
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
import 'handler/update_view_camera_handler.dart';
import 'hooks/graph_nodes_toolbar_hook.dart';
import 'hooks/refresh_graph_toolbar_hook.dart';
import 'hooks/toggle_connections_toolbar_hook.dart';
import 'service/graph_service.dart';
import 'service/node_service.dart';
import 'tasks/connection_path_task.dart';
import 'tasks/node_sizing_task.dart';
import 'tasks/text_layout_task.dart';

/// Graph 插件 — 图可视化与节点管理。
///
/// 注册 NodeService、GraphService、NodeBloc、GraphBloc。
class GraphPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'graph',
    name: 'Graph',
    version: '1.0.0',
    description: 'Graph management and node operations',
    author: 'Node Graph Notebook',
    enabledByDefault: true,
    dependencies: ['core', 'appframe'],
  );

  @override
  List<ServiceRegistration> registerServices() => [
    ServiceRegistration.singleton<NodeService>(
      (reg) => NodeServiceImpl(reg.get<NodeRepository>()),
      owner: metadata.id,
    ),
    ServiceRegistration.singleton<GraphService>(
      (reg) => GraphServiceImpl(
        reg.get<GraphRepository>(),
        reg.get<NodeRepository>(),
      ),
      owner: metadata.id,
    ),
  ];

  @override
  List<BlocProvider> registerBlocs() => [
    BlocProvider<NodeBloc>(
      create: (ctx) => NodeBloc(
        commandBus: ctx.read<CommandBus>(),
        queryBus: ctx.read<QueryBus>(),
      )..add(const NodeLoadEvent()),
    ),
    BlocProvider<GraphBloc>(
      create: (ctx) => GraphBloc(
        commandBus: ctx.read<CommandBus>(),
        queryBus: ctx.read<QueryBus>(),
        layoutService: ctx.read<UILayoutService>(),
      )..add(const GraphInitializeEvent()),
    ),
  ];

  @override
  List<HookFactory> registerHooks() => [
    GraphNodesToolbarHook.new,
    RefreshGraphToolbarHook.new,
    ToggleConnectionsToolbarHook.new,
  ];

  @override
  Future<void> onLoad(PluginContext context) async {
    _registerTaskTypes(context);
    _registerCommandHandlers(context);
    debugPrint('[GraphPlugin] Graph plugin loaded');
  }

  void _registerTaskTypes(PluginContext context) {
    final taskRegistry = context.tryGet<TaskRegistry>();
    if (taskRegistry == null) {
      debugPrint('[GraphPlugin] TaskRegistry not available');
      return;
    }

    taskRegistry
      ..registerTaskType(
        'TextLayout',
        TextLayoutTaskSerialized.new,
        (result) {
          final data = result as Map<String, dynamic>;
          return TextLayoutResult(
            width: data['width']! as double,
            height: data['height']! as double,
            didExceedMaxWidth: data['didExceedMaxWidth'] as bool? ?? false,
            lineCount: const [],
          );
        },
      )
      ..registerTaskType(
        'NodeSizing',
        NodeSizingTaskSerialized.new,
        (result) {
          final data = result as Map<String, dynamic>;
          return NodeSizeResult(
            width: data['width']! as double,
            height: data['height']! as double,
            isFolder: data['isFolder'] as bool? ?? false,
            viewMode: data['viewMode'] != null
                ? NodeViewMode.values.firstWhere(
                    (e) => e.name == data['viewMode'],
                    orElse: () => NodeViewMode.titleOnly,
                  )
                : null,
          );
        },
      )
      ..registerTaskType(
        'ConnectionPath',
        ConnectionPathTaskSerialized.new,
        (result) {
          final data = result as Map<String, dynamic>;
          final pathData = data['path']! as List;
          final points = pathData
              .map((p) {
                final point = p as Map<String, dynamic>;
                return Vector2(
                  point['x']! as double,
                  point['y']! as double,
                );
              })
              .toList();
          final controlPointData =
              data['controlPoint'] as Map<String, dynamic>?;
          return ConnectionPathResult(
            path: points,
            length: data['length']! as double,
            controlPoint: controlPointData != null
                ? Vector2(
                    controlPointData['x']! as double,
                    controlPointData['y']! as double,
                  )
                : null,
          );
        },
      );
  }

  void _registerCommandHandlers(PluginContext context) {
    final commandBus = context.get<CommandBus>();
    final nodeService = context.get<NodeService>();
    final graphService = context.get<GraphService>();
    final layoutService = context.get<UILayoutService>();

    commandBus.registerHandlers({
      CreateNodeCommand: CreateNodeHandler(nodeService),
      UpdateNodeCommand: UpdateNodeHandler(nodeService),
      DeleteNodeCommand: DeleteNodeHandler(nodeService),
      ConnectNodesCommand: ConnectNodesHandler(nodeService),
      DisconnectNodesCommand: DisconnectNodesHandler(nodeService),
      MoveNodeCommand: MoveNodeHandler(layoutService),
      ResizeNodeCommand: ResizeNodeHandler(nodeService),
      LoadGraphCommand: LoadGraphHandler(graphService),
      CreateGraphCommand: CreateGraphHandler(graphService),
      UpdateGraphCommand: UpdateGraphHandler(graphService),
      RenameGraphCommand: RenameGraphHandler(graphService),
      AddNodeToGraphCommand: AddNodeToGraphHandler(graphService),
      RemoveNodeFromGraphCommand: RemoveNodeFromGraphHandler(graphService),
      UpdateNodePositionCommand: UpdateNodePositionHandler(layoutService),
      UpdateViewCameraCommand: UpdateViewCameraHandler(graphService),
      BatchNodeOperationsCommand: BatchNodeOperationsHandler(graphService),
    });
  }
}
