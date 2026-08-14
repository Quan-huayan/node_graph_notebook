import 'package:appframe/ui/hooks/hook_contexts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plugin/plugin.dart';

import 'ui/node_editor_panel_hook_simple.dart';

/// 编辑器插件 — 节点内容编辑。
class EditorPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'editor_plugin',
    name: 'Editor Plugin',
    version: '1.0.0',
    description: 'Provides node content editing functionality',
    author: 'Node Graph Notebook',
  );

  @override
  List<ServiceRegistration> registerServices() => [];

  @override
  List<BlocProvider> registerBlocs() => [];

  @override
  List<HookFactory> registerHooks() => [
    NodeEditorPanelHook.new,
  ];

  @override
  Future<void> onLoad(PluginContext context) async {
    // 注册编辑器 Hook 点
    final hr = context.tryGet<HookRoleRegistry>();
    if (hr != null) {
      [
        const HookPointDefinition(
          id: 'editor.node',
          name: 'Node Editor',
          description: 'Node content editor',
          category: 'editor',
          contextType: NodeEditorHookContext,
        ),
      ].forEach(hr.registerHookPoint);
    }
  }
}
