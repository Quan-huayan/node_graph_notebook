/// UndoManager —— 撤销栈（03 §四 撤销契约的执行者）。
///
/// 契约（03 §四）：写命令 Handler 必须声明 `inverse`（对偶命令）或
/// 显式声明不可撤销；实现层的 UndoMiddleware 维护逆命令栈。本类即
/// 该栈：dispatch 成功后 [record] 把 result.inverse 入栈（栈上限
/// [limit]，超出丢最旧）；[undo]/[redo] 出栈并经**原始执行通道**
/// dispatch 对偶命令（不再次 record——否则撤销会立刻把自己重新入栈）。
library;

import 'command.dart';

/// 撤销管理器。
class UndoManager {
  /// 注入原始执行通道（CommandBus 的"执行 + 写后通知，不记录撤销"入口）。
  UndoManager({
    required Future<WriteResult> Function(Command command) dispatchRaw,
    this.limit = 100,
  }) : _dispatchRaw = dispatchRaw;

  final Future<WriteResult> Function(Command command) _dispatchRaw;

  /// 栈上限（超出丢最旧）。
  final int limit;

  final List<Command> _undoStack = <Command>[];
  final List<Command> _redoStack = <Command>[];

  /// 可撤销。
  bool get canUndo => _undoStack.isNotEmpty;

  /// 可重做。
  bool get canRedo => _redoStack.isNotEmpty;

  /// dispatch 成功后记录（inverse null = 显式不可撤销，跳过；
  /// 新写操作清空 redo 栈——标准撤销语义）。
  void record(WriteResult result) {
    final inverse = result.inverse;
    if (inverse == null) {
      return;
    }
    _undoStack.add(inverse);
    while (_undoStack.length > limit) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  /// 撤销：出栈 → 原始通道 dispatch 对偶命令 → 其结果 inverse 入 redo 栈。
  Future<void> undo() async {
    if (_undoStack.isEmpty) {
      return;
    }
    final command = _undoStack.removeLast();
    final result = await _dispatchRaw(command);
    final inverse = result.inverse;
    if (inverse != null) {
      _redoStack.add(inverse);
    }
  }

  /// 重做：redo 栈出栈 → 原始通道 dispatch → 其结果 inverse 回 undo 栈。
  Future<void> redo() async {
    if (_redoStack.isEmpty) {
      return;
    }
    final command = _redoStack.removeLast();
    final result = await _dispatchRaw(command);
    final inverse = result.inverse;
    if (inverse != null) {
      _undoStack.add(inverse);
    }
  }

  /// 清空两栈（如仓库切换——跨数据根的命令不可撤销）。
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
