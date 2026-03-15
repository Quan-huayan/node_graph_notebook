import 'package:flutter/material.dart';
import '../../core/plugin/ui_hooks/ui_hook.dart';
import '../../core/plugin/ui_hooks/hook_context.dart';
import '../../core/plugin/plugin_metadata.dart';
import '../../core/plugin/plugin_context.dart';

/// 侧边栏插件
///
/// 提供侧边栏功能，通过 UI Hook 集成到侧边栏区域
class SidebarPlugin extends SidebarTopHook {
  @override
  int get priority => 40;

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'sidebar_plugin',
        name: 'Sidebar Plugin',
        version: '1.0.0',
        description: 'Provides sidebar functionality',
        author: 'Node Graph Notebook',
      );

  @override
  Widget renderSidebar(SidebarHookContext context) {
    return const Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Nodes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // 这里可以添加节点列表或其他侧边栏内容
        Padding(
          padding: EdgeInsets.all(16),
          child: Text('Node list will be implemented here'),
        ),
      ],
    );
  }

  @override
  Future<void> onInit() async {}

  @override
  Future<void> onDispose() async {}

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onUnload() async {}

  @override
  PluginState get state => PluginState.loaded;

  @override
  set state(PluginState newState) {}
}
