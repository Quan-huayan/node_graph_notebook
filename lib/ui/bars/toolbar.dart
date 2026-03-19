import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/plugin/ui_hooks/hook_context.dart';
import '../../core/plugin/ui_hooks/hook_registry.dart';
import '../../core/services/i18n.dart';
import '../../plugins/graph/bloc/graph_bloc.dart';
import '../../plugins/graph/bloc/graph_event.dart';
import '../../plugins/graph/bloc/node_bloc.dart';
import '../../plugins/graph/bloc/node_event.dart';
import '../../plugins/graph/service/delete_node_dialog.dart';
import '../bloc/ui_bloc.dart';
import '../bloc/ui_event.dart';
import '../bloc/ui_state.dart';

/// 工具栏
class Toolbar extends StatelessWidget {
  /// 创建工具栏
  const Toolbar({super.key, required this.uiState});

  /// UI 状态
  final UIState uiState;

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final hookWrappers = hookRegistry.getHookWrappers('main.toolbar');

    debugPrint('[Toolbar] build() called:');
    debugPrint('  - MainToolbar hooks found: ${hookWrappers.length}');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 收起/展开按钮
            IconButton(
              icon: Icon(
                uiState.isToolbarExpanded
                    ? Icons.expand_less
                    : Icons.expand_more,
              ),
              tooltip: i18n.t(uiState.isToolbarExpanded
                  ? 'Collapse Toolbar'
                  : 'Expand Toolbar'),
              onPressed: () {
                context.read<UIBloc>().add(const UIToggleToolbarEvent());
              },
            ),
            if (uiState.isToolbarExpanded) ...[
              // 动态加载所有主工具栏钩子（仅限工具栏相关）
              ...hookWrappers.map((hookWrapper) {
                final hook = hookWrapper.hook;
                debugPrint('  - Rendering toolbar hook: ${hook.metadata.id}');
                final hookContext = MainToolbarHookContext(
                  data: {
                    'buildContext': context,
                    'graphBloc': context.read<GraphBloc>(),
                    'nodeBloc': context.read<NodeBloc>(),
                  },
                  pluginContext: hookWrapper.parentPlugin?.context,
                  hookAPIRegistry: hookRegistry.apiRegistry,
                );
                if (hook.isVisible(hookContext)) {
                  return hook.render(hookContext);
                }
                return null;
              }).whereType<Widget>(),
              IconButton(
                icon: Icon(
                  context.read<GraphBloc>().state.viewState.showConnections
                      ? Icons.share
                      : Icons.share_outlined,
                ),
                tooltip: i18n.t('Toggle Connections'),
                onPressed: () {
                  context.read<GraphBloc>().add(
                    const ViewToggleConnectionsEvent(),
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  uiState.isSidebarOpen ? Icons.menu_open : Icons.menu,
                ),
                tooltip: i18n.t('Toggle Sidebar'),
                onPressed: () {
                  context.read<UIBloc>().add(const UIToggleSidebarEvent());
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: i18n.t('Refresh'),
                onPressed: () => _refreshData(context),
              ),
              const Divider(),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: i18n.t('Delete Selected Node'),
                onPressed: () => _deleteSelectedNode(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelectedNode(BuildContext context) async {
    DeleteNodeDialog.show(context);
  }

  void _refreshData(BuildContext context) {
    // 刷新节点和图数据
    final graphBloc = context.read<GraphBloc>();
    final nodeBloc = context.read<NodeBloc>();

    // 重新初始化图和节点数据
    graphBloc.add(const GraphInitializeEvent());
    nodeBloc.add(const NodeLoadEvent());
  }
}
