import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/execution/execution_engine.dart';
import '../../../../core/services/i18n.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../ui/bloc/ui_bloc.dart';
import '../bloc/graph_bloc.dart';
import '../bloc/graph_event.dart';
import '../bloc/node_bloc.dart';
import '../flame/flame.dart';
import 'create_node_dialog.dart';
import 'draggable_toolbar.dart';

/// 图视图
class GraphView extends StatelessWidget {
  /// 创建图视图
  const GraphView({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final bloc = context.watch<GraphBloc>();
    final state = bloc.state;
    final nodeBloc = context.watch<NodeBloc>();
    final nodeState = nodeBloc.state;
    final uiBloc = context.watch<UIBloc>();
    final uiState = uiBloc.state;
    final themeService = context.watch<ThemeService>();
    final settings = context.watch<SettingsService>();
    final executionEngine = context.watch<ExecutionEngine?>();
    final theme = themeService.getThemeForMode(
      settings.themeMode,
      MediaQuery.of(context).platformBrightness,
    );

    if (state.isLoading || nodeState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.hasError || nodeState.hasError) {
      final error =
          state.error ?? nodeState.error ?? i18n.t('An unknown error occurred');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                i18n.t('Something went wrong'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // 重新初始化图
                  context.read<GraphBloc>().add(const GraphInitializeEvent());
                },
                icon: const Icon(Icons.refresh),
                label: Text(i18n.t('Try Again')),
              ),
            ],
          ),
        ),
      );
    }

    if (!state.hasGraph) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.graphic_eq,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              i18n.t('No Graph Yet'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(i18n.t('Create your first graph to get started')),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _createGraph(context),
              icon: const Icon(Icons.add),
              label: Text(i18n.t('Create Graph')),
            ),
          ],
        ),
      );
    }

    // 主内容区 - 占据剩余全部空间
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Flame 图渲染组件
          Positioned.fill(
            child: GraphFlameWidget(
              key: ValueKey(
                theme.backgrounds.canvas.toARGB32(),
              ), // 使用主题背景色作为 key，主题变化时重建
              uiState: uiState,
              theme: theme,
              executionEngine: executionEngine,
              onZoomChanged: (zoomLevel) {
                // Zoom 在 BLoC 中解决
              },
              onNodeDropped: (nodeId, position) async {
                // 检查节点是否已经在图中
                final alreadyInGraph = state.nodes.any(
                  (n) => n.id == nodeId,
                );
                if (alreadyInGraph) {
                  // 节点已经在图中，显示提示
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(i18n.t('Node is already in the graph')),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                  return;
                }

                try {
                  // 添加节点到图中并设置其位置
                  // 使用默认位置（屏幕中心）
                  final defaultPosition = Offset(
                    context.size?.width ?? 800 / 2,
                    context.size?.height ?? 600 / 2,
                  );

                  context.read<GraphBloc>().add(
                    NodeAddEvent(nodeId, position: defaultPosition),
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${i18n.t('Failed to add node:')} $e')),
                    );
                  }
                }
              },
            ),
          ),

          // 可拖动工具栏（新增，graph插件自包含）
          const DraggableToolbar(),

          // 固定在右下角的创建节点按钮
          const Positioned(
            right: 16,
            bottom: 16,
            child: _CreateNodeButton(),
          ),
        ],
      ),
    );
  }

  void _createGraph(BuildContext context) async {
    final i18n = I18n.of(context);
    final graphBloc = context.read<GraphBloc>();

    try {
      // 发送创建图事件，使用默认名称
      graphBloc.add(const GraphCreateEvent('My Graph'));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${i18n.t('Failed to create graph:')} $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

/// 创建节点按钮
///
/// 固定在图视图右下角的大按钮，用于快速创建节点
class _CreateNodeButton extends StatelessWidget {
  /// 构造函数
  const _CreateNodeButton();

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);

    return FloatingActionButton.extended(
      icon: const Icon(Icons.add, size: 28),
      label: Text(i18n.t('Create Node')),
      tooltip: i18n.t('Create Node'),
      onPressed: () => _showCreateNodeDialog(context),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      elevation: 6,
    );
  }

  /// 显示创建节点对话框
  void _showCreateNodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateNodeDialog(),
    );
  }
}
