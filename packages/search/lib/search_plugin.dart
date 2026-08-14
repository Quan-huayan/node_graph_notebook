import 'package:core/core.dart'
    hide Plugin, PluginManager, PluginContext, PluginMetadata;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:node_graph/graph.dart';
import 'package:plugin/plugin.dart';

import 'bloc/search_bloc.dart';
import 'command/search_commands.dart';
import 'handler/delete_search_preset_handler.dart';
import 'handler/save_search_preset_handler.dart';
import 'search_sidebar_hook.dart';
import 'service/search_preset_service.dart';

/// Search 插件 — 节点搜索与预设管理。
class SearchPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'search',
    name: 'Search',
    version: '1.0.0',
    description: 'Node search and preset management',
    author: 'Node Graph Notebook',
    enabledByDefault: true,
    dependencies: ['graph'],
  );

  @override
  List<ServiceRegistration> registerServices() => [
    ServiceRegistration.singleton<SearchPresetService>(
      (reg) => SearchPresetServiceImpl(reg.get<SharedPreferencesAsync>()),
      owner: metadata.id,
    ),
  ];

  @override
  List<BlocProvider> registerBlocs() => [
    BlocProvider<SearchBloc>(
      create: (ctx) => SearchBloc(
        nodeService: ctx.read<NodeService>(),
        presetService: ctx.read<SearchPresetService>(),
        commandBus: ctx.read<CommandBus>(),
        queryBus: ctx.read<QueryBus>(),
      ),
    ),
  ];

  @override
  List<HookFactory> registerHooks() => [
    SearchSidebarHook.new,
  ];

  @override
  Future<void> onLoad(PluginContext context) async {
    _registerCommandHandlers(context);
    debugPrint('[SearchPlugin] Search plugin loaded');
  }

  void _registerCommandHandlers(PluginContext context) {
    final commandBus = context.get<CommandBus>();
    final presetService = context.get<SearchPresetService>();

    commandBus.registerHandlers({
      SaveSearchPresetCommand: SaveSearchPresetHandler(presetService),
      DeleteSearchPresetCommand: DeleteSearchPresetHandler(presetService),
    });
  }
}
