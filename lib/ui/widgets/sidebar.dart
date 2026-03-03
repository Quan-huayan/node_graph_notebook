import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../models/models.dart';
import '../views/folder_tree_view.dart';

/// 侧边栏
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.graph,
    required this.nodes,
  });

  final Graph graph;
  final List<Node> nodes;

  @override
  Widget build(BuildContext context) {
    // 分离文件夹和普通节点
    final folders = nodes.where((n) => n.isFolder).toList();
    final regularNodes = nodes.where((n) => !n.isFolder).toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 标题栏
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      graph.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 创建文件夹按钮
                  IconButton(
                    icon: const Icon(Icons.create_new_folder),
                    tooltip: 'Create New Folder',
                    onPressed: () => _createFolder(context),
                  ),
                ],
              ),
            ),
          ),

          // 节点列表（文件夹树形视图）
          Expanded(
            child: FolderTreeView(
              nodes: regularNodes,
              folders: folders,
            ),
          ),
        ],
      ),
    );
  }

  void _createFolder(BuildContext context) async {
    final nodeModel = context.read<NodeModel>();
    final graphModel = context.read<GraphModel>();

    // 创建一个概念节点作为文件夹
    final folder = await nodeModel.createNode(
      type: NodeType.concept,
      title: 'New Folder',
      content: 'A folder to organize your notes',
    );

    // 标记为文件夹
    final updatedFolder = folder.copyWith(
      metadata: {...folder.metadata, 'isFolder': true},
    );
    await nodeModel.replaceNode(updatedFolder);

    // 注意：文件夹不自动添加到节点图中，它只是一个组织工具

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New folder created')),
      );
    }
  }
}

/// Node 扩展 - 检查是否为文件夹
extension NodeExtension on Node {
  bool get isFolder {
    return metadata['isFolder'] == true ||
        (metadata['isFolder'] is bool && metadata['isFolder'] as bool);
  }
}