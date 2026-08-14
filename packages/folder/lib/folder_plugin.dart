import 'package:core/plugin/hook/node_template.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plugin/plugin.dart';

import 'folder_node_template.dart';
import 'folder_sidebar_tab_hook.dart';

/// 文件夹插件
///
/// 提供文件夹管理功能，包括文件夹的创建、管理和组织。
class FolderPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'folder_plugin',
    name: 'Folder Plugin',
    version: '1.0.0',
    description: 'Provides folder management functionality',
    author: 'Node Graph Notebook',
    dependencies: ['graph'],
  );

  @override
  List<ServiceRegistration> registerServices() => [];

  @override
  List<HookFactory> registerHooks() => [
    FolderSidebarTabHook.new,
  ];

  /// 注册节点模板（通过旧系统 NodeTemplateRegistry）。
  List<NodeTemplate> get nodeTemplates => [
    FolderNodeTemplate.template,
  ];

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  List<BlocProvider> registerBlocs() => [];
}
