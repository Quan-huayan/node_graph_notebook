import 'package:flutter/material.dart';
import '../../core/plugin/ui_hooks/ui_hook.dart';
import '../../core/plugin/ui_hooks/hook_context.dart';
import '../../core/plugin/plugin_metadata.dart';
import '../../core/plugin/plugin_context.dart';

/// 布局功能插件
///
/// 提供图形布局功能，通过 UI Hook 集成到工具栏
class LayoutPlugin extends MainToolbarHook {
  @override
  int get priority => 60;

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'layout_plugin',
        name: 'Layout Plugin',
        version: '1.0.0',
        description: 'Provides graph layout functionality',
        author: 'Node Graph Notebook',
      );

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    return IconButton(
      icon: const Icon(Icons.account_tree),
      tooltip: 'Layout',
      onPressed: () => _showLayoutMenu(context),
    );
  }

  /// 显示布局菜单
  void _showLayoutMenu(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext;
    
    showDialog(
      context: buildContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Layout Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LayoutOption(
              title: 'Force Directed',
              description: 'Force-directed graph layout',
              onTap: () => _applyLayout(context, 'force_directed'),
            ),
            _LayoutOption(
              title: 'Tree Layout',
              description: 'Hierarchical tree layout',
              onTap: () => _applyLayout(context, 'tree'),
            ),
            _LayoutOption(
              title: 'Circular Layout',
              description: 'Circular graph layout',
              onTap: () => _applyLayout(context, 'circular'),
            ),
            _LayoutOption(
              title: 'Grid Layout',
              description: 'Grid-based layout',
              onTap: () => _applyLayout(context, 'grid'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// 应用布局
  void _applyLayout(MainToolbarHookContext context, String layoutType) {
    // 通过 Command Bus 执行布局命令
    // 这里需要创建并分发布局命令
    debugPrint('Applying layout: $layoutType');
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

/// 布局选项组件
class _LayoutOption extends StatelessWidget {
  const _LayoutOption({
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(description),
      onTap: onTap,
    );
  }
}
