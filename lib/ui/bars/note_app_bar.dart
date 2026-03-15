import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/graph_bloc.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/graph_event.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/node_bloc.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/node_event.dart';
import '../../plugins/builtin_plugins/converter/ui/import_export_page.dart';
import '../pages/plugin_market_page.dart';
import '../dialogs/settings_dialog.dart';

/// 应用程序的顶部导航栏
class NoteAppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  const NoteAppBarWidget({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Node Graph Notebook'),
      actions: [
        // AI按钮
        IconButton(
          icon: const Icon(Icons.smart_toy),
          onPressed: () => _addAIAssistant(context),
          tooltip: 'AI Assistant',
        ),
        // 插件市场按钮
        IconButton(
          icon: const Icon(Icons.extension),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => const PluginMarketPage()),
            );
          },
          tooltip: 'Plugin Market',
        ),
        // 导入导出
        IconButton(
          icon: const Icon(Icons.import_export),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => const ImportExportPage()),
            );
          },
          tooltip: 'Import & Export',
        ),


        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => const SettingsDialog(),
            );
          },
          tooltip: 'Settings',
        ),
      ],
    );
  }

  void _addAIAssistant(BuildContext context) {
    final nodeBloc = BlocProvider.of<NodeBloc>(context);
    final graphBloc = BlocProvider.of<GraphBloc>(context);

    try {
      // 创建AI助手节点
      nodeBloc.add(const NodeCreateEvent(
        title: 'AI Assistant',
        content: 'Your AI assistant. Click to start a conversation!',
        metadata: {'isAI': true, 'character': 'assistant'}, 
      ));

      // 等待节点创建完成后添加到图中
      Future.delayed(const Duration(milliseconds: 500), () {
        final nodeState = nodeBloc.state;
        final aiNode = nodeState.nodes.lastWhere(
          (n) => n.metadata.containsKey('isAI') && n.metadata['isAI'] == true,
          orElse: () => nodeState.nodes.last,
        );

        // 添加到图中，位置稍微随机
        // 注意：graphBloc.add 中的 position 参数约定为节点中心位置
        // AI 节点默认使用 titleWithPreview 模式，尺寸为 250x120
        final nodeWidth = 250.0;
        final nodeHeight = 120.0;
        final topLeftX = 100 + (DateTime.now().millisecond % 300).toDouble();
        final topLeftY = 100 + (DateTime.now().microsecond % 300).toDouble();
        // 转换左上角位置为中心位置
        final centerX = topLeftX + nodeWidth / 2;
        final centerY = topLeftY + nodeHeight / 2;
        graphBloc.add(NodeAddEvent(
          aiNode.id,
          position: Offset(centerX, centerY),
        ));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Assistant added to the graph!')),
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add AI Assistant: $e')),
      );
    }
  }
}
