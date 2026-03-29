import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_priority.dart';
import '../../../core/services/i18n.dart';
import 'bloc/graph_bloc.dart';
import 'bloc/graph_event.dart';
import 'bloc/graph_state.dart';

/// 切换连接线显示工具栏钩子
///
/// 提供切换节点之间连接线显示/隐藏的功能
/// 注册到 graph.toolbar hook point，用于可拖动工具栏
class ToggleConnectionsToolbarHook extends GraphToolbarHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'toggle_connections_toolbar_hook',
    name: 'Toggle Connections Toolbar Hook',
    version: '1.0.0',
    description: 'Provides toggle connections visibility button in graph toolbar',
  );

  @override
  HookPriority get priority => HookPriority.custom200;

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return const SizedBox.shrink();

    // 使用Consumer监听语言变化和图状态变化
    return Consumer<I18n>(
      // 监听 GraphBloc 状态以显示当前的连接线显示状态
      builder: (ctx, i18n, child) => BlocBuilder<GraphBloc, GraphState>(
          buildWhen: (previous, current) =>
              previous.viewState.showConnections != current.viewState.showConnections,
          builder: (ctx, state) {
            final showConnections = state.viewState.showConnections;

            return IconButton(
              icon: Icon(showConnections ? Icons.share : Icons.hide_source),
              onPressed: () => _toggleConnections(context),
              tooltip: i18n.t(showConnections ? 'Hide Connections' : 'Show Connections'),
            );
          },
        ),
    );
  }

  /// 切换连接线显示状态
  void _toggleConnections(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    // 从 BuildContext 读取 GraphBloc
    final graphBloc = buildContext.read<GraphBloc>();

    // 发送切换连接线事件
    graphBloc.add(const ViewToggleConnectionsEvent());
  }
}
