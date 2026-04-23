import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/ui_layout/node_template.dart';
import '../sidebarNode/ui/sidebar_hook_renderer.dart';
import 'folder_node_template.dart';
import 'folder_sidebar_tab_hook.dart';

/// 文件夹插件
///
/// 提供文件夹管理功能，包括文件夹的创建、管理和组织
class FolderPlugin extends Plugin {
  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'folder_plugin',
    name: 'Folder Plugin',
    version: '1.0.0',
    description: 'Provides folder management functionality',
    author: 'Node Graph Notebook',
  );

  @override
  List<ServiceBinding> registerServices() => [];

  @override
  List<NodeTemplate> registerNodeTemplates() => [
        FolderNodeTemplate.template,
      ];

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
    // 清理资源
  }

  @override
  Map<String, dynamic> exportAPIs() => {};

  @override
  List<BlocProvider> registerBlocs() => [];

  @override
  List<HookFactory> registerHooks() => [
    FolderSidebarTabHook.new,
    SidebarNodeListHook.new,
  ];
}
