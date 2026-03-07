import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../ui/items/folder_item.dart';
import '../../core/models/models.dart';
import '../../bloc/blocs.dart';
import '../items/node_item.dart';

/// 文件夹树形视图
class FolderTreeView extends StatefulWidget {
  const FolderTreeView({
    super.key,
    required this.nodes,
    required this.folders,
    this.onNodeSelected,
  });

  final List<Node> nodes;
  final List<Node> folders;
  final Function(String? nodeId)? onNodeSelected;

  @override
  State<FolderTreeView> createState() => _FolderTreeViewState();
}

class _FolderTreeViewState extends State<FolderTreeView> {
  Set<String> _expandedFolders = {};
  String? _draggedNodeId;

  // 缓存计算结果以提高性能
  final Map<String, bool> _childFolderCache = {};

  @override
  void initState() {
    super.initState();
    // 预先展开所有顶层文件夹
    _expandedFolders = widget.folders.map((f) => f.id).toSet();
  }

  @override
  void didUpdateWidget(FolderTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当文件夹列表变化时，清空缓存
    if (oldWidget.folders != widget.folders || oldWidget.nodes != widget.nodes) {
      _childFolderCache.clear();
    }
  }

  /// 获取顶层文件夹（没有被其他文件夹包含的文件夹）
  List<Node> _getTopLevelFolders(List<Node> folders) {
    return folders.where((folder) {
      // 检查是否被其他文件夹包含
      return !folders.any((parent) {
        if (parent.id == folder.id) return false;
        final ref = parent.references[folder.id];
        return ref != null && ref.type == ReferenceType.contains;
      });
    }).toList();
  }

  /// 获取不在任何文件夹中的节点
  List<Node> _getRootNodes(List<Node> nodes, List<Node> folders) {
    // 从文件夹中获取所有被包含的节点ID
    final folderContainedIds = folders
        .expand((folder) => folder.references.keys)
        .toSet();

    return nodes.where((node) {
      return !folderContainedIds.contains(node.id);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // 使用 context.select 进行细粒度状态订阅，避免不必要的重建
    final nodeState = context.select((NodeBloc bloc) => bloc.state);

    // 从 NodeBloc 状态中获取最新的节点和文件夹
    final allNodes = nodeState.nodes;
    final folders = allNodes.where((n) => n.isFolder).toList();
    final nodes = allNodes.where((n) => !n.isFolder).toList();

    final rootNodes = _getRootNodes(nodes, folders);
    final topLevelFolders = _getTopLevelFolders(folders);
    final allNodesList = [...nodes, ...folders];

    if (rootNodes.isEmpty && topLevelFolders.isEmpty) {
      return const Center(child: Text('No nodes yet'));
    }

    return ListView(
      children: [
        // 顶层文件夹列表
        ...topLevelFolders.map((folder) => FolderItem(
          folder: folder,
          allNodes: allNodesList,
          level: 0,
          expandedFolders: _expandedFolders,
          onExpandedFoldersChanged: (folders) {
            setState(() {
              _expandedFolders = folders;
            });
          },
          draggedNodeId: _draggedNodeId,
          onDragStarted: (nodeId) {
            setState(() {
              _draggedNodeId = nodeId;
            });
          },
          onDragEnd: (details) {
            setState(() {
              _draggedNodeId = null;
            });
          },
          onNodeSelected: widget.onNodeSelected,
        )),

        // 分隔线
        if (topLevelFolders.isNotEmpty && rootNodes.isNotEmpty)
          const Divider(height: 32),

        // 根节点列表
        ...rootNodes.map((node) => NodeItem(
          node: node,
          onNodeSelected: widget.onNodeSelected,
          draggedNodeId: _draggedNodeId,
          onDragStarted: (nodeId) {
            setState(() {
              _draggedNodeId = nodeId;
            });
          },
          onDragEnd: (details) {
            setState(() {
              _draggedNodeId = null;
            });
          },
        )),
      ],
    );
  }
}


