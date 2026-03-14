# Command Bus 设计文档

## 1. 概述

### 1.1 职责
Command Bus 是系统写操作的核心组件，负责：
- 接收和分发 Command 对象
- 执行中间件管道（验证、授权、转换等）
- 协调 Command 的执行
- 发布领域事件
- 处理执行结果和错误

### 1.2 目标
- **性能**: 单次 Command 执行延迟 < 10ms（不含存储）
- **可靠性**: 保证 Command 执行的原子性和一致性
- **可扩展性**: 支持中间件扩展和自定义 Command Handler
- **可观测性**: 提供执行日志和性能监控

### 1.3 关键挑战
- **中间件顺序**: 中间件执行顺序的正确性
- **错误处理**: 中间件中的错误传播和回滚
- **并发控制**: 多个 Command 的并发执行
- **事务管理**: 跨多个操作的原子性保证

## 2. 架构设计

### 2.1 组件结构

```
CommandBus
    │
    ├── Middlewares (管道)
    │   ├── ValidationMiddleware
    │   ├── AuthorizationMiddleware
    │   ├── TransformationMiddleware
    │   ├── ExecutionMiddleware
    │   ├── EffectsMiddleware
    │   └── LoggingMiddleware
    │
    ├── CommandContext (执行上下文)
    │   ├── Metadata (元数据)
    │   ├── Stopwatch (计时)
    │   └── Transaction (事务)
    │
    └── CommandResult (执行结果)
        ├── isSuccess
        ├── data
        └── error
```

### 2.2 接口定义

#### Command 基类

```dart
/// Command 基类 - 所有写操作的基类
abstract class Command {
  /// Command 类型标识，用于路由和日志
  Type get type => runtimeType;

  /// 验证 Command 的有效性
  ///
  /// 返回 ValidationResult，包含验证结果和错误信息
  ValidationResult validate();

  /// Command 的唯一标识符（可选）
  /// 用于跟踪和去重
  String? get commandId => null;
}

/// 验证结果
class ValidationResult {
  final bool isValid;
  final List<String> errors;

  ValidationResult.success()
      : isValid = true,
        errors = const [];

  ValidationResult.failure(this.errors) : isValid = false;

  /// 合并多个验证结果
  static ValidationResult combine(List<ValidationResult> results) {
    final allErrors = <String>[];
    for (final result in results) {
      allErrors.addAll(result.errors);
    }
    return allErrors.isEmpty
        ? ValidationResult.success()
        : ValidationResult.failure(allErrors);
  }
}
```

#### CommandMiddleware 接口

```dart
/// Command 中间件接口
abstract class CommandMiddleware {
  /// 中间件优先级（数值越小优先级越高）
  int get priority => 100;

  /// 处理 Command
  ///
  /// [command] - 要执行的 Command
  /// [context] - 执行上下文，可用于传递数据和状态
  /// [next] - 下一个中间件的调用函数
  ///
  /// 返回 CommandResult 表示中间件拦截了执行（如验证失败）
  /// 返回 null 表示继续执行下一个中间件
  Future<CommandResult?> handle(
    Command command,
    CommandContext context,
    NextMiddleware next,
  );
}

/// 中间件链调用函数
typedef NextMiddleware = Future<CommandResult> Function(
  Command command,
  CommandContext context,
);
```

#### CommandContext 定义

```dart
/// Command 执行上下文
class CommandContext {
  /// 元数据存储，用于中间件间传递数据
  final Map<String, dynamic> _metadata = {};

  /// 计时器，用于性能监控
  final Stopwatch stopwatch = Stopwatch();

  /// 事务对象（可选），用于跨操作原子性
  Transaction? transaction;

  /// 获取元数据
  T get<T>(String key) => _metadata[key] as T;

  /// 设置元数据
  void set<T>(String key, T value) => _metadata[key] = value;

  /// 检查元数据是否存在
  bool has(String key) => _metadata.containsKey(key);

  /// 删除元数据
  void remove(String key) => _metadata.remove(key);
}
```

#### CommandResult 定义

```dart
/// Command 执行结果
class CommandResult {
  /// 是否成功
  final bool isSuccess;

  /// 返回的数据
  final dynamic data;

  /// 错误信息
  final String? error;

  /// 执行时长（毫秒）
  final int? durationMs;

  CommandResult.success(this.data, {this.durationMs})
      : isSuccess = true,
        error = null;

  CommandResult.failure(this.error, {this.durationMs})
      : isSuccess = false,
        data = null;

  /// 创建成功结果
  factory CommandResult.ok(dynamic data, {int? durationMs}) =>
      CommandResult.success(data, durationMs: durationMs);

  /// 创建失败结果
  factory CommandResult.err(String error, {int? durationMs}) =>
      CommandResult.failure(error, durationMs: durationMs);

  /// 链式操作：仅当成功时执行
  CommandResult then(Function(dynamic) fn) {
    if (isSuccess) {
      return fn(data);
    }
    return this;
  }

  /// 链式操作：仅当失败时执行
  CommandResult catchError(Function(String) fn) {
    if (!isSuccess) {
      return fn(error!);
    }
    return this;
  }
}
```

#### CommandBus 接口

```dart
/// Command Bus 接口
abstract class ICommandBus {
  /// 执行单个 Command
  Future<CommandResult> execute(Command command);

  /// 批量执行 Commands
  ///
  /// 执行顺序保证，任何一个失败都会返回失败结果
  Future<List<CommandResult>> executeBatch(List<Command> commands);

  /// 添加中间件
  void addMiddleware(CommandMiddleware middleware);

  /// 移除中间件
  void removeMiddleware(CommandMiddleware middleware);

  /// 订阅所有 Command 结果
  Stream<CommandResult> get results;

  /// 获取执行统计
  CommandBusStats get stats;
}

/// Command Bus 统计信息
class CommandBusStats {
  final int totalExecuted;
  final int totalFailed;
  final int totalSucceeded;
  final double averageDurationMs;

  CommandBusStats({
    required this.totalExecuted,
    required this.totalFailed,
    required this.totalSucceeded,
    required this.averageDurationMs,
  });
}
```

## 3. 核心算法

### 3.1 中间件管道执行

**问题描述**:
如何按照正确的顺序执行中间件链，并支持：
- 中间件的前置和后置逻辑
- 中间件的短路返回（拦截执行）
- 错误的正确传播

**算法描述**:
使用递归链式调用模式，每个中间件接收 `next` 函数用于调用下一个中间件。

**伪代码**:
```
function executeMiddlewareChain(command, context, middlewares, index):
    if index >= middlewares.length:
        // 所有中间件执行完毕，返回成功
        return CommandResult.success(null)

    middleware = middlewares[index]

    try:
        // 调用当前中间件
        result = await middleware.handle(command, context, (cmd, ctx) =>
            executeMiddlewareChain(cmd, ctx, middlewares, index + 1)
        )

        if result != null:
            // 中间件拦截了执行
            return result
        else:
            // 继续执行下一个中间件
            return executeMiddlewareChain(command, context, middlewares, index + 1)
    catch error:
        // 中间件抛出异常
        return CommandResult.failure(error.message)
```

**复杂度分析**:
- 时间复杂度: O(n)，n 为中间件数量
- 空间复杂度: O(n)，递归调用栈深度

**实现**:

```dart
class CommandBus implements ICommandBus {
  final List<CommandMiddleware> _middlewares = [];
  final StreamController<CommandResult> _resultController =
      StreamController.broadcast();

  // 统计信息
  int _totalExecuted = 0;
  int _totalFailed = 0;
  int _totalSucceeded = 0;
  final List<int> _durations = [];

  @override
  Future<CommandResult> execute(Command command) async {
    final stopwatch = Stopwatch()..start();

    try {
      // 1. 验证 Command
      final validation = command.validate();
      if (!validation.isValid) {
        final result = CommandResult.err(
          '验证失败: ${validation.errors.join(", ")}',
        );
        _recordResult(result, stopwatch);
        return result;
      }

      // 2. 创建上下文
      final context = CommandContext();

      // 3. 执行中间件链
      final result = await _executeMiddlewareChain(command, context);

      // 4. 记录结果
      _recordResult(result, stopwatch);

      return result;
    } catch (e) {
      final result = CommandResult.err('执行异常: ${e.toString()}');
      _recordResult(result, stopwatch);
      return result;
    }
  }

  /// 递归执行中间件链
  Future<CommandResult> _executeMiddlewareChain(
    Command command,
    CommandContext context,
  ) async {
    int index = 0;

    // 闭包实现递归
    Future<CommandResult> next(
      Command cmd,
      CommandContext ctx,
    ) async {
      if (index >= _middlewares.length) {
        // 所有中间件执行完毕
        return CommandResult.ok(null);
      }

      final middleware = _middlewares[index++];
      return await middleware.handle(cmd, ctx, next);
    }

    return await next(command, context);
  }

  void _recordResult(CommandResult result, Stopwatch stopwatch) {
    stopwatch.stop();
    final duration = stopwatch.elapsedMilliseconds;

    _totalExecuted++;
    _durations.add(duration);

    if (result.isSuccess) {
      _totalSucceeded++;
    } else {
      _totalFailed++;
    }

    // 广播结果
    _resultController.add(result);
  }

  @override
  void addMiddleware(CommandMiddleware middleware) {
    _middlewares.add(middleware);
    // 按优先级排序
    _middlewares.sort((a, b) => a.priority.compareTo(b.priority));
  }

  @override
  Stream<CommandResult> get results => _resultController.stream;

  @override
  CommandBusStats get stats {
    final avgDuration = _durations.isEmpty
        ? 0.0
        : _durations.reduce((a, b) => a + b) / _durations.length;

    return CommandBusStats(
      totalExecuted: _totalExecuted,
      totalFailed: _totalFailed,
      totalSucceeded: _totalSucceeded,
      averageDurationMs: avgDuration,
    );
  }
}
```

### 3.2 批量执行优化

**问题描述**:
如何高效执行多个 Command，保证顺序和错误处理。

**算法描述**:
顺序执行每个 Command，任何一个失败则停止执行并返回失败。

**伪代码**:
```
function executeBatch(commands):
    results = []
    for command in commands:
        result = await execute(command)
        results.add(result)
        if not result.isSuccess:
            // 失败，停止执行
            break
    return results
```

**复杂度分析**:
- 时间复杂度: O(n * m)，n 为命令数，m 为中间件数
- 空间复杂度: O(n)，存储结果列表

**实现**:

```dart
@override
Future<List<CommandResult>> executeBatch(List<Command> commands) async {
  final results = <CommandResult>[];

  for (final command in commands) {
    final result = await execute(command);
    results.add(result);

    if (!result.isSuccess) {
      // 失败，停止执行
      break;
    }
  }

  return results;
}
```

## 4. 数据结构

### 4.1 中间件优先级队列

**结构定义**:
使用排序列表存储中间件，按优先级排序。

**存储布局**:
```
[
  ValidationMiddleware (priority: 10),
  AuthorizationMiddleware (priority: 20),
  TransformationMiddleware (priority: 30),
  ExecutionMiddleware (priority: 100),
  EffectsMiddleware (priority: 200),
  LoggingMiddleware (priority: 1000),
]
```

**索引策略**:
- 插入时排序: O(n log n)
- 执行时顺序访问: O(1)

## 5. 并发模型

### 5.1 Command 串行执行

**策略**:
- 所有 Command 进入单一队列
- 按到达顺序执行
- 保证 Command 之间的顺序性

**实现**:

```dart
class SerialCommandBus implements ICommandBus {
  final ICommandBus _delegate;
  final Queue<Future<CommandResult> Function()> _queue = Queue();
  bool _isProcessing = false;

  SerialCommandBus(this._delegate);

  @override
  Future<CommandResult> execute(Command command) async {
    final completer = Completer<CommandResult>();

    _queue.add(() async {
      final result = await _delegate.execute(command);
      completer.complete(result);
    });

    _processQueue();
    return completer.future;
  }

  void _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final operation = _queue.removeFirst();
      await operation();
    }

    _isProcessing = false;
  }

  @override
  void addMiddleware(CommandMiddleware middleware) {
    _delegate.addMiddleware(middleware);
  }

  @override
  Stream<CommandResult> get results => _delegate.results;

  @override
  CommandBusStats get stats => _delegate.stats;

  @override
  Future<List<CommandResult>> executeBatch(List<Command> commands) {
    return _delegate.executeBatch(commands);
  }
}
```

### 5.2 Command 并发执行（可选）

**策略**:
- 独立 Command 可并发执行
- 冲突 Command 串行化
- 使用依赖分析检测冲突

**实现**:

```dart
class ConcurrentCommandBus implements ICommandBus {
  final ICommandBus _delegate;
  final int maxConcurrency;

  ConcurrentCommandBus(
    this._delegate, {
    this.maxConcurrency = 10,
  });

  @override
  Future<CommandResult> execute(Command command) async {
    // TODO: 实现依赖分析和冲突检测
    return await _delegate.execute(command);
  }

  // ... 其他方法
}
```

## 6. 错误处理

### 6.1 错误类型定义

```dart
/// Command 错误基类
abstract class CommandError implements Exception {
  final String message;
  final Command? command;

  CommandError(this.message, [this.command]);

  @override
  String toString() => message;
}

/// 验证错误
class ValidationError extends CommandError {
  ValidationError(String message, [Command? command])
      : super(message, command);
}

/// 授权错误
class AuthorizationError extends CommandError {
  AuthorizationError(String message, [Command? command])
      : super(message, command);
}

/// 执行错误
class ExecutionError extends CommandError {
  final dynamic originalError;

  ExecutionError(String message, [Command? command, this.originalError])
      : super(message, command);
}

/// 冲突错误
class ConflictError extends CommandError {
  ConflictError(String message, [Command? command])
      : super(message, command);
}
```

### 6.2 错误传播机制

**策略**:
1. 中间件中捕获异常
2. 转换为 CommandResult.failure
3. 广播错误事件
4. 调用者处理错误

**实现**:

```dart
@override
Future<CommandResult> execute(Command command) async {
  try {
    // ... 执行逻辑
    return result;
  } on ValidationError catch (e) {
    return CommandResult.err('验证失败: ${e.message}');
  } on AuthorizationError catch (e) {
    return CommandResult.err('授权失败: ${e.message}');
  } on ExecutionError catch (e) {
    return CommandResult.err('执行失败: ${e.message}');
  } catch (e) {
    return CommandResult.err('未知错误: ${e.toString()}');
  }
}
```

### 6.3 回滚机制

**策略**:
- 使用 Command 前的快照
- 失败时恢复快照
- 通过 CommandContext 实现

**实现**:

```dart
class TransactionMiddleware extends CommandMiddleware {
  final StorageEngine _storage;

  TransactionMiddleware(this._storage);

  @override
  int get priority => 5;

  @override
  Future<CommandResult?> handle(
    Command command,
    CommandContext context,
    NextMiddleware next,
  ) async {
    // 创建快照
    final snapshot = await _storage.createSnapshot();
    context.set('snapshot', snapshot);

    try {
      final result = await next(command, context);

      if (!result.isSuccess) {
        // 回滚
        await _storage.restoreSnapshot(snapshot);
      }

      return result;
    } catch (e) {
      // 异常也回滚
      await _storage.restoreSnapshot(snapshot);
      rethrow;
    }
  }
}
```

## 7. 性能考虑

### 7.1 概念性性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| Command 执行延迟 | < 10ms | 不含存储操作 |
| 中间件开销 | < 1ms per middleware | 单个中间件的平均执行时间 |
| 批量执行吞吐 | > 1000 commands/s | 简单 Command 的批量执行 |

### 7.2 优化方向

1. **中间件优化**:
   - 减少中间件数量
   - 优化中间件逻辑
   - 使用异步并行

2. **批量操作**:
   - 批量验证
   - 批量执行
   - 批量发布事件

3. **缓存**:
   - 缓存验证结果
   - 缓存授权信息
   - 缓存转换结果

### 7.3 瓶颈分析

**潜在瓶颈**:
- 中间件过多导致延迟增加
- 同步阻塞操作
- 序列化/反序列化开销

**解决方案**:
- 中间件按需加载
- 异步非阻塞操作
- 二进制序列化格式

## 8. 关键文件清单

```
lib/core/command_bus/
├── command.dart              # Command 基类和 ValidationResult
├── command_context.dart      # CommandContext 定义
├── command_result.dart       # CommandResult 定义
├── command_bus.dart          # ICommandBus 接口和实现
├── serial_command_bus.dart   # 串行执行包装器
├── concurrent_command_bus.dart # 并发执行包装器
└── middleware/
    ├── middleware.dart       # CommandMiddleware 接口
    ├── validation.dart       # 验证中间件
    ├── authorization.dart    # 授权中间件
    ├── transformation.dart   # 转换中间件
    ├── execution.dart        # 执行中间件
    ├── effects.dart          # 副作用中间件
    ├── logging.dart          # 日志中间件
    ├── transaction.dart      # 事务中间件
    └── retry.dart            # 重试中间件
```

## 9. 中间件示例

### 9.1 验证中间件

```dart
class ValidationMiddleware extends CommandMiddleware {
  @override
  int get priority => 10;

  @override
  Future<CommandResult?> handle(
    Command command,
    CommandContext context,
    NextMiddleware next,
  ) async {
    // 调用 Command 的验证方法
    final result = command.validate();

    if (!result.isValid) {
      // 验证失败，返回错误
      return CommandResult.err(
        '验证失败: ${result.errors.join(", ")}',
      );
    }

    // 验证通过，继续执行
    return await next(command, context);
  }
}
```

### 9.2 授权中间件

```dart
class AuthorizationMiddleware extends CommandMiddleware {
  final AuthService _auth;

  AuthorizationMiddleware(this._auth);

  @override
  int get priority => 20;

  @override
  Future<CommandResult?> handle(
    Command command,
    CommandContext context,
    NextMiddleware next,
  ) async {
    // 获取当前用户
    final user = context.get<User>('currentUser');

    // 检查权限
    if (!await _auth.hasPermission(user, command)) {
      return CommandResult.err('权限不足');
    }

    return await next(command, context);
  }
}
```

### 9.3 执行中间件

```dart
class ExecutionMiddleware extends CommandMiddleware {
  final Map<Type, CommandHandler> _handlers;

  ExecutionMiddleware(this._handlers);

  @override
  int get priority => 100;

  @override
  Future<CommandResult?> handle(
    Command command,
    CommandContext context,
    NextMiddleware next,
  ) async {
    // 查找 Handler
    final handler = _handlers[command.type];

    if (handler == null) {
      return CommandResult.err('未找到 Handler: ${command.type}');
    }

    // 执行 Command
    context.stopwatch.start();
    final result = await handler.execute(command, context);
    context.stopwatch.stop();

    return CommandResult.ok(
      result.data,
      durationMs: context.stopwatch.elapsedMilliseconds,
    );
  }
}

/// Command Handler 接口
abstract class CommandHandler<TCommand extends Command> {
  Future<CommandResult> execute(
    TCommand command,
    CommandContext context,
  );
}
```

## 10. 参考资料

### 设计模式
- Mediator Pattern - Command Bus
- Middleware Pattern - Pipeline
- Command Pattern - Command Objects

### 相关文档
- CQRS Pattern - Martin Fowler
- Event Sourcing - Martin Fowler
- Domain-Driven Design - Eric Evans

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
