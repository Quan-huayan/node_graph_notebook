import 'package:flutter/material.dart';

import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/ui_hook.dart';
import 'ui/search_sidebar_panel.dart';

/// 搜索侧边栏钩子
class SearchSidebarHook extends SidebarBottomHook {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  int get priority => 10;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'search_sidebar_hook',
    name: 'Search Sidebar Hook',
    version: '1.0.0',
    description: 'Provides search functionality in sidebar',
    author: 'Node Graph Notebook',
    enabledByDefault: true,
  );

  @override
  Widget renderSidebar(SidebarHookContext context) => const SearchSidebarPanel();

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
}
