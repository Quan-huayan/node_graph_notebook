import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:node_graph_notebook/core/services/services.dart';
import '../../bloc/blocs.dart';
import '../../core/models/models.dart';
import '../dialogs/graph_nodes_dialog.dart';

/// 工具栏
class Toolbar extends StatelessWidget {
  const Toolbar({
    super.key,
    required this.uiState,
  });

  final UIState uiState;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 收起/展开按钮
            IconButton(
              icon: Icon(uiState.isToolbarExpanded ? Icons.expand_less : Icons.expand_more),
              tooltip: uiState.isToolbarExpanded ? 'Collapse Toolbar' : 'Expand Toolbar',
              onPressed: () {
                context.read<UIBloc>().add(const UIToggleToolbarEvent());
              },
            ),
            if (uiState.isToolbarExpanded)
              ...[
                // 布局按钮
                IconButton(
                  icon: const Icon(Icons.account_tree),
                  tooltip: 'Layout',
                  onPressed: () => _showLayoutMenu(context),
                ),
                IconButton(
                  icon: Icon(
                    context.read<GraphBloc>().state.viewState.showConnections
                        ? Icons.share
                        : Icons.share_outlined,
                  ),
                  tooltip: 'Toggle Connections',
                  onPressed: () {
                    context.read<GraphBloc>().add(const ViewToggleConnectionsEvent());
                  },
                ),
                IconButton(
                  icon: Icon(
                    uiState.isSidebarOpen
                        ? Icons.menu_open
                        : Icons.menu,
                  ),
                  tooltip: 'Toggle Sidebar',
                  onPressed: () {
                    context.read<UIBloc>().add(const UIToggleSidebarEvent());
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => _refreshData(context),
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
    final bloc = context.read<GraphBloc>();

    // 检查是否有节点
    if (bloc.state.nodes.isEmpty) {
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

    // 应用布局
    bloc.add(LayoutApplyEvent(algorithm));
  }

  void _showGraphNodesDialog(BuildContext context) {
    final bloc = context.read<GraphBloc>();
    final nodeBloc = context.read<NodeBloc>();

    showDialog(
      context: context,
      builder: (ctx) => GraphNodesDialog(
        graphBloc: bloc,
        nodeBloc: nodeBloc,
      ),
    );
  }

  Future<void> _deleteSelectedNode(BuildContext context) async {
    final bloc = context.read<GraphBloc>();
    final nodeBloc = context.read<NodeBloc>();
    final nodeState = nodeBloc.state;

    // 检查是否有选中的节点
    if (nodeState.selectedNode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No node selected. Click a node to select it first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final node = nodeState.selectedNode!;

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
        // 从图中删除节点
        bloc.add(NodeDeleteEvent(node.id));

        // 再删除节点本身
        nodeBloc.add(NodeDeleteEvent(node.id));

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

  void _refreshData(BuildContext context) {
    // 刷新节点和图数据
    context.read<NodeBloc>().add(const NodeLoadEvent());
    context.read<GraphBloc>().add(const GraphInitializeEvent());
  }
}

