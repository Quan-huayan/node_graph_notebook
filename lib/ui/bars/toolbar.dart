import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/blocs.dart';
import '../dialogs/graph_nodes_dialog.dart';
import '../menus/layout_menu.dart';
import '../dialogs/delete_node_dialog.dart';

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
    LayoutMenu.show(context);
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
    DeleteNodeDialog.show(context);
  }

  void _refreshData(BuildContext context) {
    // 刷新节点和图数据
    context.read<NodeBloc>().add(const NodeLoadEvent());
    context.read<GraphBloc>().add(const GraphInitializeEvent());
  }
}

