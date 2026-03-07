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

  /// 获取文件夹中的直接子节点
  List<Node> _getFolderChildren(Node folder, List<Node> nodes) {
    return nodes.where((node) {
      final ref = folder.references[node.id];
      return ref != null && ref.type == ReferenceType.contains;
    }).toList();
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

  /// 检测是否存在循环 contains 关系
  bool _hasCircularContains(Node node, Node folder, List<Node> allNodes) {
    // 检查是否将节点拖拽到自身
    if (node.id == folder.id) {
      return true;
    }

    // 检查是否将文件夹拖拽到其子文件夹中
    if (node.isFolder) {
      // 检查目标文件夹是否是当前节点的子文件夹
      return _isChildFolder(folder, node, allNodes);
    }

    return false;
  }

  /// 检查 folder 是否是 parentFolder 的子文件夹（优化版本，使用缓存避免重复计算）
  bool _isChildFolder(Node folder, Node parentFolder, List<Node> allNodes) {
    // 创建缓存键
    final cacheKey = '${folder.id}_${parentFolder.id}';

    // 检查缓存
    if (_childFolderCache.containsKey(cacheKey)) {
      return _childFolderCache[cacheKey]!;
    }

    // 使用迭代替代递归，提高性能
    final result = _isChildFolderIterative(folder, parentFolder, allNodes);

    // 缓存结果
    _childFolderCache[cacheKey] = result;

    return result;
  }

  /// 使用迭代方式检查子文件夹关系（避免递归栈溢出）
  bool _isChildFolderIterative(Node folder, Node parentFolder, List<Node> allNodes) {
    // 使用队列进行广度优先搜索
    final queue = <Node>[parentFolder];
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);

      // 避免循环
      if (visited.contains(current.id)) {
        continue;
      }
      visited.add(current.id);

      // 检查是否找到目标文件夹
      if (current.references.containsKey(folder.id)) {
        final ref = current.references[folder.id];
        if (ref != null && ref.type == ReferenceType.contains) {
          return true;
        }
      }

      // 将所有子文件夹加入队列
      for (final entry in current.references.entries) {
        if (entry.value.type == ReferenceType.contains) {
          final childNode = allNodes.firstWhere(
            (n) => n.id == entry.key,
          );
          if (childNode.id.isNotEmpty && childNode.isFolder) {
            queue.add(childNode);
          }
        }
      }
    }

    return false;
  }

  /// 将节点添加到文件夹
  Future<void> _addToFolder(Node node, Node folder) async {
    final nodeBloc = context.read<NodeBloc>();
    final allNodes = nodeBloc.state.nodes;

    // 检测循环 contains 关系
    if (_hasCircularContains(node, folder, allNodes)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot create circular folder structure')),
        );
      }
      return;
    }

    // 从旧文件夹中移除节点
    final oldParent = _getParentFolder(node);
    if (oldParent != null) {
      await _removeFromFolder(node, oldParent);
    }

    // 创建新的引用
    final newReferences = Map<String, NodeReference>.from(folder.references);
    newReferences[node.id] = NodeReference(
      nodeId: node.id,
      type: ReferenceType.contains,
    );

    final updatedFolder = folder.copyWith(references: newReferences);
    nodeBloc.add(NodeReplaceEvent(updatedFolder));

    if (mounted) {
      setState(() {
        _expandedFolders.add(folder.id);
      });
    }
  }

  /// 从文件夹中移除节点
  Future<void> _removeFromFolder(Node node, Node folder) async {
    final nodeBloc = context.read<NodeBloc>();

    final newReferences = Map<String, NodeReference>.from(folder.references);
    newReferences.remove(node.id);

    final updatedFolder = folder.copyWith(references: newReferences);
    nodeBloc.add(NodeReplaceEvent(updatedFolder));
  }

  /// 获取节点的父文件夹
  Node? _getParentFolder(Node node) {
    final nodeBloc = context.read<NodeBloc>();
    final folders = nodeBloc.state.nodes.where((n) => n.isFolder).toList();
    for (final folder in folders) {
      final ref = folder.references[node.id];
      if (ref != null && ref.type == ReferenceType.contains) {
        return folder;
      }
    }
    return null;
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


