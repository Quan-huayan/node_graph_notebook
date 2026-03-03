import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/services/theme_service.dart';
import '../models/models.dart';
import 'graph_nodes_dialog.dart';

/// 工具栏
class Toolbar extends StatelessWidget {
  const Toolbar({
    super.key,
    required this.graphModel,
    required this.uiModel,
  });

  final GraphModel graphModel;
  final UIModel uiModel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 布局按钮
            IconButton(
              icon: const Icon(Icons.account_tree),
              tooltip: 'Layout',
              onPressed: () => _showLayoutMenu(context),
            ),
            IconButton(
              icon: const Icon(Icons.view_module),
              tooltip: 'View Mode',
              onPressed: () => _showViewModeMenu(context),
            ),
            IconButton(
              icon: Icon(
                uiModel.showConnections
                    ? Icons.share
                    : Icons.share_outlined,
              ),
              tooltip: 'Toggle Connections',
              onPressed: () {
                uiModel.toggleConnections();
              },
            ),
            IconButton(
              icon: const Icon(Icons.category),
              tooltip: 'Toggle Concept Nodes',
              onPressed: () {
                uiModel.toggleConceptNodes();
              },
            ),
            IconButton(
              icon: Icon(
                uiModel.isSidebarOpen
                    ? Icons.menu_open
                    : Icons.menu,
              ),
              tooltip: 'Toggle Sidebar',
              onPressed: () {
                uiModel.toggleSidebar();
              },
            ),
            const Divider(),
            // 管理图节点按钮
            IconButton(
              icon: const Icon(Icons.playlist_add_check),
              tooltip: 'Manage Graph Nodes',
              onPressed: () => _showGraphNodesDialog(context),
            ),
            // 删除按钮
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Selected Node',
              onPressed: () => _deleteSelectedNode(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showLayoutMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Layout Algorithm'),
              tileColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: const Text('Force Directed'),
              subtitle: const Text('Physics-based layout'),
              onTap: () {
                Navigator.pop(ctx);
                _applyLayout(context, LayoutAlgorithm.forceDirected);
              },
            ),
            ListTile(
              leading: const Icon(Icons.stacked_line_chart),
              title: const Text('Hierarchical'),
              subtitle: const Text('Tree-based layout'),
              onTap: () {
                Navigator.pop(ctx);
                _applyLayout(context, LayoutAlgorithm.hierarchical);
              },
            ),
            ListTile(
              leading: const Icon(Icons.circle_outlined),
              title: const Text('Circular'),
              subtitle: const Text('Circle arrangement'),
              onTap: () {
                Navigator.pop(ctx);
                _applyLayout(context, LayoutAlgorithm.circular);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_tree),
              title: const Text('Concept Map'),
              subtitle: const Text('Organize by concept nodes'),
              onTap: () {
                Navigator.pop(ctx);
                _applyLayout(context, LayoutAlgorithm.conceptMap);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyLayout(
    BuildContext context,
    LayoutAlgorithm algorithm,
  ) async {
    final nodeModel = context.read<NodeModel>();
    final graphModel = context.read<GraphModel>();

    // 检查是否有节点
    if (nodeModel.nodes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No nodes to layout. Create some nodes first.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 保存旧位置以便撤销
    final oldPositions = <String, Offset>{};
    for (final node in nodeModel.nodes) {
      oldPositions[node.id] = node.position;
    }

    // 显示加载提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text('Applying ${_getLayoutName(algorithm)} layout...'),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      // 应用布局
      final layoutService = LayoutServiceImpl();
      final newPositions = await layoutService.applyLayout(
        nodes: nodeModel.nodes,
        algorithm: algorithm,
      );

      // 保存所有新位置
      for (final entry in newPositions.entries) {
        await nodeModel.updateNode(
          entry.key,
          position: entry.value,
        );
      }

      // 刷新图
      await graphModel.refresh();

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Applied ${_getLayoutName(algorithm)} layout to ${newPositions.length} nodes'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => _undoLayout(context, nodeModel, graphModel, oldPositions),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final theme = context.read<ThemeService>().themeData;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply layout: $e'),
            backgroundColor: theme.status.error,
          ),
        );
      }
    }
  }

  Future<void> _undoLayout(
    BuildContext context,
    NodeModel nodeModel,
    GraphModel graphModel,
    Map<String, Offset> oldPositions,
  ) async {
    try {
      for (final entry in oldPositions.entries) {
        await nodeModel.updateNode(
          entry.key,
          position: entry.value,
        );
      }

      await graphModel.refresh();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Layout undone'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final theme = context.read<ThemeService>().themeData;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to undo layout: $e'),
            backgroundColor: theme.status.error,
          ),
        );
      }
    }
  }

  void _showViewModeMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Consumer<UIModel>(
          builder: (ctx, uiModel, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('View Mode'),
                  tileColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                ),
                ListTile(
                  leading: Icon(
                    uiModel.viewMode == ViewModeType.normalGraph
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
                  title: const Text('Normal Graph'),
                  subtitle: const Text('Show connections as arrows'),
                  onTap: () {
                    uiModel.setViewMode(ViewModeType.normalGraph);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Icon(
                    uiModel.viewMode == ViewModeType.conceptMap
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
                  title: const Text('Concept Map'),
                  subtitle: const Text('Show all nodes with reference arrows'),
                  onTap: () {
                    uiModel.setViewMode(ViewModeType.conceptMap);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _getLayoutName(LayoutAlgorithm algorithm) {
    switch (algorithm) {
      case LayoutAlgorithm.forceDirected:
        return 'Force Directed';
      case LayoutAlgorithm.hierarchical:
        return 'Hierarchical';
      case LayoutAlgorithm.circular:
        return 'Circular';
      case LayoutAlgorithm.conceptMap:
        return 'Concept Map';
      case LayoutAlgorithm.free:
        return 'Free';
    }
  }

  Future<void> _deleteSelectedNode(BuildContext context) async {
    final nodeModel = context.read<NodeModel>();
    final graphModel = context.read<GraphModel>();

    // 检查是否有选中的节点
    if (nodeModel.selectedNode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No node selected. Click a node to select it first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final node = nodeModel.selectedNode!;

    // 确认删除
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = context.read<ThemeService>().themeData;
        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: const Text('Delete Node'),
          content: Text('Are you sure you want to delete "${node.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // 先从图中移除
        if (graphModel.hasGraph) {
          await graphModel.removeNode(node.id);
        }

        // 再删除节点本身
        await nodeModel.deleteNode(node.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted: ${node.title}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          final theme = context.read<ThemeService>().themeData;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete node: $e'),
              backgroundColor: theme.status.error,
            ),
          );
        }
      }
    }
  }

  void _showGraphNodesDialog(BuildContext context) {
    final nodeModel = context.read<NodeModel>();
    final graphModel = context.read<GraphModel>();

    showDialog(
      context: context,
      builder: (ctx) => GraphNodesDialog(
        graphModel: graphModel,
        nodeModel: nodeModel,
      ),
    );
  }
}

