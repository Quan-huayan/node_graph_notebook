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
