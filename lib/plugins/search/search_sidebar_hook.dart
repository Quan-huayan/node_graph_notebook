import 'package:flutter/material.dart';

import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_priority.dart';
import 'ui/search_sidebar_panel.dart';

/// 搜索侧边栏钩子
class SearchSidebarHook extends SidebarBottomHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'search_sidebar_hook',
    name: 'Search Sidebar Hook',
    version: '1.0.0',
    description: 'Provides search functionality in sidebar',
  );

  @override
  HookPriority get priority => HookPriority.medium;

  @override
  Widget renderSidebar(SidebarHookContext context) => const SearchSidebarPanel();
}
