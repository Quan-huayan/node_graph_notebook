import '../../../core/plugin/plugin.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'service/search_service_bindings.dart';
import 'bloc/search_bloc.dart';
import '../graph/service/node_service.dart';
import 'service/search_preset_service.dart';

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
      );

  @override
  List<ServiceBinding> registerServices() => [
        SearchPresetServiceBinding(),
      ];

  @override
  List<BlocProvider> registerBlocs() => [
        BlocProvider<SearchBloc>(
          create: (ctx) => SearchBloc(
            nodeService: ctx.read<NodeService>(),
            presetService: ctx.read<SearchPresetService>(),
          ),
        ),
      ];

  @override
  Future<void> onLoad(PluginContext context) async {
    // 加载时的逻辑
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
}
