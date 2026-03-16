import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/models.dart';
import '../bloc/graph_bloc.dart';
import '../bloc/graph_event.dart';
import '../bloc/node_bloc.dart';
import '../bloc/node_event.dart';
import 'node_icon_dialog.dart';
import 'node_metadata_dialog.dart';

/// 菜单操作类型
enum _MenuAction {
  // 显示模式
  titleOnly,
  compact,
  titleWithPreview,
  fullContent,
  // 编辑功能
  editMetadata,
  manageConnections,
  addIcon,
  changeColor,
  duplicate,
  // 节点操作
  focus,
  delete,
}

/// 节点右键菜单 - 用于调整节点显示模式和编辑节点
Future<void> showNodeContextMenu(
  BuildContext context, {
  required Node node,
  required Offset position,
}) async {
  final nodeBloc = context.read<NodeBloc>();
  final graphBloc = context.read<GraphBloc>();

  // 显示弹出菜单（position 已经是全局设备坐标）
  final selectedAction = await showMenu<_MenuAction?>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 1,
      position.dy + 1,
    ),
    items: [
      // === 显示模式 ===
      PopupMenuItem<_MenuAction>(
        value: _MenuAction.titleOnly,
        child: _buildMenuItem(
          icon: Icons.title,
          label: 'Title Only',
          isSelected: node.viewMode == NodeViewMode.titleOnly,
        ),
      ),
      PopupMenuItem<_MenuAction>(
        value: _MenuAction.compact,
        child: _buildMenuItem(
          icon: Icons.circle,
          label: 'Compact',
          isSelected: node.viewMode == NodeViewMode.compact,
        ),
      ),
      PopupMenuItem<_MenuAction>(
        value: _MenuAction.titleWithPreview,
        child: _buildMenuItem(
          icon: Icons.short_text,
          label: 'Title with Preview',
          isSelected: node.viewMode == NodeViewMode.titleWithPreview,
        ),
      ),
      PopupMenuItem<_MenuAction>(
        value: _MenuAction.fullContent,
        child: _buildMenuItem(
          icon: Icons.article,
          label: 'Full Content',
          isSelected: node.viewMode == NodeViewMode.fullContent,
        ),
      ),
      const PopupMenuDivider(),

      // === 编辑功能 ===
      const PopupMenuItem<_MenuAction>(
        value: _MenuAction.editMetadata,
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18),
            SizedBox(width: 12),
            Text('Edit Metadata'),
          ],
        ),
      ),
      const PopupMenuItem<_MenuAction>(
        value: _MenuAction.manageConnections,
        child: Row(
          children: [
            Icon(Icons.link, size: 18),
            SizedBox(width: 12),
            Text('Manage Connections'),
          ],
        ),
      ),
      const PopupMenuItem<_MenuAction>(
        value: _MenuAction.addIcon,
        child: Row(
          children: [
            Icon(Icons.emoji_emotions_outlined, size: 18),
            SizedBox(width: 12),
            Text('Add Icon'),
          ],
        ),
      ),
      const PopupMenuItem<_MenuAction>(
        value: _MenuAction.changeColor,
        child: Row(
          children: [
            Icon(Icons.palette, size: 18),
            SizedBox(width: 12),
            Text('Change Color'),
          ],
        ),
      ),
      const PopupMenuItem<_MenuAction>(
        value: _MenuAction.duplicate,
        child: Row(
          children: [
            Icon(Icons.copy, size: 18),
            SizedBox(width: 12),
            Text('Duplicate'),
          ],
        ),
      ),
      const PopupMenuDivider(),

      // === 节点操作 ===
      const PopupMenuItem<_MenuAction>(
        value: _MenuAction.focus,
        child: Row(
          children: [
            Icon(Icons.center_focus_strong, size: 18),
            SizedBox(width: 12),
            Text('Focus Node'),
          ],
        ),
      ),
      const PopupMenuDivider(),

      // === 危险操作 ===
      const PopupMenuItem<_MenuAction>(
        value: _MenuAction.delete,
        child: Row(
          children: [
            Icon(Icons.delete, color: Colors.red, size: 18),
            SizedBox(width: 12),
            Text('Delete'),
          ],
        ),
      ),
      const PopupMenuDivider(),

      // === 状态信息 ===
      PopupMenuItem<_MenuAction>(
        value: null,
        enabled: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Current: ${_getModeLabel(node.viewMode)}',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ),
    ],
    elevation: 8,
  );

  // 处理用户选择
  if (selectedAction == null) return;

  switch (selectedAction) {
    case _MenuAction.delete:
      await _handleDelete(context, node, graphBloc, nodeBloc);
      break;

    case _MenuAction.editMetadata:
      await _handleEditMetadata(context, node);
      break;

    case _MenuAction.addIcon:
      await _handleAddIcon(context, node);
      break;

    case _MenuAction.changeColor:
      await _handleChangeColor(context, node, nodeBloc);
      break;

    case _MenuAction.duplicate:
      await _handleDuplicate(context, node, nodeBloc);
      break;

    case _MenuAction.focus:
      _handleFocus(context, node);
      break;

    default:
      // 切换显示模式
      final newMode = _actionToViewMode(selectedAction);
      if (newMode != null && newMode != node.viewMode) {
        nodeBloc.add(NodeUpdateEvent(node.id, viewMode: newMode));
      }
  }
}

/// 将菜单操作转换为视图模式
NodeViewMode? _actionToViewMode(_MenuAction action) {
  switch (action) {
    case _MenuAction.titleOnly:
      return NodeViewMode.titleOnly;
    case _MenuAction.compact:
      return NodeViewMode.compact;
    case _MenuAction.titleWithPreview:
      return NodeViewMode.titleWithPreview;
    case _MenuAction.fullContent:
      return NodeViewMode.fullContent;
    default:
      return null;
  }
}

/// 构建单个菜单项
Widget _buildMenuItem({
  required IconData icon,
  required String label,
  required bool isSelected,
}) => Row(
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 12),
      Expanded(child: Text(label)),
      if (isSelected) const Icon(Icons.check, size: 18, color: Colors.blue),
    ],
  );

/// 获取显示模式的标签
String _getModeLabel(NodeViewMode mode) {
  switch (mode) {
    case NodeViewMode.titleOnly:
      return 'Title Only';
    case NodeViewMode.compact:
      return 'Compact';
    case NodeViewMode.titleWithPreview:
      return 'Title with Preview';
    case NodeViewMode.fullContent:
      return 'Full Content';
  }
}

/// 处理删除操作
Future<void> _handleDelete(
  BuildContext context,
  Node node,
  GraphBloc graphBloc,
  NodeBloc nodeBloc,
) async {
  // 确认删除
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
        title: const Text('Delete Node'),
        content: Text('Are you sure you want to delete "${node.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
  );

  if ((confirmed ?? false) && context.mounted) {
    try {
      // 再删除节点本身
      nodeBloc.add(NodeDeleteEvent(node.id));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted: ${node.title}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete node: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// 处理编辑元数据
Future<void> _handleEditMetadata(BuildContext context, Node node) async {
  await showDialog(
    context: context,
    builder: (context) => NodeMetadataDialog(node: node),
  );
}

/// 处理添加图标
Future<void> _handleAddIcon(BuildContext context, Node node) async {
  await showDialog(
    context: context,
    builder: (context) => NodeIconDialog(node: node),
  );
}

/// 处理更改颜色
Future<void> _handleChangeColor(
  BuildContext context,
  Node node,
  NodeBloc nodeBloc,
) async {
  // 快速颜色选择
  final colors = [
    null,
    '#FF6B6B',
    '#4ECDC4',
    '#45B7D1',
    '#96CEB4',
    '#FFEAA7',
    '#DDA0DD',
    '#FF9F43',
  ];

  final selectedColor = await showDialog<String?>(
    context: context,
    builder: (context) => AlertDialog(
        title: const Text('Select Color'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: colors.map((colorHex) {
                Color color = Colors.grey;
                if (colorHex != null) {
                  color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                }
                final isSelected = node.color == colorHex;

                return InkWell(
                  onTap: () => Navigator.pop(context, colorHex),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.withAlpha(76),
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
  );

  if (selectedColor != null && context.mounted) {
    nodeBloc.add(NodeUpdateEvent(node.id, color: selectedColor));
  }
}

/// 处理复制节点
Future<void> _handleDuplicate(
  BuildContext context,
  Node node,
  NodeBloc nodeBloc,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
        title: const Text('Duplicate Node'),
        content: Text('Create a copy of "${node.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Duplicate'),
          ),
        ],
      ),
  );

  if ((confirmed ?? false) && context.mounted) {
    // 创建副本，偏移位置
    final newPosition = Offset(node.position.dx + 50, node.position.dy + 50);

    // 生成新标题
    var newTitle = node.title;
    final match = RegExp(r'^(.+?)\s*\((\d+)\)$').firstMatch(newTitle);
    if (match != null) {
      final baseTitle = match.group(1)!;
      final count = int.parse(match.group(2)!) + 1;
      newTitle = '$baseTitle ($count)';
    } else {
      newTitle = '$newTitle (1)';
    }

    // 创建新节点事件
    nodeBloc.add(
      NodeCreateEvent(
        title: newTitle,
        content: node.content,
        position: newPosition,
        color: node.color,
        metadata: Map<String, dynamic>.from(node.metadata),
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Duplicated: $newTitle')));
    }
  }
}

/// 处理聚焦节点
void _handleFocus(BuildContext context, Node node) {
  // 发送聚焦事件到 GraphBloc
  // 这需要在 GraphBloc 中实现相应的处理逻辑
  context.read<GraphBloc>().add(FocusNodeEvent(node.id));

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Focusing on ${node.title}')));
  }
}

/// 空的 overlay widget，用于保持兼容性
class NodeContextMenuOverlay extends StatelessWidget {
  /// 构造函数
  ///
  /// [child] - 子组件
  const NodeContextMenuOverlay({super.key, required this.child});

  /// 子组件
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
