import 'package:appframe/ui/hooks/hook_bases.dart';
import 'package:appframe/ui/hooks/hook_contexts.dart';
import 'package:flutter/material.dart';
import 'package:plugin/plugin.dart';

import 'ui/search_sidebar_panel.dart';

/// 搜索侧边栏钩子
class SearchSidebarHook extends SidebarBottomHookRole {
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
