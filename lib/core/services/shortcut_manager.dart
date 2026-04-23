import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 全局快捷键管理器
///
/// 提供应用级别的快捷键注册和处理功能，支持动态注册和注销快捷键。
///
/// ## 使用方式
///
/// ```dart
/// // 1. 创建管理器实例
/// final manager = ShortcutManager();
///
/// // 2. 注册快捷键
/// manager.register(
///   const SingleActivator(LogicalKeyboardKey.keyN, control: true),
///   () => print('Ctrl+N pressed'),
/// );
///
/// // 3. 在 FocusScope 中处理按键事件
/// FocusScope(
///   onKeyEvent: (node, event) {
///     if (manager.handleKeyPress(event)) {
///       return KeyEventResult.handled;
///     }
///     return KeyEventResult.ignored;
///   },
///   child: // ... your UI
/// )
///
/// // 4. 不再需要时注销快捷键
/// manager.unregister(activator);
/// ```
///
/// ## 架构说明
///
/// - 使用 Map 存储 `ShortcutActivator` 到回调的映射
/// - `handleKeyPress` 遍历所有注册的快捷键，找到匹配的触发器并执行回调
/// - 返回 `true` 表示事件已处理，`false` 表示未找到匹配的快捷键
/// - 支持任意 `ShortcutActivator` 实现（SingleActivator, LogicalKeySet 等）
class ShortcutManager {
  /// 创建快捷键管理器
  ShortcutManager();

  /// 快捷键映射表
  ///
  /// 键：快捷键触发器（如 SingleActivator, LogicalKeySet）
  /// 值：按键触发时执行的回调函数
  final Map<ShortcutActivator, VoidCallback> _shortcuts = {};

  /// 注册快捷键
  ///
  /// 如果相同的 [activator] 已存在，会覆盖之前的回调。
  ///
  /// [activator] 快捷键触发器，定义按键组合（如 Ctrl+S）
  /// [callback] 按键触发时执行的回调函数
  ///
  /// ## 示例
  /// ```dart
  /// // 注册单键快捷键
  /// manager.register(
  ///   const SingleActivator(LogicalKeyboardKey.keyN),
  ///   () => createNewNode(),
  /// );
  ///
  /// // 注册组合键快捷键
  /// manager.register(
  ///   const SingleActivator(LogicalKeyboardKey.keyS, control: true),
  ///   () => saveCurrentFile(),
  /// );
  /// ```
  void register(ShortcutActivator activator, VoidCallback callback) {
    _shortcuts[activator] = callback;
  }

  /// 注销快捷键
  ///
  /// 从管理器中移除指定的快捷键触发器。
  ///
  /// [activator] 要注销的快捷键触发器
  ///
  /// 如果触发器不存在，此方法不执行任何操作。
  void unregister(ShortcutActivator activator) {
    _shortcuts.remove(activator);
  }

  /// 处理按键事件
  ///
  /// 遍历所有注册的快捷键，检查是否有匹配的触发器。
  /// 如果找到匹配的快捷键，执行其回调并返回 `true`。
  ///
  /// [event] 按键事件对象
  ///
  /// 返回 `true` 如果事件被处理（找到了匹配的快捷键），否则返回 `false`
  ///
  /// ## 使用建议
  /// ```dart
  /// // 在 Widget 的 onKeyEvent 中使用
  /// FocusScope(
  ///   onKeyEvent: (node, event) {
  ///     return manager.handleKeyPress(event)
  ///         ? KeyEventResult.handled
  ///         : KeyEventResult.ignored;
  ///   },
  ///   child: child,
  /// )
  /// ```
  bool handleKeyPress(KeyEvent event) {
    for (final entry in _shortcuts.entries) {
      final activator = entry.key;
      final keyboard = ServicesBinding.instance.keyboard;
      if (activator.accepts(event, keyboard)) {
        entry.value();
        return true;
      }
    }
    return false;
  }
}

/// 应用标准快捷键配置
///
/// 定义应用中常用的快捷键常量，确保全局快捷键的一致性。
///
/// ## 使用方式
///
/// ```dart
/// // 在 ShortcutManager 中使用
/// final manager = ShortcutManager();
/// manager.register(AppShortcuts.createNode, () => createNewNode());
/// manager.register(AppShortcuts.save, () => saveFile());
///
/// // 在 FocusScope 的 Shortcuts 小部件中使用
/// Shortcuts(
///   shortcuts: <ShortcutActivator, Intent>{
///     AppShortcuts.createNode: const CreateNodeIntent(),
///     AppShortcuts.save: const SaveIntent(),
///   },
///   child: // ... your UI
/// )
/// ```
///
/// ## 快捷键列表
///
/// - `createNode`: N - 创建新节点
/// - `save`: Ctrl+S - 保存当前文件
/// - `undo`: Ctrl+Z - 撤销上一步操作
/// - `redo`: Ctrl+Shift+Z - 重做已撤销的操作
/// - `delete`: Delete - 删除选中的元素
/// - `search`: Ctrl+F - 打开搜索对话框
/// - `export`: Ctrl+E - 导出数据
class AppShortcuts {
  /// 创建节点快捷键 (N)
  ///
  /// 用于快速创建新节点，无需使用组合键
  static const createNode = SingleActivator(LogicalKeyboardKey.keyN);

  /// 保存快捷键 (Ctrl+S)
  ///
  /// 标准的保存操作快捷键，符合用户习惯
  static const save = SingleActivator(
    LogicalKeyboardKey.keyS,
    control: true,
  );

  /// 撤销快捷键 (Ctrl+Z)
  ///
  /// 标准的撤销操作快捷键
  static const undo = SingleActivator(
    LogicalKeyboardKey.keyZ,
    control: true,
  );

  /// 重做快捷键 (Ctrl+Shift+Z)
  ///
  /// 标准的重做操作快捷键
  static const redo = SingleActivator(
    LogicalKeyboardKey.keyZ,
    control: true,
    shift: true,
  );

  /// 删除快捷键 (Delete)
  ///
  /// 用于删除选中的节点、连接等元素
  static const delete = SingleActivator(LogicalKeyboardKey.delete);

  /// 搜索快捷键 (Ctrl+F)
  ///
  /// 标准的搜索快捷键，打开全局搜索对话框
  static const search = SingleActivator(
    LogicalKeyboardKey.keyF,
    control: true,
  );

  /// 导出快捷键 (Ctrl+E)
  ///
  /// 用于导出当前数据或节点
  static const export = SingleActivator(
    LogicalKeyboardKey.keyE,
    control: true,
  );
}
