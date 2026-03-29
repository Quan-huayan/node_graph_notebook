import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_priority.dart';
import '../../../core/services/i18n.dart';
import 'bloc/graph_bloc.dart';
import 'bloc/graph_event.dart';

/// 刷新图工具栏钩子
///
/// 提供刷新当前图的功能，重新加载图数据和节点位置
/// 注册到 graph.toolbar hook point，用于可拖动工具栏
class RefreshGraphToolbarHook extends GraphToolbarHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'refresh_graph_toolbar_hook',
    name: 'Refresh Graph Toolbar Hook',
    version: '1.0.0',
    description: 'Provides refresh graph button in graph toolbar',
  );

  @override
  HookPriority get priority => HookPriority.custom250;

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return const SizedBox.shrink();

    // 使用Consumer监听语言变化
    return Consumer<I18n>(
      builder: (ctx, i18n, child) => IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: () => _refreshGraph(context),
      ),
    );
  }

  /// 刷新当前图
  void _refreshGraph(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    // 从 BuildContext 读取 GraphBloc
    final graphBloc = buildContext.read<GraphBloc>();

    // 获取当前图状态
    final currentState = graphBloc.state;
    if (currentState.isLoaded && currentState.hasGraph) {
      // 重新加载当前图
      graphBloc.add(GraphLoadEvent(currentState.graph.id));
    }
  }
}
