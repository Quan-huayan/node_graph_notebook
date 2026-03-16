import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 快捷键管理器
class ShortcutManager {
  /// 创建快捷键管理器
  ShortcutManager();

  /// 快捷键映射
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
  /// 创建节点快捷键 (N)
  static const createNode = SingleActivator(LogicalKeyboardKey.keyN);

  /// 保存快捷键 (Ctrl+S)
  static const save = SingleActivator(
    LogicalKeyboardKey.keyS,
    control: true,
  );

  /// 撤销快捷键 (Ctrl+Z)
  static const undo = SingleActivator(
    LogicalKeyboardKey.keyZ,
    control: true,
  );

  /// 重做快捷键 (Ctrl+Shift+Z)
  static const redo = SingleActivator(
    LogicalKeyboardKey.keyZ,
    control: true,
    shift: true,
  );

  /// 删除快捷键 (Delete)
  static const delete = SingleActivator(LogicalKeyboardKey.delete);

  /// 搜索快捷键 (Ctrl+F)
  static const search = SingleActivator(
    LogicalKeyboardKey.keyF,
    control: true,
  );

  /// 导出快捷键 (Ctrl+E)
  static const export = SingleActivator(
    LogicalKeyboardKey.keyE,
    control: true,
  );
}
