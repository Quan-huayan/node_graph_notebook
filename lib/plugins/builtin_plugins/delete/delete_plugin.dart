import 'package:flutter/material.dart';

import '../../../core/plugin/plugin_context.dart';
import '../../../core/plugin/plugin_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/ui_hook.dart';
import '../graph/command/node_commands.dart';

/// 删除功能插件
///
/// 提供节点删除功能，通过 UI Hook 集成到上下文菜单
class DeletePlugin extends NodeContextMenuHook {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  int get priority => 50;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'delete_plugin',
    name: 'Delete Plugin',
    version: '1.0.0',
    description: 'Provides node deletion functionality',
    author: 'Node Graph Notebook',
  );

  @override
  Widget renderMenu(NodeContextMenuHookContext context) {
    final node = context.node;
    if (node == null) return const SizedBox.shrink();

    return ListTile(
      title: const Text('Delete'),
      leading: const Icon(Icons.delete, color: Colors.red),
      onTap: () => _deleteNode(context),
    );
  }

  /// 删除节点
  Future<void> _deleteNode(NodeContextMenuHookContext context) async {
    final node = context.node;
    if (node == null) return;

    // 检查 PluginContext 是否可用
    if (context.pluginContext == null) {
      debugPrint('DeletePlugin: PluginContext not available');
      return;
    }

    final buildContext = context.data['buildContext'] as BuildContext?;

    if (buildContext == null) {
      context.pluginContext!.error(
        'BuildContext not found in HookContext data',
      );
      return;
    }

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: buildContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Node'),
        content: Text('Are you sure you want to delete "${node.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        // 通过 CommandBus 执行删除命令
        final result = await context.pluginContext!.commandBus.dispatch(
          DeleteNodeCommand(node: node, cascadeConnections: true),
        );

        if (!result.isSuccess) {
          context.pluginContext!.error('Failed to delete node', result.error);
          // 显示错误提示
          if (buildContext.mounted) {
            ScaffoldMessenger.of(buildContext).showSnackBar(
              SnackBar(
                content: Text('Failed to delete node: ${result.error}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          context.pluginContext!.info('Node deleted: ${node.id}');
          // 显示成功提示
          if (buildContext.mounted) {
            ScaffoldMessenger.of(buildContext).showSnackBar(
              SnackBar(
                content: Text('Node "${node.title}" deleted'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        context.pluginContext!.error('Error deleting node', e);
        // 显示错误提示
        if (buildContext.mounted) {
          ScaffoldMessenger.of(buildContext).showSnackBar(
            SnackBar(
              content: Text('Error deleting node: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
