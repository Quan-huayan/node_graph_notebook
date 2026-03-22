import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/i18n.dart';
import '../../../../core/services/theme_service.dart';
import '../bloc/node_bloc.dart';
import '../bloc/node_event.dart';

/// 预定义图标选项
const List<Map<String, dynamic>> _iconOptions = [
  {'icon': null, 'name': 'None', 'iconData': Icons.close},
  {'icon': '⭐', 'name': 'Star', 'iconData': Icons.star},
  {'icon': '💡', 'name': 'Idea', 'iconData': Icons.lightbulb},
  {'icon': '🎯', 'name': 'Target', 'iconData': Icons.track_changes},
  {'icon': '📁', 'name': 'Folder', 'iconData': Icons.folder},
  {'icon': '📝', 'name': 'Note', 'iconData': Icons.note},
  {'icon': '🔧', 'name': 'Tool', 'iconData': Icons.build},
  {'icon': '🚀', 'name': 'Rocket', 'iconData': Icons.rocket_launch},
  {'icon': '✅', 'name': 'Check', 'iconData': Icons.check_circle},
  {'icon': '⚠️', 'name': 'Warning', 'iconData': Icons.warning},
  {'icon': '❓', 'name': 'Question', 'iconData': Icons.help},
  {'icon': '🔥', 'name': 'Fire', 'iconData': Icons.local_fire_department},
  {'icon': '💎', 'name': 'Gem', 'iconData': Icons.diamond},
  {'icon': '🌟', 'name': 'Sparkle', 'iconData': Icons.auto_awesome},
  {'icon': '📌', 'name': 'Pin', 'iconData': Icons.push_pin},
  {'icon': '🏷️', 'name': 'Tag', 'iconData': Icons.label},
  {'icon': '📊', 'name': 'Chart', 'iconData': Icons.bar_chart},
  {'icon': '🎨', 'name': 'Art', 'iconData': Icons.palette},
  {'icon': '🔬', 'name': 'Science', 'iconData': Icons.science},
  {'icon': '💻', 'name': 'Code', 'iconData': Icons.code},
  {'icon': '📚', 'name': 'Book', 'iconData': Icons.menu_book},
  {'icon': '🎓', 'name': 'Grad', 'iconData': Icons.school},
  {'icon': '💼', 'name': 'Work', 'iconData': Icons.work},
];

/// 节点图标选择对话框
/// 用于为节点选择图标/emoji
class NodeIconDialog extends StatefulWidget {
  /// 构造函数
  ///
  /// [node] - 要编辑图标的节点
  const NodeIconDialog({super.key, required this.node});

  /// 要编辑图标的节点
  final Node node;

  @override
  State<NodeIconDialog> createState() => _NodeIconDialogState();
}

class _NodeIconDialogState extends State<NodeIconDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = context.read<ThemeService>().themeData;
    final currentIcon = widget.node.metadata['icon'] as String?;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<I18n>(
      builder: (context, i18n, child) => AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: Text(i18n.t('Select Icon')),
          content: SizedBox(
            width: 350,
            height: 350,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _iconOptions.length,
              itemBuilder: (context, index) {
                final option = _iconOptions[index];
                final icon = option['icon'] as String?;
                final name = option['name'] as String;
                final isSelected = icon == currentIcon;

                return InkWell(
                  onTap: () => _selectIcon(icon),
                  borderRadius: BorderRadius.circular(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.2)
                          : theme.backgrounds.secondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Tooltip(
                      message: name,
                      child: Center(
                        child: isSelected
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    icon ?? '',
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                icon ?? '',
                                style: const TextStyle(fontSize: 24),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(i18n.t('Cancel')),
            ),
          ],
        ),
    );
  }

  /// 选择图标
  void _selectIcon(String? icon) {
    final i18n = I18n.of(context);
    final nodeBloc = context.read<NodeBloc>();

    // 更新节点元数据
    final newMetadata = Map<String, dynamic>.from(widget.node.metadata);
    if (icon == null) {
      newMetadata.remove('icon');
    } else {
      newMetadata['icon'] = icon;
    }

    nodeBloc.add(NodeUpdateEvent(widget.node.id, metadata: newMetadata));

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(icon != null ? '${i18n.t('Icon added:')} $icon' : i18n.t('Icon removed')),
      ),
    );
  }
}
