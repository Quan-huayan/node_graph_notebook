import 'package:flutter/material.dart';

import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_priority.dart';

/// 侧边栏 Hook
///
/// 提供侧边栏功能，通过 UI Hook 集成到侧边栏区域，显示节点列表等内容
class SidebarPlugin extends UIHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'sidebar_plugin',
    name: 'Sidebar Plugin',
    version: '1.0.0',
    description: 'Provides sidebar functionality',
  );

  @override
  String get hookPointId => 'sidebar.top';

  @override
  HookPriority get priority => HookPriority.medium;

  @override
  Widget render(HookContext context) {
    final sidebarContext = SidebarHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return _renderSidebar(sidebarContext);
  }

  Widget _renderSidebar(SidebarHookContext context) => const Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Nodes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
