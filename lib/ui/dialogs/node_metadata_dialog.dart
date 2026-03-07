import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/models.dart';
import '../../core/services/theme_service.dart';
import '../../bloc/blocs.dart';

/// 节点元数据编辑对话框
/// 用于编辑节点的标题、颜色、文件夹属性等元数据
class NodeMetadataDialog extends StatefulWidget {
  const NodeMetadataDialog({
    super.key,
    required this.node,
  });

  final Node node;

  @override
  State<NodeMetadataDialog> createState() => _NodeMetadataDialogState();
}

class _NodeMetadataDialogState extends State<NodeMetadataDialog> {
  late TextEditingController _titleController;
  late bool _isFolder;
  String? _selectedColor;

  // 预定义颜色选项
  static const List<Map<String, dynamic>> _colorOptions = [
    {'color': null, 'name': 'Default', 'value': Colors.grey},
    {'color': '#FF6B6B', 'name': 'Red', 'value': Color(0xFFFF6B6B)},
    {'color': '#4ECDC4', 'name': 'Teal', 'value': Color(0xFF4ECDC4)},
    {'color': '#45B7D1', 'name': 'Blue', 'value': Color(0xFF45B7D1)},
    {'color': '#96CEB4', 'name': 'Green', 'value': Color(0xFF96CEB4)},
    {'color': '#FFEAA7', 'name': 'Yellow', 'value': Color(0xFFFFEAA7)},
    {'color': '#DDA0DD', 'name': 'Plum', 'value': Color(0xFFDDA0DD)},
    {'color': '#FF9F43', 'name': 'Orange', 'value': Color(0xFFFF9F43)},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.node.title);
    _isFolder = widget.node.isFolder;
    _selectedColor = widget.node.color;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<ThemeService>().themeData;

    return AlertDialog(
      backgroundColor: theme.backgrounds.primary,
      title: const Text('Edit Node Metadata'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题编辑
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // 文件夹属性
            CheckboxListTile(
              title: const Text('Is Folder'),
              subtitle: const Text('Folder nodes can contain other nodes'),
              value: _isFolder,
              onChanged: (value) {
                setState(() {
                  _isFolder = value ?? false;
                });
              },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),

            // 颜色选择
            const Text(
              'Color',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorOptions.map((colorOption) {
                final colorHex = colorOption['color'] as String?;
                final color = colorOption['value'] as Color;
                final isSelected = _selectedColor == colorHex;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedColor = colorHex;
                    });
                  },
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
                            : Colors.grey.withValues(alpha: 0.3),
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: _getContrastColor(color),
                            size: 20,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              _colorOptions
                      .firstWhere(
                        (opt) => opt['color'] == _selectedColor,
                        orElse: () => _colorOptions[0],
                      )['name']
                  as String,
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveMetadata,
          child: const Text('Save'),
        ),
      ],
    );
  }

  /// 计算对比色（用于图标）
  Color _getContrastColor(Color color) {
    // 计算亮度
    final luminance =
        (0.299 * (color.r * 255.0).round() +
            0.587 * (color.g * 255.0).round() +
            0.114 * (color.b * 255.0).round()) /
        255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// 保存元数据
  void _saveMetadata() {
    final newTitle = _titleController.text.trim();
    if (newTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }

    final nodeBloc = context.read<NodeBloc>();

    // 更新节点
    final newMetadata = Map<String, dynamic>.from(widget.node.metadata);
    newMetadata['isFolder'] = _isFolder;

    nodeBloc.add(NodeUpdateEvent(
      widget.node.id,
      title: newTitle,
      color: _selectedColor,
      metadata: newMetadata,
    ));

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Metadata updated')),
    );
  }
}
