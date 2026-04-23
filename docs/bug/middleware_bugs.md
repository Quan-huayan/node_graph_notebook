# Middleware 模块 Bug 报告

## Bug #1: UndoMiddleware.redo() 绕过中间件链

**文件位置**: [undo_middleware.dart:92](file:///d:/Projects/node_graph_notebook/lib/core/middleware/undo_middleware.dart#L92)

**严重程度**: 高

**问题描述**:
`redo` 方法直接调用 `command.execute(context)`，这会完全绕过中间件链。

**问题代码**:
```dart
Future<CommandResult> redo(CommandContext context) async {
  if (!canRedo) {
    throw StateError('没有可重做的命令');
  }

  final command = _redoStack.removeLast();
  final result = await command.execute(context);  // <-- 直接执行，绕过中间件

  if (result.isSuccess) {
    _undoStack.add(command);
  }

  return result;
}
```

**影响**:
- 验证中间件不会被触发，可能导致无效数据被重做
- 日志中间件不会被触发，导致审计日志缺失
- 性能监控中间件不会被触发，导致性能数据不完整
- 事务中间件不会被触发，可能导致事务管理失效
- 缓存中间件不会被触发，可能导致缓存不一致

**建议修复**:
`UndoMiddleware` 应该持有对 `CommandBus` 的引用，通过 `CommandBus` 来执行重做操作，以确保所有中间件都能正常工作。

---

## Bug #2: TransactionMiddleware.clearMetadata() 清除所有元数据

**文件位置**: [transaction_middleware.dart:27](file:///d:/Projects/node_graph_notebook/lib/core/middleware/transaction_middleware.dart#L27)

**严重程度**: 中

**问题描述**:
`processAfter` 方法调用 `context.clearMetadata()` 清除所有元数据，这会影响其他中间件设置的元数据。

**问题代码**:
```dart
@override
Future<void> processAfter(
  Command command,
  CommandContext context,
  CommandResult result,
) async {
  context.clearMetadata();  // <-- 清除所有元数据

  if (!result.isSuccess && command.isUndoable) {
    try {
      await command.undo(context);
    } catch (e) {
      // 撤销失败，记录错误但不影响原错误抛出
    }
  }
}
```

**影响**:
- 其他中间件（如性能监控、日志等）可能依赖元数据来传递信息
- 清除所有元数据可能导致其他中间件的行为异常
- 破坏了中间件之间的数据隔离原则

**建议修复**:
应该只清除事务相关的元数据，而不是所有元数据：
```dart
context.removeMetadata('_transaction_active');
context.removeMetadata('_transaction_command');
```

---

## Bug #3: CacheMiddleware.canHandle() 语法错误

**文件位置**: [cache_middleware.dart:70-72](file:///d:/Projects/node_graph_notebook/lib/core/middleware/cache_middleware.dart#L70)

**严重程度**: 致命

**问题描述**:
`canHandle` 方法存在语法错误，缺少函数体的大括号，导致代码无法编译。

**问题代码**:
```dart
@override
bool canHandle(Command command) 
  // 只处理标记为可缓存的命令
  => command is CacheableCommand;
```

**影响**:
- 代码无法编译，中间件完全无法使用
- 整个缓存中间件功能不可用

**正确代码**:
```dart
@override
bool canHandle(Command command) {
  // 只处理标记为可缓存的命令
  return command is CacheableCommand;
}
```

或者简写：
```dart
@override
bool canHandle(Command command) => command is CacheableCommand;
```

---

## Bug #4: UndoMiddleware.undo() 异常处理不完整

**文件位置**: [undo_middleware.dart:70-78](file:///d:/Projects/node_graph_notebook/lib/core/middleware/undo_middleware.dart#L70)

**严重程度**: 中

**问题描述**:
`undo` 方法在 `command.undo(context)` 抛出异常时，命令已经从 `_undoStack` 中移除，但不会被添加到 `_redoStack`，导致命令丢失。

**问题代码**:
```dart
Future<void> undo(CommandContext context) async {
  if (!canUndo) {
    throw StateError('没有可撤销的命令');
  }

  final command = _undoStack.removeLast();  // 命令已从栈中移除
  await command.undo(context);  // 如果这里抛出异常，命令将丢失
  _redoStack.add(command);  // 这行不会执行
}
```

**影响**:
- 撤销失败时，命令从历史记录中丢失
- 用户无法重试撤销操作
- 数据状态可能不一致

**建议修复**:
```dart
Future<void> undo(CommandContext context) async {
  if (!canUndo) {
    throw StateError('没有可撤销的命令');
  }

  final command = _undoStack.removeLast();
  try {
    await command.undo(context);
    _redoStack.add(command);
  } catch (e) {
    // 撤销失败，将命令放回撤销栈
    _undoStack.add(command);
    rethrow;
  }
}
```

---

## 总结

| Bug ID | 文件 | 严重程度 | 状态 |
|--------|------|----------|------|
| Bug #1 | undo_middleware.dart | 高 | 待修复 |
| Bug #2 | transaction_middleware.dart | 中 | 待修复 |
| Bug #3 | cache_middleware.dart | 致命 | 待修复 |
| Bug #4 | undo_middleware.dart | 中 | 待修复 |
