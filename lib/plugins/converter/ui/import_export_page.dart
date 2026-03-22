import 'package:flutter/material.dart';
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
      builder: (context, i18n, child) => Scaffold(
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
                          onTap: () async {
                            // 图导入功能实现：
                            // 1. 使用 file_picker 选择 JSON 文件
                            // 2. 解析 JSON 文件验证图结构
                            // 3. 检查所有引用的节点是否存在
                            // 4. 提供"合并"或"替换"选项
                            // 5. 通过 GraphService 导入图数据
                            // 6. 刷新图视图显示导入的数据
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
                            onTap: () async {
                              // 图片导出功能实现：
                              // 1. 获取 Flame GameWidget 的引用
                              // 2. 使用 Boundary 计算图的边界
                              // 3. 创建 PictureRecorder 记录渲染
                              // 4. 将 Flame 组件渲染到 Canvas
                              // 5. 转换为 PNG 图片
                              // 6. 使用 file_picker 保存位置
                              // 7. 处理大图的缩放和分块
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
        ),
    );
  }
}
