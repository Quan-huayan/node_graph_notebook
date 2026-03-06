import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/blocs.dart';
import '../dialogs/export_dialog.dart';
import '../dialogs/import_markdown_dialog.dart';
import '../dialogs/export_markdown_dialog.dart';
import '../dialogs/batch_operation_dialog.dart';

/// 导入导出页面
class ImportExportPage extends StatelessWidget {
  const ImportExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final graphBloc = context.watch<GraphBloc>();
    final nodeBloc = context.watch<NodeBloc>();
    final graphState = graphBloc.state;
    final nodeState = nodeBloc.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import & Export'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 导入部分
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.note_add),
                      title: const Text('Import Markdown File'),
                      subtitle: const Text('Import a single Markdown file'),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => const ImportMarkdownDialog(),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.folder_open),
                      title: const Text('Batch Import'),
                      subtitle: const Text('Import multiple Markdown files'),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => const BatchOperationDialog(),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.file_upload),
                      title: const Text('Import Graph'),
                      subtitle: const Text('Import a saved graph file'),
                      onTap: () {
                        // TODO: 实现图导入
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Graph import feature - Coming soon!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 导出部分
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Export',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!graphState.hasGraph) ...[
                      const Text(
                        'No graph available to export',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ] else ...[
                      ListTile(
                        leading: const Icon(Icons.file_download),
                        title: const Text('Export Graph'),
                        subtitle: const Text('Export the current graph as JSON'),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => ExportDialog(
                              graph: graphState.graph,
                              nodes: nodeState.nodes,
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.document_scanner),
                        title: const Text('Export as Markdown'),
                        subtitle: const Text('Export all nodes as Markdown files'),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => const ExportMarkdownDialog(),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.image),
                        title: const Text('Export as Image'),
                        subtitle: const Text('Export graph as PNG image'),
                        onTap: () {
                          // TODO: 实现图片导出
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Image export feature - Coming soon!')),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
