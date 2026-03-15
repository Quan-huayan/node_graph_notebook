import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/blocs.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/settings_service.dart';
import '../bars/core_toolbar.dart';
import '../../core/commands/command_bus.dart';
import '../../core/events/app_events.dart';
import '../bars/sidebar.dart';
import '../../flame/flame.dart';


/// 图视图
class GraphView extends StatelessWidget {
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
    final theme = themeService.getThemeForMode(
      settings.themeMode,
      MediaQuery.of(context).platformBrightness,
    );

    if (state.isLoading || nodeState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.hasError || nodeState.hasError) {
      final error = state.error ?? nodeState.error ?? 'An unknown error occurred';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
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
                  bloc.add(const ErrorClearEvent());
                  bloc.add(const GraphInitializeEvent());
                  nodeBloc.add(const NodeLoadEvent());
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

    return Row(
      children: [
        // 侧边栏
        if (uiState.isSidebarOpen)
          Row(
            children: [
              SizedBox(
                width: uiState.sidebarWidth,
                child: Sidebar(
                  graph: state.graph,
                  nodes: nodeState.nodes,
                ),
              ),
              // 侧边栏宽度调整把手
              GestureDetector(
                onPanUpdate: (details) {
                  final newWidth = uiState.sidebarWidth + details.delta.dx;
                  context.read<UIBloc>().add(UISetSidebarWidthEvent(newWidth));
                },
                child: Container(
                  width: 5,
                  color: Colors.transparent,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: Container(
                      width: 1,
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
              ),
            ],
          ),

        // 主内容区 - 占据剩余全部空间
        Expanded(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Flame 图渲染组件
                Positioned.fill(
                  child: GraphFlameWidget(
                    key: ValueKey(theme.backgrounds.canvas.toARGB32()), // 使用主题背景色作为 key，主题变化时重建
                    uiState: uiState,
                    theme: theme,
                    onZoomChanged: (zoomLevel) {
                      // Zoom 在 BLoC 中解决
                    },
                    onNodeDropped: (nodeId, position) async {
                      // 检查节点是否已经在图中
                      final alreadyInGraph = state.nodes.any((n) => n.id == nodeId);
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

                      try
                      {
                        // 添加节点到图中，并设置其位置
                        bloc.add(NodeAddEvent(nodeId, position: position));
                        // 选择新添加的节点
                        bloc.add(NodeSelectEvent(nodeId));
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

                // 工具栏
                Positioned(
                  top: 16,
                  right: 16,
                  child: CoreToolbar(
                    uiState: uiState,
                    commandBus: context.read<CommandBus>(),
                    eventBus: context.read<AppEventBus>(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _createGraph(BuildContext context) async {
    final bloc = context.read<GraphBloc>();
    try {
      bloc.add(const GraphCreateEvent('My First Graph'));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FileSystemException
                  ? 'Cannot create graph: Data folder is missing. Please restart the application.'
                  : 'Failed to create graph: $e',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
