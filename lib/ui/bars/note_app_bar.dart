import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../pages/import_export_page.dart';
import '../pages/plugin_market_page.dart';
import '../dialogs/settings_dialog.dart';
import '../../bloc/blocs.dart';

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
        final randomX = 100 + (DateTime.now().millisecond % 300).toDouble();
        final randomY = 100 + (DateTime.now().microsecond % 300).toDouble();
        graphBloc.add(NodeAddEvent(
          aiNode.id,
          position: Offset(randomX, randomY),
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
