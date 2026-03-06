import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/models.dart';
import '../blocs/blocs.dart';

/// 菜单操作类型
enum _MenuAction {
  titleOnly,
  compact,
  titleWithPreview,
  fullContent,
  editMetadata,
  manageConnections,
  addIcon,
  delete,
}

/// 节点右键菜单 - 用于调整节点显示模式和删除节点
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
            Icon(Icons.image, size: 18),
            SizedBox(width: 12),
            Text('Add Icon'),
          ],
        ),
      ),
      const PopupMenuDivider(),
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
      PopupMenuItem<_MenuAction>(
        value: null,
        enabled: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Current: ${_getModeLabel(node.viewMode)}',
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    ],
    elevation: 8.0,
  );

  // 处理用户选择
  if (selectedAction == null) return;

  if (selectedAction == _MenuAction.delete) {
    // 删除操作
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

    if (confirmed == true && context.mounted) {
      final state = graphBloc.state;
      if (state.hasGraph) {
        graphBloc.add(NodeDeleteEvent(node.id));
      }
      nodeBloc.add(NodeDeleteEvent(node.id));
    }
  } else if (selectedAction == _MenuAction.editMetadata) {
    // 编辑元数据
    // TODO: 实现编辑元数据的对话框
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit Metadata feature - Coming soon!')),
    );
  } else if (selectedAction == _MenuAction.manageConnections) {
    // 管理连接
    // TODO: 实现管理连接的对话框
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Manage Connections feature - Coming soon!')),
    );
  } else if (selectedAction == _MenuAction.addIcon) {
    // 添加图标
    // TODO: 实现添加图标的功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add Icon feature - Coming soon!')),
    );
  } else {
    // 切换显示模式
    final newMode = _actionToViewMode(selectedAction);
    if (newMode != null && newMode != node.viewMode) {
      nodeBloc.add(NodeUpdateEvent(
        node.id,
        viewMode: newMode,
      ));
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
}) {
  return Row(
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 12),
      Expanded(child: Text(label)),
      if (isSelected)
        const Icon(
          Icons.check,
          size: 18,
          color: Colors.blue,
        ),
    ],
  );
}

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

/// 空的 overlay widget，用于保持兼容性
class NodeContextMenuOverlay extends StatelessWidget {
  const NodeContextMenuOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
