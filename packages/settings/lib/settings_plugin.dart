import 'package:plugin/plugin.dart';

import 'settings_toolbar_hook.dart';

/// Settings 插件
class SettingsPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'settings',
    name: 'Settings',
    version: '1.0.0',
    description: 'Settings and configuration functionality',
    author: 'Node Graph Notebook',
  );

  @override
  List<HookFactory> registerHooks() => [
    SettingsToolbarHook.new,
  ];

  @override
  Future<void> onLoad(PluginContext context) async {}
}
