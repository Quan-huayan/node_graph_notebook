import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/theme_service.dart';
import '../../graph/bloc/node_bloc.dart';
import '../../graph/bloc/node_event.dart';

/// 显示文件夹选择器对话框
///
/// 用于选择将节点移动到哪个文件夹
///
/// [context] 构建上下文
/// [node] 要移动的节点
/// [folders] 可选的文件夹列表
void showFolderSelector(BuildContext context, Node node, List<Node> folders) {
  final theme = context.read<ThemeService>().themeData;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: theme.backgrounds.primary,
      title: const Text('Select Folder'),
      content: SizedBox(
        width: 300,
        height: 300,
        child: ListView.builder(
          itemCount: folders.length,
          itemBuilder: (ctx, i) {
            final folder = folders[i];
            return ListTile(
              leading: Icon(Icons.folder, color: theme.nodes.folderPrimary),
              title: Text(folder.title),
              onTap: () async {
                Navigator.pop(ctx);
                // 从旧文件夹移除
                final oldParent = _getParentFolder(node, context);
                if (oldParent != null) {
                  await _removeFromFolder(node, oldParent, context);
                }
                // 添加到新文件夹
                await _addToFolder(node, folder, context);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

/// 从文件夹中移除节点
Future<void> _removeFromFolder(
  Node node,
  Node folder,
  BuildContext context,
) async {
  final nodeBloc = context.read<NodeBloc>();

  final newReferences = Map<String, NodeReference>.from(folder.references)
  ..remove(node.id);

  final updatedFolder = folder.copyWith(references: newReferences);
  nodeBloc.add(NodeReplaceEvent(updatedFolder));
}

/// 将节点添加到文件夹
Future<void> _addToFolder(Node node, Node folder, BuildContext context) async {
  final nodeBloc = context.read<NodeBloc>();
  final allNodes = nodeBloc.state.nodes;

  // 检测循环 contains 关系
  if (_hasCircularContains(node, folder, allNodes)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot create circular folder structure'),
        ),
      );
    }
    return;
  }

  // 创建新的引用（使用通用关系类型）
  final newReferences = Map<String, NodeReference>.from(folder.references);
  newReferences[node.id] = NodeReference(
    nodeId: node.id,
    properties: {'type': 'relatesTo'},
  );

  final updatedFolder = folder.copyWith(references: newReferences);
  nodeBloc.add(NodeReplaceEvent(updatedFolder));
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

/// 检查 folder 是否是 parentFolder 的子文件夹
bool _isChildFolder(Node folder, Node parentFolder, List<Node> allNodes) {
  // 检查 folder 是否直接被 parentFolder 引用
  if (parentFolder.references.containsKey(folder.id)) {
    return true;
  }

  // 递归检查 parentFolder 的所有直接子文件夹
  for (final entry in parentFolder.references.entries) {
    final childNode = allNodes.firstWhere(
      (n) => n.id == entry.key,
      orElse: () => parentFolder,
    );
    if (childNode.id.isNotEmpty &&
        childNode.isFolder &&
        _isChildFolder(folder, childNode, allNodes)) {
      return true;
    }
  }

  return false;
}

/// 获取节点的父文件夹
Node? _getParentFolder(Node node, BuildContext context) {
  final nodeBloc = context.read<NodeBloc>();
  final folders = nodeBloc.state.nodes.where((n) => n.isFolder).toList();
  for (final folder in folders) {
    // 找到第一个引用该节点的文件夹
    if (folder.references.containsKey(node.id)) {
      return folder;
    }
  }
  return null;
}
