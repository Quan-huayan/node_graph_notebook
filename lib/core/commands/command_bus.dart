import 'dart:async';

import '../events/app_events.dart';
import '../plugin/middleware/middleware_pipeline.dart';
import '../plugin/middleware/middleware_plugin.dart';
import 'command_handler_registry.dart';
import 'models/command.dart';
import 'models/command_context.dart';
import 'models/command_handler.dart';
import 'models/middleware.dart';

/// 命令总线
///
/// 作为业务逻辑的统一入口和事件发布的中心，负责：
/// 1. 命令分发到对应的处理器
/// 2. 中间件管道执行
/// 3. 执行结果处理
/// 4. 错误处理和日志
/// 5. 事件发布（替代 AppEventBus）
///
/// 架构说明：
/// - CommandBus 现在是统一的通信中心
/// - 命令执行后自动发布事件到 eventStream
/// - BLoC 订阅 eventStream 接收数据变化通知
/// - 移除了 EventBus 与 CommandBus 的职责重叠
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

  /// 应用事件流控制器
  ///
  /// 用于发布应用事件（替代 AppEventBus）
  /// BLoC 订阅此流以接收数据变化通知
  final _eventStreamController = StreamController<AppEvent>.broadcast();

  /// 应用事件流
  ///
  /// 替代 AppEventBus.stream
  /// BLoC 应该订阅此流以接收节点数据变化、图关系变化等事件
  Stream<AppEvent> get eventStream => _eventStreamController.stream;

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

  /// 批量注册命令处理器
  ///
  /// [handlers] 命令处理器映射，key为命令类型，value为对应的处理器
  ///
  /// 每个命令类型只能注册一个处理器，重复注册会覆盖
  void registerHandlers(Map<Type, CommandHandler> handlers) {
    if (_disposed) {
      throw StateError('CommandBus 已释放，无法注册处理器');
    }

    _handlerRegistry.registerAll(handlers);
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
    _commandStreamController.add(
      CommandStarted(command: command, timestamp: DateTime.now()),
    );

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

      // 5. 从 CommandContext 收集待发布的事件
      final pendingEvents = context.getPendingEvents();

      // 6. 执行传统中间件（后置）
      for (final middleware in _middlewares) {
        await middleware.processAfter(command, context, result);
      }

      // 合并 CommandResult 中的事件和 CommandContext 中的待发布事件
      final allEvents = [
        ...?result.events,
        ...pendingEvents,
      ];

      // 发布命令成功事件
      _commandStreamController.add(
        CommandSucceeded(
          command: command,
          result: result,
          timestamp: DateTime.now(),
        ),
      );

      // 发布应用事件（如果有）
      if (allEvents.isNotEmpty) {
        allEvents.forEach(_eventStreamController.add);
      }

      // 清空 CommandContext 中的待发布事件
      context.clearPendingEvents();

      // 如果有新事件，返回带事件的 CommandResult
      return allEvents.isNotEmpty
          ? result.withEvents(allEvents) as CommandResult<T>
          : result as CommandResult<T>;
    } catch (e, stackTrace) {
      // 发布命令失败事件
      _commandStreamController.add(
        CommandFailed(
          command: command,
          error: e,
          stackTrace: stackTrace,
          timestamp: DateTime.now(),
        ),
      );

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

      _commandStreamController.add(
        CommandUndone(command: command, timestamp: DateTime.now()),
      );
    } catch (e, stackTrace) {
      _commandStreamController.add(
        CommandUndoFailed(
          command: command,
          error: e,
          stackTrace: stackTrace,
          timestamp: DateTime.now(),
        ),
      );

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
    _eventStreamController.close();
    _handlerRegistry.clear();
    _middlewares.clear();
    _disposed = true;
  }

  /// 发布应用事件
  ///
  /// 直接发布事件到 eventStream，无需通过命令执行
  /// 用于在命令处理器外部发布事件（向后兼容）
  ///
  /// 注意：推荐在 CommandHandler 中使用 CommandContext.publishEvent()
  /// 而不是直接调用此方法
  void publishEvent(AppEvent event) {
    if (_disposed) {
      throw StateError('CommandBus 已释放，无法发布事件');
    }
    _eventStreamController.add(event);
  }

  /// 批量发布应用事件
  ///
  /// 批量发布多个事件到 eventStream
  void publishEvents(List<AppEvent> events) {
    if (_disposed) {
      throw StateError('CommandBus 已释放，无法发布事件');
    }
    events.forEach(_eventStreamController.add);
  }
}

/// 命令事件基类
///
/// 表示命令总线生命周期中的各种事件
abstract class CommandEvent {
  /// 创建一个命令事件
  ///
  /// [command] - 关联的命令
  /// [timestamp] - 事件时间戳
  CommandEvent({required this.command, required this.timestamp});

  /// 关联的命令
  final Command command;

  /// 事件时间戳
  final DateTime timestamp;
}

/// 命令开始执行事件
class CommandStarted extends CommandEvent {
  /// 创建一个命令开始执行事件
  ///
  /// [command] - 关联的命令
  /// [timestamp] - 事件时间戳
  CommandStarted({required super.command, required super.timestamp});
}

/// 命令执行成功事件
class CommandSucceeded extends CommandEvent {
  /// 创建一个命令执行成功事件
  ///
  /// [command] - 关联的命令
  /// [result] - 执行结果
  /// [timestamp] - 事件时间戳
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
  /// 创建一个命令执行失败事件
  ///
  /// [command] - 关联的命令
  /// [error] - 错误对象
  /// [stackTrace] - 堆栈跟踪
  /// [timestamp] - 事件时间戳
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
  /// 创建一个命令撤销成功事件
  ///
  /// [command] - 关联的命令
  /// [timestamp] - 事件时间戳
  CommandUndone({required super.command, required super.timestamp});
}

/// 命令撤销失败事件
class CommandUndoFailed extends CommandEvent {
  /// 创建一个命令撤销失败事件
  ///
  /// [command] - 关联的命令
  /// [error] - 错误对象
  /// [stackTrace] - 堆栈跟踪
  /// [timestamp] - 事件时间戳
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
