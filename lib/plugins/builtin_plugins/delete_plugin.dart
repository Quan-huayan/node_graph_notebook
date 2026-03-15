import 'package:flutter/material.dart';
import '../../core/plugin/ui_hooks/ui_hook.dart';
import '../../core/plugin/ui_hooks/hook_context.dart';
import '../../core/plugin/plugin_metadata.dart';
import '../../core/plugin/plugin_context.dart';

/// 删除功能插件
///
/// 提供节点删除功能，通过 UI Hook 集成到上下文菜单
class DeletePlugin extends NodeContextMenuHook {
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
  void _deleteNode(NodeContextMenuHookContext context) {
    final node = context.node;
    if (node == null) return;
    
    // 暂时使用简单的实现
    showDialog(
      context: context.data['buildContext'] as BuildContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Node'),
        content: const Text('Are you sure you want to delete this node?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // 这里应该通过 commandBus 执行删除命令
              debugPrint('Deleting node: ${node.id}');
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
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
