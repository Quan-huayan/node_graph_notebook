import '../commands/models/command.dart';
import '../commands/models/command_context.dart';
import '../commands/models/middleware.dart';

/// 撤销中间件
///
/// 自动追踪执行的命令，支持撤销和重做操作。
///
/// 工作原理：
/// 1. 在命令成功执行后，将命令添加到撤销栈
/// 2. 执行撤销时，从撤销栈取出命令并调用其 undo 方法
/// 3. 执行重做时，从重做栈取出命令并重新执行
///
/// 注意事项：
/// - 只追踪可撤销的命令（isUndoable == true）
/// - 执行失败的命令不会被添加到撤销栈
/// - 撤销栈大小限制为 50 条，超过时会移除最早的记录
class UndoMiddleware extends CommandMiddlewareBase {
  /// 创建撤销中间件
  ///
  /// [maxStackSize] 撤销栈的最大大小，默认 50
  UndoMiddleware({int maxStackSize = 50}) : _maxStackSize = maxStackSize;

  /// 撤销栈
  ///
  /// 存储已执行的命令，按执行顺序排列
  final List<Command> _undoStack = [];

  /// 重做栈
  ///
  /// 存储已撤销的命令，按撤销顺序排列
  final List<Command> _redoStack = [];

  /// 最大栈大小
  final int _maxStackSize;

  /// 是否可以撤销
  bool get canUndo => _undoStack.isNotEmpty;

  /// 是否可以重做
  bool get canRedo => _redoStack.isNotEmpty;

  @override
  Future<void> processAfter(
    Command command,
    CommandContext context,
    CommandResult result,
  ) async {
    // 只追踪可撤销且执行成功的命令
    if (command.isUndoable && result.isSuccess) {
      _undoStack.add(command);

      // 新命令执行后，清空重做栈
      // 这是因为新的命令执行改变了状态，之前的历史路径已经失效
      _redoStack.clear();

      // 限制撤销栈大小
      if (_undoStack.length > _maxStackSize) {
        _undoStack.removeAt(0);
      }
    }
  }

  /// 撤销最后一个命令
  ///
  /// 从撤销栈取出最后一个命令并调用其 undo 方法
  /// 撤销成功后，将命令移动到重做栈
  ///
  /// 抛出 [StateError] 如果没有可撤销的命令
  Future<void> undo(CommandContext context) async {
    if (!canUndo) {
      throw StateError('没有可撤销的命令');
    }

    final command = _undoStack.removeLast();
    await command.undo(context);
    _redoStack.add(command);
  }

  /// 重做最后一个被撤销的命令
  ///
  /// 从重做栈取出最后一个命令并重新执行
  /// 执行成功后，将命令移动回撤销栈
  ///
  /// 抛出 [StateError] 如果没有可重做的命令
  Future<CommandResult> redo(CommandContext context) async {
    if (!canRedo) {
      throw StateError('没有可重做的命令');
    }

    final command = _redoStack.removeLast();
    final result = await command.execute(context);

    // 只有执行成功才加入撤销栈
    if (result.isSuccess) {
      _undoStack.add(command);
    }

    return result;
  }

  /// 清空撤销和重做栈
  ///
  /// 通常在以下情况调用：
  /// - 用户执行了不可撤销的操作
  /// - 应用关闭时
  /// - 数据重新加载时
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }

  /// 获取撤销栈的快照
  ///
  /// 用于调试和测试
  List<Command> get undoStackSnapshot => List.unmodifiable(_undoStack);

  /// 获取重做栈的快照
  ///
  /// 用于调试和测试
  List<Command> get redoStackSnapshot => List.unmodifiable(_redoStack);
}
