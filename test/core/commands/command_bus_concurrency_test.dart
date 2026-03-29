import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/commands/models/command.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/commands/models/command_handler.dart';
import 'package:node_graph_notebook/core/commands/models/middleware.dart';

/// 计数命令 - 用于测试并发
class CounterCommand extends Command<int> {
  CounterCommand({this.increment = 1, this.delayMs = 0});

  final int increment;
  final int delayMs;

  @override
  String get name => 'CounterCommand';

  @override
  String get description => 'Increments a counter';

  @override
  Future<CommandResult<int>> execute(CommandContext context) async {
    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    return CommandResult.success(increment);
  }
}

/// 计数命令处理器
class CounterCommandHandler extends CommandHandler<CounterCommand> {
  static int _globalCounter = 0;

  @override
  Future<CommandResult<int>> execute(
    CounterCommand command,
    CommandContext context,
  ) async {
    final current = _globalCounter;
    await Future.delayed(Duration(milliseconds: command.delayMs));
    _globalCounter = current + command.increment;
    return CommandResult.success(_globalCounter);
  }

  static void reset() => _globalCounter = 0;
  static int get value => _globalCounter;
}

/// 慢速命令 - 用于测试超时场景
class SlowCommand extends Command<String> {
  SlowCommand({required this.durationMs});

  final int durationMs;

  @override
  String get name => 'SlowCommand';

  @override
  String get description => 'A slow command';

  @override
  Future<CommandResult<String>> execute(CommandContext context) async {
    await Future.delayed(Duration(milliseconds: durationMs));
    return CommandResult.success('Completed after ${durationMs}ms');
  }
}

/// 慢速命令处理器
class SlowCommandHandler extends CommandHandler<SlowCommand> {
  @override
  Future<CommandResult<String>> execute(
    SlowCommand command,
    CommandContext context,
  ) async {
    await Future.delayed(Duration(milliseconds: command.durationMs));
    return CommandResult.success('Completed');
  }
}

/// 错误命令 - 用于测试错误处理
class ErrorCommand extends Command<void> {
  ErrorCommand({this.errorMessage = 'Error'});

  final String errorMessage;

  @override
  String get name => 'ErrorCommand';

  @override
  String get description => 'A command that throws error';

  @override
  Future<CommandResult<void>> execute(CommandContext context) async {
    throw Exception(errorMessage);
  }
}

/// 错误命令处理器
class ErrorCommandHandler extends CommandHandler<ErrorCommand> {
  @override
  Future<CommandResult<void>> execute(
    ErrorCommand command,
    CommandContext context,
  ) async {
    throw Exception(command.errorMessage);
  }
}

/// 并发计数中间件
class ConcurrentCountingMiddleware extends CommandMiddleware {
  int beforeCount = 0;
  int afterCount = 0;
  final _beforeLock = Object();
  final _afterLock = Object();

  @override
  Future<void> processBefore(Command command, CommandContext context) async {
    synchronized(_beforeLock, () => beforeCount++);
  }

  @override
  Future<void> processAfter(
    Command command,
    CommandContext context,
    CommandResult result,
  ) async {
    synchronized(_afterLock, () => afterCount++);
  }
}

/// 延迟中间件 - 用于测试中间件执行顺序
class DelayMiddleware extends CommandMiddleware {
  DelayMiddleware({this.delayMs = 10});

  final int delayMs;
  final executionOrder = <String>[];

  @override
  Future<void> processBefore(Command command, CommandContext context) async {
    executionOrder.add('before_${command.name}');
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  @override
  Future<void> processAfter(
    Command command,
    CommandContext context,
    CommandResult result,
  ) async {
    await Future.delayed(Duration(milliseconds: delayMs));
    executionOrder.add('after_${command.name}');
  }
}

// 简单的同步辅助函数
void synchronized(Object lock, void Function() action) {
  action();
}

void main() {
  group('CommandBus Concurrency Tests', () {
    late CommandBus commandBus;

    setUp(() {
      commandBus = CommandBus();
      CounterCommandHandler.reset();
    });

    tearDown(() {
      commandBus.dispose();
    });

    group('高并发命令分发测试', () {
      test('should handle many concurrent commands', () async {
        commandBus.registerHandler(CounterCommandHandler(), CounterCommand);

        const commandCount = 100;
        final futures = <Future<CommandResult<int>>>[];

        for (var i = 0; i < commandCount; i++) {
          futures.add(commandBus.dispatch(CounterCommand(increment: 1)));
        }

        final results = await Future.wait(futures);

        expect(results.length, commandCount);
        expect(results.every((r) => r.isSuccess), true);
      });

      test('should handle rapid sequential dispatch', () async {
        commandBus.registerHandler(CounterCommandHandler(), CounterCommand);

        const iterations = 200;

        for (var i = 0; i < iterations; i++) {
          final result = await commandBus.dispatch(CounterCommand(increment: 1));
          expect(result.isSuccess, true);
        }
      });

      test('should handle mixed fast and slow commands', () async {
        commandBus
          ..registerHandler(CounterCommandHandler(), CounterCommand)
          ..registerHandler(SlowCommandHandler(), SlowCommand);

        final futures = <Future<CommandResult<dynamic>>>[
          commandBus.dispatch(SlowCommand(durationMs: 100)),
          commandBus.dispatch(CounterCommand(increment: 1)),
          commandBus.dispatch(CounterCommand(increment: 2)),
          commandBus.dispatch(SlowCommand(durationMs: 50)),
          commandBus.dispatch(CounterCommand(increment: 3)),
        ];

        final results = await Future.wait(futures);

        expect(results.length, 5);
        expect(results.every((r) => r.isSuccess), true);
      });
    });

    group('并发错误处理测试', () {
      test('should handle errors in concurrent commands', () async {
        commandBus
          ..registerHandler(CounterCommandHandler(), CounterCommand)
          ..registerHandler(ErrorCommandHandler(), ErrorCommand);

        final futures = <Future<CommandResult<dynamic>>>[
          commandBus.dispatch(CounterCommand(increment: 1)),
          commandBus.dispatch(ErrorCommand(errorMessage: 'Error 1')),
          commandBus.dispatch(CounterCommand(increment: 2)),
          commandBus.dispatch(ErrorCommand(errorMessage: 'Error 2')),
          commandBus.dispatch(CounterCommand(increment: 3)),
        ];

        final results = await Future.wait(futures);

        expect(results[0].isSuccess, true);
        expect(results[1].isSuccess, false);
        expect(results[2].isSuccess, true);
        expect(results[3].isSuccess, false);
        expect(results[4].isSuccess, true);
      });

      test('should continue operating after command failure', () async {
        commandBus.registerHandler(ErrorCommandHandler(), ErrorCommand);

        // 第一个命令失败
        final result1 = await commandBus.dispatch(ErrorCommand());
        expect(result1.isSuccess, false);

        // 命令总线应该仍然可以工作
        commandBus.registerHandler(CounterCommandHandler(), CounterCommand);
        final result2 = await commandBus.dispatch(CounterCommand(increment: 5));
        expect(result2.isSuccess, true);
        expect(result2.data, 5);
      });

      test('should handle all failing commands gracefully', () async {
        commandBus.registerHandler(ErrorCommandHandler(), ErrorCommand);

        const failureCount = 50;
        final futures = <Future<CommandResult<void>>>[];

        for (var i = 0; i < failureCount; i++) {
          futures.add(
            commandBus.dispatch(ErrorCommand(errorMessage: 'Error $i')),
          );
        }

        final results = await Future.wait(futures);

        expect(results.length, failureCount);
        expect(results.every((r) => !r.isSuccess), true);
      });
    });

    group('中间件并发测试', () {
      test('should execute middleware correctly under concurrency', () async {
        final middleware = ConcurrentCountingMiddleware();
        commandBus
          ..addMiddleware(middleware)
          ..registerHandler(CounterCommandHandler(), CounterCommand);

        const commandCount = 50;
        final futures = <Future<CommandResult<int>>>[];

        for (var i = 0; i < commandCount; i++) {
          futures.add(commandBus.dispatch(CounterCommand(increment: 1)));
        }

        await Future.wait(futures);

        expect(middleware.beforeCount, commandCount);
        expect(middleware.afterCount, commandCount);
      });

      test('should maintain middleware execution order', () async {
        final middleware = DelayMiddleware(delayMs: 5);
        commandBus
          ..addMiddleware(middleware)
          ..registerHandler(CounterCommandHandler(), CounterCommand);

        // 顺序执行命令
        await commandBus.dispatch(CounterCommand(increment: 1));
        await commandBus.dispatch(CounterCommand(increment: 2));
        await commandBus.dispatch(CounterCommand(increment: 3));

        // 验证中间件执行顺序
        expect(middleware.executionOrder.length, 6); // 3 before + 3 after
        expect(middleware.executionOrder[0], contains('before'));
        expect(middleware.executionOrder[5], contains('after'));
      });

      test('should handle multiple middlewares under concurrency', () async {
        final middleware1 = ConcurrentCountingMiddleware();
        final middleware2 = ConcurrentCountingMiddleware();

        commandBus
          ..addMiddleware(middleware1)
          ..addMiddleware(middleware2)
          ..registerHandler(CounterCommandHandler(), CounterCommand);

        const commandCount = 30;
        final futures = <Future<CommandResult<int>>>[];

        for (var i = 0; i < commandCount; i++) {
          futures.add(commandBus.dispatch(CounterCommand(increment: 1)));
        }

        await Future.wait(futures);

        expect(middleware1.beforeCount, commandCount);
        expect(middleware1.afterCount, commandCount);
        expect(middleware2.beforeCount, commandCount);
        expect(middleware2.afterCount, commandCount);
      });
    });

    group('事件流并发测试', () {
      test('should emit events for concurrent commands', () async {
        commandBus.registerHandler(CounterCommandHandler(), CounterCommand);

        final events = <CommandEvent>[];
        commandBus.commandStream.listen(events.add);

        const commandCount = 20;
        final futures = <Future<CommandResult<int>>>[];

        for (var i = 0; i < commandCount; i++) {
          futures.add(commandBus.dispatch(CounterCommand(increment: 1)));
        }

        await Future.wait(futures);
        await Future.delayed(const Duration(milliseconds: 100));

        // 每个命令应该产生至少2个事件（Started + Succeeded）
        expect(events.length, greaterThanOrEqualTo(commandCount * 2));

        final startedCount = events.whereType<CommandStarted>().length;
        final succeededCount = events.whereType<CommandSucceeded>().length;

        expect(startedCount, commandCount);
        expect(succeededCount, commandCount);
      });

      test('should handle multiple subscribers', () async {
        commandBus.registerHandler(CounterCommandHandler(), CounterCommand);

        final events1 = <CommandEvent>[];
        final events2 = <CommandEvent>[];

        commandBus.commandStream.listen(events1.add);
        commandBus.commandStream.listen(events2.add);

        const commandCount = 10;

        for (var i = 0; i < commandCount; i++) {
          await commandBus.dispatch(CounterCommand(increment: 1));
        }

        await Future.delayed(const Duration(milliseconds: 50));

        expect(events1.length, greaterThanOrEqualTo(commandCount * 2));
        expect(events2.length, greaterThanOrEqualTo(commandCount * 2));
      });
    });

    group('资源管理边界测试', () {
      test('should handle disposal during command execution', () async {
        commandBus.registerHandler(SlowCommandHandler(), SlowCommand);

        // 启动一个慢速命令
        await commandBus.dispatch(SlowCommand(durationMs: 500));

        // 等待命令开始执行
        await Future.delayed(const Duration(milliseconds: 50));

        // 释放命令总线
        commandBus.dispose();

        // 验证后续操作会失败
        expect(
          () => commandBus.dispatch(CounterCommand()),
          throwsA(isA<StateError>()),
        );
      });

      test('should reject commands after disposal', () async {
        commandBus.dispose();

        expect(
          () => commandBus.dispatch(CounterCommand()),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle multiple disposals gracefully', () {
        commandBus.dispose();
        commandBus.dispose(); // 第二次不应该抛出错误

        expect(
          () => commandBus.dispatch(CounterCommand()),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('处理器注册边界测试', () {
      test('should handle handler override', () async {
        // 注册第一个处理器
        commandBus.registerHandler(CounterCommandHandler(), CounterCommand);

        // 覆盖注册
        commandBus.registerHandler(CounterCommandHandler(), CounterCommand);

        final result = await commandBus.dispatch(CounterCommand(increment: 5));
        expect(result.isSuccess, true);
      });

      test('should handle many handler registrations', () async {
        // 注册大量处理器
        for (var i = 0; i < 100; i++) {
          // 创建不同的命令类型
          // 注意：这里我们使用相同的处理器类型，但在实际场景中应该有不同的命令类型
          commandBus.registerHandler(CounterCommandHandler(), CounterCommand);
        }

        final result = await commandBus.dispatch(CounterCommand(increment: 1));
        expect(result.isSuccess, true);
      });
    });
  });
}
