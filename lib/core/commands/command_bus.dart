import 'dart:async';
import 'command.dart';
import 'command_context.dart';
import 'command_handler.dart';
import 'command_handler_registry.dart';
import 'middleware.dart';
import '../plugin/middleware/middleware_plugin.dart';
import '../plugin/middleware/middleware_pipeline.dart';

/// 命令总线
///
/// 作为业务逻辑的统一入口，负责：
/// 1. 命令分发到对应的处理器
/// 2. 中间件管道执行
/// 3. 执行结果处理
/// 4. 错误处理和日志
class CommandBus {
  /// 构造函数
  CommandBus() {
    _middlewarePipeline = MiddlewarePipeline();
    _handlerRegistry = CommandHandlerRegistry();
  }
  
  /// 命令处理器注册表
  late final CommandHandlerRegistry _handlerRegistry;

  /// 中间件列表
  ///
  /// 按照添加顺序依次执行
  final List<CommandMiddleware> _middlewares = [];

  /// 中间件管道（用于插件中间件）
  late final MiddlewarePipeline _middlewarePipeline;

  /// 是否已释放
  bool _disposed = false;

  /// 命令执行流控制器
  ///
  /// 用于广播命令执行事件
  final _commandStreamController = StreamController<CommandEvent>.broadcast();

  /// 命令执行事件流
  Stream<CommandEvent> get commandStream => _commandStreamController.stream;

  /// 注册命令处理器
  ///
  /// [handler] 命令处理器实例
  /// [commandType] 命令类型（必须与处理器泛型参数匹配）
  ///
  /// 每个命令类型只能注册一个处理器，重复注册会覆盖
  void registerHandler<T extends Command>(
    CommandHandler<T> handler,
    Type commandType,
  ) {
    if (_disposed) {
      throw StateError('CommandBus 已释放，无法注册处理器');
    }

    _handlerRegistry.register(handler, commandType);
  }

  /// 添加中间件
  ///
  /// [middleware] 中间件实例
  ///
  /// 中间件按照添加顺序依次执行
  void addMiddleware(CommandMiddleware middleware) {
    if (_disposed) {
      throw StateError('CommandBus 已释放，无法添加中间件');
    }
    _middlewares.add(middleware);
  }

  /// 添加中间件插件
  ///
  /// [middleware] 中间件插件实例
  void addMiddlewarePlugin(CommandMiddlewarePlugin middleware) {
    if (_disposed) {
      throw StateError('CommandBus 已释放，无法添加中间件插件');
    }
    _middlewarePipeline.addCommandMiddleware(middleware);
  }

  /// 移除中间件插件
  ///
  /// [middleware] 中间件插件实例
  void removeMiddlewarePlugin(CommandMiddlewarePlugin middleware) {
    if (_disposed) {
      throw StateError('CommandBus 已释放，无法移除中间件插件');
    }
    _middlewarePipeline.removeCommandMiddleware(middleware);
  }

  /// 分发命令
  ///
  /// [command] 要执行的命令对象
  ///
  /// 执行流程：
  /// 1. 执行所有传统中间件（前置处理）
  /// 2. 执行中间件插件管道
  /// 3. 路由到对应的命令处理器
  /// 4. 执行命令
  /// 5. 执行中间件插件管道（后置）
  /// 6. 执行所有传统中间件（后置处理）
  /// 7. 返回执行结果
  ///
  /// 返回命令执行结果
  Future<CommandResult<T>> dispatch<T>(Command<T> command) async {
    if (_disposed) {
      throw StateError('CommandBus 已释放，无法分发命令');
    }

    final context = CommandContext();

    // 发布命令开始事件
    _commandStreamController.add(CommandStarted(
      command: command,
      timestamp: DateTime.now(),
    ));

    try {
      // 1. 执行传统中间件（前置）
      for (final middleware in _middlewares) {
        await middleware.processBefore(command, context);
      }

      // 2. 执行中间件插件管道
      // 3. 查找处理器
      final handler = _handlerRegistry.getHandler(command.runtimeType);
      if (handler == null) {
        throw CommandHandlerNotFoundException(command.runtimeType);
      }

      // 4. 执行命令
      final result = await _middlewarePipeline.executeCommand(
        command,
        context,
        handler,
      );



      // 6. 执行传统中间件（后置）
      for (final middleware in _middlewares) {
        await middleware.processAfter(command, context, result);
      }

      // 发布命令成功事件
      _commandStreamController.add(CommandSucceeded(
        command: command,
        result: result,
        timestamp: DateTime.now(),
      ));

      return result as CommandResult<T>;
    } catch (e, stackTrace) {
      // 发布命令失败事件
      _commandStreamController.add(CommandFailed(
        command: command,
        error: e,
        stackTrace: stackTrace,
        timestamp: DateTime.now(),
      ));

      // 返回失败结果
      return CommandResult.failureTyped<T>(e.toString());
    }
  }

  /// 撤销命令
  ///
  /// [command] 要撤销的命令对象
  ///
  /// 仅支持实现了 undo 方法的命令
  Future<void> undo(Command command) async {
    if (_disposed) {
      throw StateError('CommandBus 已释放，无法撤销命令');
    }

    if (!command.isUndoable) {
      throw UnsupportedError('命令 ${command.name} 不支持撤销操作');
    }

    final context = CommandContext();

    try {
      await command.undo(context);

      _commandStreamController.add(CommandUndone(
        command: command,
        timestamp: DateTime.now(),
      ));
    } catch (e, stackTrace) {
      _commandStreamController.add(CommandUndoFailed(
        command: command,
        error: e,
        stackTrace: stackTrace,
        timestamp: DateTime.now(),
      ));

      rethrow;
    }
  }

  /// 释放资源
  ///
  /// 关闭命令总线，释放所有资源
  /// 释放后无法再使用该命令总线
  void dispose() {
    if (_disposed) return;

    _commandStreamController.close();
    _handlerRegistry.clear();
    _middlewares.clear();
    _disposed = true;
  }
}

/// 命令事件基类
///
/// 表示命令总线生命周期中的各种事件
abstract class CommandEvent {
  CommandEvent({
    required this.command,
    required this.timestamp,
  });

  /// 关联的命令
  final Command command;

  /// 事件时间戳
  final DateTime timestamp;
}

/// 命令开始执行事件
class CommandStarted extends CommandEvent {
  CommandStarted({
    required super.command,
    required super.timestamp,
  });
}

/// 命令执行成功事件
class CommandSucceeded extends CommandEvent {
  CommandSucceeded({
    required super.command,
    required this.result,
    required super.timestamp,
  });

  /// 执行结果
  final CommandResult result;
}

/// 命令执行失败事件
class CommandFailed extends CommandEvent {
  CommandFailed({
    required super.command,
    required this.error,
    required this.stackTrace,
    required super.timestamp,
  });

  /// 错误对象
  final Object error;

  /// 堆栈跟踪
  final StackTrace stackTrace;
}

/// 命令撤销成功事件
class CommandUndone extends CommandEvent {
  CommandUndone({
    required super.command,
    required super.timestamp,
  });
}

/// 命令撤销失败事件
class CommandUndoFailed extends CommandEvent {
  CommandUndoFailed({
    required super.command,
    required this.error,
    required this.stackTrace,
    required super.timestamp,
  });

  /// 错误对象
  final Object error;

  /// 堆栈跟踪
  final StackTrace stackTrace;
}