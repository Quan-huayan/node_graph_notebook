import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/settings_service.dart';
import '../models/models.dart';
import '../widgets/toolbar.dart';
import '../widgets/sidebar.dart';
import '../widgets/node_context_menu.dart';
import '../pages/markdown_editor_page.dart';
import '../../flame/flame.dart';


/// 图视图
class GraphView extends StatelessWidget {
  const GraphView({super.key});

  @override
  Widget build(BuildContext context) {
    final graphModel = context.watch<GraphModel>();
    final nodeModel = context.watch<NodeModel>();
    final uiModel = context.watch<UIModel>();
    final themeService = context.watch<ThemeService>();
    final settings = context.watch<SettingsService>();
    final theme = themeService.getThemeForMode(
      settings.themeMode,
      MediaQuery.of(context).platformBrightness,
    );

    if (graphModel.isLoading || nodeModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (graphModel.hasError || nodeModel.hasError) {
      return Center(
        child: Text(
          'Error: ${graphModel.error ?? nodeModel.error}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    if (!graphModel.hasGraph) {
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
        if (uiModel.isSidebarOpen)
          SizedBox(
            width: 300,
            child: Sidebar(
              graph: graphModel.currentGraph!,
              nodes: nodeModel.nodes,
            ),
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
                    graph: graphModel.currentGraph!,
                    nodes: graphModel.graphNodes,
                    connections: graphModel.connections,
                    viewConfig: graphModel.currentGraph!.viewConfig,
                    uiModel: uiModel,
                    theme: theme,
                    onTap: (node) {
                      context.read<NodeModel>().selectNode(node.id);
                    },
                    onDragEnd: (node, newPosition) async {
                      await context.read<NodeModel>().updateNode(
                        node.id,
                        position: newPosition,
                      );
                      // 刷新图数据
                      await graphModel.refresh();
                    },
                    onSecondaryTap: (node, position) {
                      showNodeContextMenu(
                        context,
                        node: node,
                        position: position,
                      );
                    },
                    onDoubleTap: (node) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => MarkdownEditorPage(node: node),
                        ),
                      );
                    },
                    onNodeDropped: (nodeId) async {
                      // 检查节点是否已经在图中
                      final alreadyInGraph = graphModel.graphNodes.any((n) => n.id == nodeId);
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

                      // 添加节点到图中
                      try {
                        await graphModel.addNode(nodeId);
                        // 可选：选择新添加的节点
                        context.read<NodeModel>().selectNode(nodeId);
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
                  child: Toolbar(graphModel: graphModel, uiModel: uiModel),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _createGraph(BuildContext context) async {
    final graphModel = context.read<GraphModel>();
    try {
      await graphModel.createGraph('My First Graph');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create graph: $e')),
        );
      }
    }
  }
}
