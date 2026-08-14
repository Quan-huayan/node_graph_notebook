import 'package:plugin/plugin.dart';

import 'market_toolbar_hook.dart';

/// Market 插件
class MarketPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'market',
    name: 'Market',
    version: '1.0.0',
    description: 'Plugin market and extension management',
    author: 'Node Graph Notebook',
  );

  @override
  List<HookFactory> registerHooks() => [
    MarketToolbarHook.new,
  ];

  @override
  Future<void> onLoad(PluginContext context) async {}
}
