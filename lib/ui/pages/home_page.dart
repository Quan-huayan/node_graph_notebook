import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../dialogs/search_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../dialogs/create_node_dialog.dart';
import '../views/graph_view.dart';
import '../../core/services/export_service.dart';

/// 主页面
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Node Graph Notebook'),
        actions: [
          // 导入导出
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: () => _showImportMenu(context),
            tooltip: 'Import',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _showExportDialog(context),
            tooltip: 'Export',
          ),
          // 快速搜索
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const SearchDialog(),
              );
            },
            tooltip: 'Search',
          ),
          // 高级搜索
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const AdvancedSearchDialog(),
              );
            },
            tooltip: 'Advanced Search',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<NodeModel>().loadNodes();
              context.read<GraphModel>().refresh();
            },
            tooltip: 'Refresh',
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
      ),
      body: const GraphView(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateNodeDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showImportMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add),
              title: const Text('Import Markdown File'),
              subtitle: const Text('Import a single Markdown file'),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: 实现单文件导入
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Import feature - Coming soon!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Import Markdown Folder'),
              subtitle: const Text('Import multiple Markdown files'),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: 实现文件夹导入
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Batch import - Coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    final graphModel = context.read<GraphModel>();
    final nodeModel = context.read<NodeModel>();

    if (!graphModel.hasGraph) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No graph to export')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => ExportDialog(
        graph: graphModel.currentGraph!,
        nodes: nodeModel.nodes,
      ),
    );
  }

  void _showCreateNodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const CreateNodeDialog(),
    );
  }
}