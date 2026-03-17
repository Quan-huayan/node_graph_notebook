import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/execution/execution_engine.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../ui/bloc/ui_bloc.dart';
import '../bloc/graph_bloc.dart';
import '../bloc/node_bloc.dart';
import '../flame/flame.dart';

/// 图视图
class GraphView extends StatelessWidget {
  /// 创建图视图
  const GraphView({super.key});

  @override
  Widget build(BuildContext context) {
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
          state.error ?? nodeState.error ?? 'An unknown error occurred';
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
                'Something went wrong',
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
                onPressed: () async {
                  // 尝试重新初始化
                  // 注意：事件类可能需要重新定义
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
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
              'No Graph Yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Create your first graph to get started'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _createGraph(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Graph'),
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
                      const SnackBar(
                        content: Text('Node is already in the graph'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                  return;
                }

                try {
                  // 添加节点到图中，并设置其位置
                  // 注意：NodeAddEvent 和 NodeSelectEvent 可能需要重新定义
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to add node: $e')),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _createGraph(BuildContext context) async {
    try {
      // 注意：GraphCreateEvent 可能需要重新定义
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Graph creation functionality coming soon!'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
