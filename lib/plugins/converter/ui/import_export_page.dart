import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/i18n.dart';
import '../../graph/bloc/graph_bloc.dart';
import '../../graph/bloc/node_bloc.dart';
import '../../graph/ui/batch_operation_dialog.dart';
import 'export_dialog.dart';
import 'export_markdown_dialog.dart';
import 'import_markdown_dialog.dart';

/// 导入导出页面
class ImportExportPage extends StatelessWidget {
  /// 导入导出页面构造函数
  const ImportExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final graphBloc = context.watch<GraphBloc>();
    final nodeBloc = context.watch<NodeBloc>();
    final graphState = graphBloc.state;
    final nodeState = nodeBloc.state;

    return Consumer<I18n>(
      builder: (context, i18n, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(i18n.t('Import & Export')),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 导入部分
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18n.t('Import'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.note_add),
                          title: Text(i18n.t('Import Markdown File')),
                          subtitle: Text(i18n.t('Import a single Markdown file')),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => const ImportMarkdownDialog(),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.folder_open),
                          title: Text(i18n.t('Batch Import')),
                          subtitle: Text(i18n.t('Import multiple Markdown files')),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => const BatchOperationDialog(),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.file_upload),
                          title: Text(i18n.t('Import Graph')),
                          subtitle: Text(i18n.t('Import a saved graph file')),
                          onTap: () {
                            // TODO: 实现图导入
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  i18n.t('Graph import feature - Coming soon!'),
                                ),
                              ),
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18n.t('Export'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!graphState.hasGraph) ...[
                          Text(
                            i18n.t('No graph available to export'),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ] else ...[
                          ListTile(
                            leading: const Icon(Icons.file_download),
                            title: Text(i18n.t('Export Graph')),
                            subtitle: Text(
                              i18n.t('Export the current graph as JSON'),
                            ),
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
                            title: Text(i18n.t('Export as Markdown')),
                            subtitle: Text(
                              i18n.t('Export all nodes as Markdown files'),
                            ),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => const ExportMarkdownDialog(),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.image),
                            title: Text(i18n.t('Export as Image')),
                            subtitle: Text(i18n.t('Export graph as PNG image')),
                            onTap: () {
                              // TODO: 实现图片导出
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    i18n.t('Image export feature - Coming soon!'),
                                  ),
                                ),
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
      },
    );
  }
}
