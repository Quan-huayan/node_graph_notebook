import 'package:flutter/material.dart';
import '../../core/services/i18n.dart';

/// 快捷键帮助对话框
class ShortcutsDialog extends StatelessWidget {
  /// 创建快捷键帮助对话框
  const ShortcutsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);

    return AlertDialog(
      title: Text(i18n.t('Keyboard Shortcuts')),
      content: SizedBox(
        width: 500,
        child: ListView(
          shrinkWrap: true,
          children: [
            _ShortcutItem(
              shortcutKey: 'Ctrl + N',
              description: i18n.t('Create New Node'),
            ),
            _ShortcutItem(shortcutKey: 'Ctrl + S', description: i18n.t('Save')),
            _ShortcutItem(shortcutKey: 'Ctrl + Z', description: i18n.t('Undo')),
            _ShortcutItem(shortcutKey: 'Ctrl + Shift + Z', description: i18n.t('Redo')),
            _ShortcutItem(
              shortcutKey: 'Delete',
              description: i18n.t('Delete Selected Node'),
            ),
            _ShortcutItem(shortcutKey: 'Ctrl + F', description: i18n.t('Search')),
            _ShortcutItem(shortcutKey: 'Ctrl + E', description: i18n.t('Export')),
            const Divider(),
            _ShortcutItem(
              shortcutKey: 'Ctrl + 1',
              description: i18n.t('Force Directed Layout'),
            ),
            _ShortcutItem(
              shortcutKey: 'Ctrl + 2',
              description: i18n.t('Hierarchical Layout'),
            ),
            _ShortcutItem(
              shortcutKey: 'Ctrl + 3',
              description: i18n.t('Circular Layout'),
            ),
            _ShortcutItem(
              shortcutKey: 'Ctrl + 4',
              description: i18n.t('Concept Map Layout'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(i18n.t('Close')),
        ),
      ],
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  const _ShortcutItem({required this.shortcutKey, required this.description});

  final String shortcutKey;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              shortcutKey,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(description)),
        ],
      ),
    );
}