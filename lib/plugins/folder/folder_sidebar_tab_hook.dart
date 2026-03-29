import 'package:flutter/material.dart';

import '../../core/models/node.dart';
import '../../core/plugin/ui_hooks/hook_context.dart';
import '../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../core/plugin/ui_hooks/hook_priority.dart';
import '../../core/plugin/ui_hooks/sidebar_tab_hook_base.dart';
import 'ui/folder_tree_view.dart';

/// 文件夹标签页Hook
///
/// 在Sidebar中显示文件夹树形视图标签页
class FolderSidebarTabHook extends SidebarTabHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'folder.sidebar_tab',
    name: 'Folder Sidebar Tab',
    version: '1.0.0',
    description: 'Provides a folders tab in the sidebar',
  );

  @override
  String get tabId => 'folders';

  @override
  String get tabLabel => 'Folders';

  @override
  IconData get tabIcon => Icons.folder;

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
