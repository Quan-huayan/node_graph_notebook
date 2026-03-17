import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/commands/command_bus.dart';
import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../graph/service/node_service.dart';
import 'bloc/search_bloc.dart';
import 'command/search_commands.dart';
import 'handler/delete_search_preset_handler.dart';
import 'handler/save_search_preset_handler.dart';
import 'search_sidebar_hook.dart';
import 'service/search_preset_service.dart';
import 'service/search_service_bindings.dart';

/// Search 插件
///
/// 提供搜索相关功能：节点搜索、预设管理等
class SearchPlugin extends Plugin {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

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
  List<ServiceBinding> registerServices() => [SearchPresetServiceBinding()];

  @override
  List<BlocProvider> registerBlocs() => [
    BlocProvider<SearchBloc>(
      create: (ctx) => SearchBloc(
        nodeService: ctx.read<NodeService>(),
        presetService: ctx.read<SearchPresetService>(),
        commandBus: ctx.read<CommandBus>(),
      ),
    ),
  ];

  @override
  List<HookFactory> registerHooks() => [
    SearchSidebarHook.new,
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
    final presetService = context.read<SearchPresetService>();

    // 注册搜索预设命令处理器
    commandBus.registerHandlers({
      SaveSearchPresetCommand: SaveSearchPresetHandler(presetService),
      DeleteSearchPresetCommand: DeleteSearchPresetHandler(presetService),
    });
  }
}
