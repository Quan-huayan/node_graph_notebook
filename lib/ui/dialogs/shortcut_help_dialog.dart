import 'package:flutter/material.dart';

/// 快捷键帮助对话框
class ShortcutsDialog extends StatelessWidget {
  const ShortcutsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Keyboard Shortcuts'),
      content: SizedBox(
        width: 500,
        child: ListView(
          shrinkWrap: true,
          children: const [
            _ShortcutItem(
              shortcutKey: 'Ctrl + N',
              description: 'Create New Node',
            ),
            _ShortcutItem(
              shortcutKey: 'Ctrl + S',
              description: 'Save',
            ),
            _ShortcutItem(
              shortcutKey: 'Ctrl + Z',
              description: 'Undo',
            ),
            _ShortcutItem(
              shortcutKey: 'Ctrl + Shift + Z',
              description: 'Redo',
            ),
            _ShortcutItem(
              shortcutKey: 'Delete',
              description: 'Delete Selected Node',
            ),
            _ShortcutItem(
              shortcutKey: 'Ctrl + F',
              description: 'Search',
            ),
            _ShortcutItem(
              shortcutKey: 'Ctrl + E',
              description: 'Export',
            ),
            Divider(),
            _ShortcutItem(
              shortcutKey: 'Ctrl + 1',
              description: 'Force Directed Layout',
            ),
            _ShortcutItem(
              shortcutKey: 'Ctrl + 2',
              description: 'Hierarchical Layout',
            ),
            _ShortcutItem(
              shortcutKey: 'Ctrl + 3',
              description: 'Circular Layout',
            ),
            _ShortcutItem(
              shortcutKey: 'Ctrl + 4',
              description: 'Concept Map Layout',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  const _ShortcutItem({
    required this.shortcutKey,
    required this.description,
  });

  final String shortcutKey;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          Expanded(
            child: Text(description),
          ),
        ],
      ),
    );
  }
}
