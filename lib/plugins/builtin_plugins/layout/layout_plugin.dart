import 'package:flutter/material.dart';
import '../../../core/plugin/ui_hooks/ui_hook.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/plugin_metadata.dart';
import '../../../core/plugin/plugin_context.dart';
import 'command/layout_commands.dart';

/// 布局功能插件
///
/// 提供图形布局功能，通过 UI Hook 集成到工具栏
class LayoutPlugin extends MainToolbarHook {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }
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
    final buildContext = context.data['buildContext'] as BuildContext?;

    if (buildContext == null) {
      debugPrint('LayoutPlugin: BuildContext not found in HookContext data');
      return;
    }

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
              onTap: () {
                Navigator.pop(ctx);
                _applyLayout(context, 'force_directed', buildContext);
              },
            ),
            _LayoutOption(
              title: 'Tree Layout',
              description: 'Hierarchical tree layout',
              onTap: () {
                Navigator.pop(ctx);
                _applyLayout(context, 'tree', buildContext);
              },
            ),
            _LayoutOption(
              title: 'Circular Layout',
              description: 'Circular graph layout',
              onTap: () {
                Navigator.pop(ctx);
                _applyLayout(context, 'circular', buildContext);
              },
            ),
            _LayoutOption(
              title: 'Grid Layout',
              description: 'Grid-based layout',
              onTap: () {
                Navigator.pop(ctx);
                _applyLayout(context, 'grid', buildContext);
              },
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
  Future<void> _applyLayout(
    MainToolbarHookContext context,
    String layoutType,
    BuildContext buildContext,
  ) async {
    // 检查 PluginContext 是否可用
    if (context.pluginContext == null) {
      debugPrint('LayoutPlugin: PluginContext not available');
      if (buildContext.mounted) {
        ScaffoldMessenger.of(buildContext).showSnackBar(
          const SnackBar(
            content: Text('Plugin system not available'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // 显示加载指示器
      if (buildContext.mounted) {
        showDialog(
          context: buildContext,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // 通过 CommandBus 执行布局命令
      final result = await context.pluginContext!.commandBus.dispatch(
        ApplyLayoutCommand(layoutType: layoutType),
      );

      // 关闭加载指示器
      if (buildContext.mounted) {
        Navigator.of(buildContext).pop();
      }

      if (!result.isSuccess) {
        context.pluginContext!.error('Failed to apply layout: ${result.error}');
        // 显示错误提示
        if (buildContext.mounted) {
          ScaffoldMessenger.of(buildContext).showSnackBar(
            SnackBar(
              content: Text('Failed to apply layout: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        final nodeCount = result.data?.length ?? 0;
        context.pluginContext!.info('Layout applied: $layoutType ($nodeCount nodes)');
        // 显示成功提示
        if (buildContext.mounted) {
          ScaffoldMessenger.of(buildContext).showSnackBar(
            SnackBar(
              content: Text('Layout applied: $layoutType ($nodeCount nodes)'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // 关闭加载指示器
      if (buildContext.mounted) {
        Navigator.of(buildContext).pop();
      }

      context.pluginContext!.error('Error applying layout', e);
      // 显示错误提示
      if (buildContext.mounted) {
        ScaffoldMessenger.of(buildContext).showSnackBar(
          SnackBar(
            content: Text('Error applying layout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
