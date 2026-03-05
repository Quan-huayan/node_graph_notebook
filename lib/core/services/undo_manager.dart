import 'package:flutter/foundation.dart';
import 'commands/command.dart';

/// 撤销/重做管理器
class UndoManager extends ChangeNotifier {
  UndoManager();

  final List<Command> _undoStack = [];
  final List<Command> _redoStack = [];
  static const int _maxStackSize = 50;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// 执行命令
  Future<void> execute(Command command) async {
    await command.execute();
    _undoStack.add(command);
    _redoStack.clear();

    // 限制栈大小
    if (_undoStack.length > _maxStackSize) {
      _undoStack.removeAt(0);
    }

    notifyListeners();
  }

  /// 撤销
  Future<void> undo() async {
    if (!canUndo) return;

    final command = _undoStack.removeLast();
    await command.undo();
    _redoStack.add(command);

    notifyListeners();
  }

  /// 重做
  Future<void> redo() async {
    if (!canRedo) return;

    final command = _redoStack.removeLast();
    await command.execute();
    _undoStack.add(command);

    notifyListeners();
  }

  /// 清空历史
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }
}
