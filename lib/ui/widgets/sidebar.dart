import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../models/models.dart';
import '../views/folder_tree_view.dart';

/// 侧边栏
class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.graph,
    required this.nodes,
  });

  final Graph graph;
  final List<Node> nodes;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final FocusNode _focusNode = FocusNode();
  String? _selectedNodeId;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.delete &&
          _selectedNodeId != null) {
        _deleteSelectedNode();
      }
    }
  }

  Future<void> _deleteSelectedNode() async {
    if (_selectedNodeId == null) return;

    final nodeModel = context.read<NodeModel>();
    final graphModel = context.read<GraphModel>();
    final node = nodeModel.nodes.firstWhere(
      (n) => n.id == _selectedNodeId,
      orElse: () => nodeModel.nodes.first,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delete Node'),
          content: Text('Are you sure you want to delete "${node.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      if (graphModel.hasGraph) {
        await graphModel.removeNode(node.id);
      }
      await nodeModel.deleteNode(node.id);
      setState(() {
        _selectedNodeId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 分离文件夹和普通节点
    final folders = widget.nodes.where((n) => n.isFolder).toList();
    final regularNodes = widget.nodes.where((n) => !n.isFolder).toList();

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyPress,
      child: DecoratedBox(
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
                        widget.graph.name,
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
                onNodeSelected: (nodeId) {
                  setState(() {
                    _selectedNodeId = nodeId;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createFolder(BuildContext context) async {
    final nodeModel = context.read<NodeModel>();

    // 创建一个内容节点作为文件夹
    final folder = await nodeModel.createNode(
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