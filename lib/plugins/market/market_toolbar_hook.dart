import 'package:flutter/material.dart';

import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/ui_hook.dart';
import '../../../ui/pages/plugin_market_page.dart';

/// 插件市场工具栏钩子
class MarketToolbarHook extends MainToolbarHook {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  int get priority => 20;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'market_toolbar_hook',
    name: 'Market Toolbar Hook',
    version: '1.0.0',
    description: 'Provides plugin market button in toolbar',
    author: 'Node Graph Notebook',
  );

  @override
  Widget renderToolbar(MainToolbarHookContext context) => IconButton(
      icon: const Icon(Icons.extension),
      onPressed: () => _openPluginMarket(context),
      tooltip: 'Plugin Market',
    );

  void _openPluginMarket(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    Navigator.push(
      buildContext,
      MaterialPageRoute(builder: (ctx) => const PluginMarketPage()),
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
}
