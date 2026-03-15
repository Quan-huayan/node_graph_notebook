import 'package:flutter/material.dart';
import '../../core/plugin/ui_hooks/ui_hook.dart';
import '../../core/plugin/ui_hooks/hook_context.dart';
import '../../core/plugin/plugin_metadata.dart';
import '../../core/plugin/plugin_context.dart';

/// 状态栏插件
///
/// 提供状态栏功能，通过 UI Hook 集成到状态栏区域
class StatusBarPlugin extends StatusBarHook {
  @override
  int get priority => 30;

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'status_bar_plugin',
        name: 'Status Bar Plugin',
        version: '1.0.0',
        description: 'Provides status bar functionality',
        author: 'Node Graph Notebook',
      );

  @override
  Widget renderStatusBar(StatusBarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(buildContext).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Node Graph Notebook'),
          Text(DateTime.now().toString().substring(0, 19)),
        ],
      ),
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
