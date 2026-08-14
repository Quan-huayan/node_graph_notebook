import 'package:core/core.dart' hide Plugin, PluginManager;
import 'package:node_graph/service/graph_service.dart';
import 'package:plugin/plugin.dart';

import 'command/layout_commands.dart';
import 'handler/apply_layout_handler.dart';
import 'layout_toolbar_hook.dart';
import 'service/layout_service.dart';

/// A plugin that provides graph layout algorithms and node positioning
/// functionality, including automatic layout and batch node movement.
class LayoutPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'layout',
    name: 'Layout',
    version: '1.0.0',
    description: 'Graph layout and node positioning',
    author: 'Node Graph Notebook',
  );

  @override
  List<ServiceRegistration> registerServices() => [];

  @override
  List<HookFactory> registerHooks() => [
    LayoutToolbarHook.new,
  ];

  @override
  Future<void> onLoad(PluginContext context) async {
    _registerCommandHandlers(context);
  }

  void _registerCommandHandlers(PluginContext context) {
    final commandBus = context.get<CommandBus>();
    final graphService = context.get<GraphService>();
    final layoutService = context.get<LayoutService>();
    final nodeRepository = context.get<NodeRepository>();
    final uiLayoutService = context.get<UILayoutService>();

    commandBus
      ..registerHandler<ApplyLayoutCommand>(
        ApplyLayoutHandler(graphService, layoutService, uiLayoutService, commandBus),
        ApplyLayoutCommand,
      )
      ..registerHandler<BatchMoveNodesCommand>(
        BatchMoveNodesHandler(nodeRepository, uiLayoutService),
        BatchMoveNodesCommand,
      );
  }
}
