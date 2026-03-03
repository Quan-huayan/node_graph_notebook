import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 快捷键管理器
class ShortcutManager {
  ShortcutManager();

  final Map<ShortcutActivator, VoidCallback> _shortcuts = {};

  /// 注册快捷键
  void register(ShortcutActivator activator, VoidCallback callback) {
    _shortcuts[activator] = callback;
  }

  /// 注销快捷键
  void unregister(ShortcutActivator activator) {
    _shortcuts.remove(activator);
  }

  /// 处理按键事件
  bool handleKeyPress(KeyEvent event) {
    for (final entry in _shortcuts.entries) {
      final activator = entry.key;
      if (activator.accepts(event, ServicesBinding.instance.keyboard)) {
        entry.value();
        return true;
      }
    }
    return false;
  }
}

/// 快捷键配置
class AppShortcuts {
  static final createNode = const SingleActivator(
    LogicalKeyboardKey.keyN,
  );

  static final save = const SingleActivator(
    LogicalKeyboardKey.keyS,
    control: true,
  );

  static final undo = const SingleActivator(
    LogicalKeyboardKey.keyZ,
    control: true,
  );

  static final redo = const SingleActivator(
    LogicalKeyboardKey.keyZ,
    control: true,
    shift: true,
  );

  static final delete = const SingleActivator(
    LogicalKeyboardKey.delete,
  );

  static final search = const SingleActivator(
    LogicalKeyboardKey.keyF,
    control: true,
  );

  static final export = const SingleActivator(
    LogicalKeyboardKey.keyE,
    control: true,
  );
}

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
