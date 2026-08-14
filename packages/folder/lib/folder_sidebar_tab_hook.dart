import 'package:appframe/ui/hooks/hook_bases.dart';
import 'package:appframe/ui/hooks/hook_contexts.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:plugin/plugin.dart';

import 'ui/folder_tree_view.dart';

/// 资源管理器标签页Hook
///
/// 在Sidebar中显示文件夹和节点的树形视图
class FolderSidebarTabHook extends SidebarTabHookRole {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'folder.sidebar_tab',
    name: 'Explorer Sidebar Tab',
    version: '1.0.0',
    description: 'Provides an explorer tab in the sidebar showing folders and nodes',
  );

  @override
  String get tabId => 'explorer';

  @override
  String get tabLabel => 'Explorer';

  @override
  IconData get tabIcon => Icons.folder_open;

  @override
  HookPriority get tabPriority => HookPriority.high;

  @override
  Widget buildContent(SidebarHookContext context) {
    final folders = context.get<List<Node>>('folders') ?? [];
    final nodes = context.get<List<Node>>('nodes') ?? [];
    final onNodeSelected = context.get<Function(String?)>('onNodeSelected');

    return FolderTreeView(
      folders: folders,
      nodes: nodes,
      onNodeSelected: onNodeSelected,
    );
  }
}
