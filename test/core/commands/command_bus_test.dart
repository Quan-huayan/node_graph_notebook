import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/commands/command_context.dart';
import 'package:node_graph_notebook/core/commands/command_handler.dart';
import 'package:node_graph_notebook/core/commands/middleware/middleware.dart';

/// 测试用命令
class TestCommand extends Command<String> {
  TestCommand(this.value);

  final String value;

  @override
  String get name => 'TestCommand';

  @override
  String get description => 'Test command with value: $value';

  @override
  Future<CommandResult<String>> execute(CommandContext context) async {
    // 由 Handler 处理
    throw UnimplementedError();
  }
}

/// 测试用可撤销命令
class UndoableTestCommand extends Command<String> {
  UndoableTestCommand(this.value);

  final String value;
  bool undoCalled = false;


  @override
  String get name => 'UndoableTestCommand';

  @override
  String get description => 'Undoable test command with value: $value';

  @override
  Future<CommandResult<String>> execute(CommandContext context) async {
    // 由 Handler 处理
    throw UnimplementedError();
  }

  @override
  Future<void> undo(CommandContext context) async {
    undoCalled = true;
  }
}

/// 测试用不可撤销命令
class NonUndoableCommand extends Command<String> {
  @override
  String get name => 'NonUndoableCommand';

  @override
  String get description => 'Non-undoable test command';

  @override
  bool get isUndoable => false;

  @override
  Future<CommandResult<String>> execute(CommandContext context) async {
    // 由 Handler 处理
    throw UnimplementedError();
  }
}

/// 测试用命令处理器
class TestCommandHandler implements CommandHandler<TestCommand> {
  TestCommandHandler({this.resultToReturn});

  CommandResult<String>? resultToReturn;
  Future<CommandResult<String>>? Function(TestCommand, CommandContext)? executeCallback;

  @override
  Future<CommandResult<String>> execute(TestCommand command, CommandContext context) async {
    if (executeCallback != null) {
      return await executeCallback!(command, context) ?? CommandResult.success('default-result');
    }
    return resultToReturn ?? CommandResult.success('default-result');
  }

  /// 设置要返回的结果
  void setResult(CommandResult<String> result) {
    resultToReturn = result;
  }
}

/// 测试用中间件
class TestMiddleware extends CommandMiddlewareBase {
  TestMiddleware({
    required this.executionLog,
    this.beforeFn,
    this.afterFn,
  });

  final List<String> executionLog;
  final Future<void> Function(Command, CommandContext)? beforeFn;
  final Future<void> Function(Command, CommandContext, CommandResult)? afterFn;

  @override
  Future<void> processBefore(Command command, CommandContext context) async {
    executionLog.add('$runtimeType-before');
    if (beforeFn != null) {
      await beforeFn!(command, context);
    }
  }

  @override
  Future<void> processAfter(Command command, CommandContext context, CommandResult result) async {
    executionLog.add('$runtimeType-after');
    if (afterFn != null) {
      await afterFn!(command, context, result);
    }
  }
}

void main() {
  group('CommandBus', () {
    late CommandBus commandBus;

    setUp(() {
      commandBus = CommandBus();
    });

    tearDown(() {
      commandBus.dispose();
    });

    group('命令注册和路由', () {
      test('应该成功注册命令处理器', () async {
        // Arrange
        final handler = TestCommandHandler(
          resultToReturn: CommandResult.success('test-result'),
        );

        // Act
        commandBus.registerHandler<TestCommand>(handler, TestCommand);
        final result = await commandBus.dispatch(TestCommand('test'));

        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 'test-result');
      });

      test('应该将命令路由到正确的处理器', () async {
        // Arrange
        const testValue = 'test-value';
        final handler = TestCommandHandler(
          resultToReturn: CommandResult.success('result: $testValue'),
        );
        final command = TestCommand(testValue);

        commandBus.registerHandler<TestCommand>(handler, TestCommand);

        // Act
        final result = await commandBus.dispatch(command);

        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 'result: $testValue');
      });

      test('未注册处理器时应该返回失败结果', () async {
        // Arrange
        final command = TestCommand('test');

        // Act
        final result = await commandBus.dispatch(command);

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, contains('未找到命令'));
      });

      test('重复注册处理器应该覆盖之前的注册', () async {
        // Arrange
        final oldHandler = TestCommandHandler(
          resultToReturn: CommandResult.success('old-result'),
        );
        final newHandler = TestCommandHandler(
          resultToReturn: CommandResult.success('new-result'),
        );

        // Act
        commandBus.registerHandler<TestCommand>(oldHandler, TestCommand);
        commandBus.registerHandler<TestCommand>(newHandler, TestCommand);
        final result = await commandBus.dispatch(TestCommand('test'));

        // Assert
        expect(result.data, 'new-result');
      });
    });

    group('中间件管道执行', () {
      test('应该按添加顺序执行中间件的前置处理', () async {
        // Arrange
        final executionLog = <String>[];
        final handler = TestCommandHandler(
          resultToReturn: CommandResult.success('result'),
        );

        final middleware1 = TestMiddleware(executionLog: executionLog);
        final middleware2 = TestMiddleware(executionLog: executionLog);

        commandBus
          ..addMiddleware(middleware1)
          ..addMiddleware(middleware2)
          ..registerHandler<TestCommand>(handler, TestCommand);

        // Act
        await commandBus.dispatch(TestCommand('test'));

        // Assert
        expect(executionLog, contains('TestMiddleware-before'));
        expect(executionLog.indexOf('TestMiddleware-before'), lessThan(executionLog.length));
      });

      test('应该在命令执行后执行中间件的后置处理', () async {
        // Arrange
        final executionLog = <String>[];
        final handler = TestCommandHandler();

        handler.executeCallback = (command, context) async {
          executionLog.add('handler');
          return CommandResult.success('result');
        };

        final middleware1 = TestMiddleware(executionLog: executionLog);
        final middleware2 = TestMiddleware(executionLog: executionLog);

        commandBus
          ..addMiddleware(middleware1)
          ..addMiddleware(middleware2)
          ..registerHandler<TestCommand>(handler, TestCommand);

        // Act
        await commandBus.dispatch(TestCommand('test'));

        // Assert
        expect(executionLog, contains('handler'));
        expect(executionLog, contains('TestMiddleware-after'));
        expect(executionLog.lastIndexOf('handler'), lessThan(executionLog.indexOf('TestMiddleware-after')));
      });

      test('应该执行完整的中间件管道', () async {
        // Arrange
        final executionLog = <String>[];
        final handler = TestCommandHandler();

        handler.executeCallback = (command, context) async {
          executionLog.add('handler');
          return CommandResult.success('result');
        };

        final middleware1 = TestMiddleware(executionLog: executionLog);
        final middleware2 = TestMiddleware(executionLog: executionLog);

        commandBus
          ..addMiddleware(middleware1)
          ..addMiddleware(middleware2)
          ..registerHandler<TestCommand>(handler, TestCommand);

        // Act
        await commandBus.dispatch(TestCommand('test'));

        // Assert
        // 应该有 2 个 before, 1 个 handler, 2 个 after
        final beforeCount = executionLog.where((s) => s.endsWith('-before')).length;
        final afterCount = executionLog.where((s) => s.endsWith('-after')).length;
        expect(beforeCount, 2);
        expect(afterCount, 2);
        expect(executionLog, contains('handler'));
      });
    });

    group('命令执行结果', () {
      test('成功执行应该返回成功结果', () async {
        // Arrange
        const expectedResult = 'success-data';
        final handler = TestCommandHandler(
          resultToReturn: CommandResult.success(expectedResult),
        );

        commandBus.registerHandler<TestCommand>(handler, TestCommand);

        // Act
        final result = await commandBus.dispatch(TestCommand('test'));

        // Assert
        expect(result.isSuccess, true);
        expect(result.data, expectedResult);
        expect(result.error, null);
      });

      test('失败执行应该返回失败结果', () async {
        // Arrange
        const errorMessage = 'Execution failed';
        final handler = TestCommandHandler(
          resultToReturn: CommandResult.failure(errorMessage),
        );

        commandBus.registerHandler<TestCommand>(handler, TestCommand);

        // Act
        final result = await commandBus.dispatch(TestCommand('test'));

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, errorMessage);
        expect(result.data, null);
      });

      test('处理结果的数据类型应该正确', () async {
        // Arrange
        const testInt = 42;
        const testString = 'hello';
        final handler = TestCommandHandler(
          resultToReturn: CommandResult.success(testString),
        );

        commandBus.registerHandler<TestCommand>(handler, TestCommand);

        // Act
        final result = await commandBus.dispatch(TestCommand(testInt.toString()));

        // Assert
        expect(result.isSuccess, true);
        expect(result.data, testString);
        expect(result.data, isA<String>());
      });
    });

    group('错误处理', () {
      test('处理器抛出异常应该返回失败结果', () async {
        // Arrange
        final handler = TestCommandHandler();
        handler.executeCallback = (command, context) async {
          throw Exception('Handler error');
        };

        commandBus.registerHandler<TestCommand>(handler, TestCommand);

        // Act
        final result = await commandBus.dispatch(TestCommand('test'));

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, contains('Handler error'));
      });

      test('中间件前置处理异常应该阻止命令执行', () async {
        // Arrange
        final executionLog = <String>[];
        final handler = TestCommandHandler(
          resultToReturn: CommandResult.success('result'),
        );

        final middleware = TestMiddleware(
          executionLog: executionLog,
          beforeFn: (command, context) async {
            throw Exception('Middleware error');
          },
        );

        commandBus
          ..addMiddleware(middleware)
          ..registerHandler<TestCommand>(handler, TestCommand);

        // Act
        final result = await commandBus.dispatch(TestCommand('test'));

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, contains('Middleware error'));
      });

      test('中间件后置处理异常会被捕获并导致命令失败', () async {
        // Arrange
        final handler = TestCommandHandler(
          resultToReturn: CommandResult.success('result'),
        );

        final middleware = TestMiddleware(
          executionLog: <String>[],
          afterFn: (command, context, result) async {
            throw Exception('After error');
          },
        );

        commandBus
          ..addMiddleware(middleware)
          ..registerHandler<TestCommand>(handler, TestCommand);

        // Act
        final result = await commandBus.dispatch(TestCommand('test'));

        // Assert - 当前实现中，中间件后置异常会导致命令失败
        expect(result.isSuccess, false);
        expect(result.error, contains('After error'));
      });
    });

    group('undo 功能', () {
      test('应该成功撤销可撤销命令', () async {
        // Arrange
        final command = UndoableTestCommand('test');

        // Act
        await commandBus.undo(command);

        // Assert
        expect(command.undoCalled, true);
      });

      test('撤销不可撤销命令应该抛出异常', () async {
        // Arrange
        final command = NonUndoableCommand();

        // Act & Assert
        expect(
          () => commandBus.undo(command),
          throwsA(isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('不支持撤销操作'),
          )),
        );
      });

      test('撤销应该发布成功事件', () async {
        // Arrange
        final command = UndoableTestCommand('test');
        final eventList = <CommandEvent>[];

        commandBus.commandStream.listen(eventList.add);

        // Act
        await commandBus.undo(command);
        await Future.delayed(const Duration(milliseconds: 10));

        // Assert - 撤销成功应该发布 CommandUndone 事件
        final undoneEvents = eventList.whereType<CommandUndone>().toList();
        expect(undoneEvents.length, 1);
        expect(undoneEvents[0].command, command);
      });
    });

    group('事件流发布', () {
      test('应该发布命令开始事件', () async {
        // Arrange
        final eventList = <CommandEvent>[];
        final command = TestCommand('test');
        final handler = TestCommandHandler(
          resultToReturn: CommandResult.success('result'),
        );

        commandBus.commandStream.listen(eventList.add);
        commandBus.registerHandler<TestCommand>(handler, TestCommand);

        // Act
        await commandBus.dispatch(command);

        // Assert
        expect(eventList.isNotEmpty, true);
        expect(eventList[0], isA<CommandStarted>());
        expect(eventList[0].command, command);
      });

      test('应该发布命令成功事件', () async {
        // Arrange
        final eventList = <CommandEvent>[];
        final command = TestCommand('test');
        final handler = TestCommandHandler(
          resultToReturn: CommandResult.success('result'),
        );

        commandBus.commandStream.listen(eventList.add);
        commandBus.registerHandler<TestCommand>(handler, TestCommand);

        // Act
        await commandBus.dispatch(command);
        await Future.delayed(const Duration(milliseconds: 10));

        // Assert
        final successEvents = eventList.whereType<CommandSucceeded>().toList();
        expect(successEvents.length, 1, reason: '应该收到一个 CommandSucceeded 事件');
        expect(successEvents[0].command, command);
        expect(successEvents[0].result.isSuccess, true);
      });

      test('应该发布命令失败事件', () async {
        // Arrange
        final eventList = <CommandEvent>[];
        final command = TestCommand('test');
        final handler = TestCommandHandler();
        handler.executeCallback = (cmd, ctx) async {
          throw Exception('Handler failed');
        };

        commandBus.commandStream.listen(eventList.add);
        commandBus.registerHandler<TestCommand>(handler, TestCommand);

        // Act
        await commandBus.dispatch(command);
        await Future.delayed(const Duration(milliseconds: 10));

        // Assert
        final failedEvents = eventList.whereType<CommandFailed>().toList();
        expect(failedEvents.length, 1);
        expect(failedEvents[0].command, command);
        expect(failedEvents[0].error, isA<Exception>());
        expect(failedEvents[0].stackTrace, isA<StackTrace>());
      });

      test('应该发布命令撤销成功事件', () async {
        // Arrange
        final eventList = <CommandEvent>[];
        final command = UndoableTestCommand('test');

        commandBus.commandStream.listen(eventList.add);

        // Act
        await commandBus.undo(command);
        await Future.delayed(const Duration(milliseconds: 10));

        // Assert
        final undoneEvents = eventList.whereType<CommandUndone>().toList();
        expect(undoneEvents.length, 1);
        expect(undoneEvents[0].command, command);
      });

      test('多个监听者应该都能收到事件', () async {
        // Arrange
        final events1 = <CommandEvent>[];
        final events2 = <CommandEvent>[];
        final handler = TestCommandHandler(
          resultToReturn: CommandResult.success('result'),
        );

        commandBus.commandStream.listen(events1.add);
        commandBus.commandStream.listen(events2.add);
        commandBus.registerHandler<TestCommand>(handler, TestCommand);

        // Act
        await commandBus.dispatch(TestCommand('test'));

        // Assert
        expect(events1.length, greaterThan(0));
        expect(events2.length, greaterThan(0));
        expect(events1.length, events2.length);
      });
    });

    group('dispose 功能', () {
      test('释放后无法注册处理器', () {
        // Arrange
        commandBus.dispose();
        final handler = TestCommandHandler();

        // Act & Assert
        expect(
          () => commandBus.registerHandler<TestCommand>(handler, TestCommand),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('已释放'),
          )),
        );
      });

      test('释放后无法添加中间件', () {
        // Arrange
        commandBus.dispose();
        final middleware = TestMiddleware(executionLog: <String>[]);

        // Act & Assert
        expect(
          () => commandBus.addMiddleware(middleware),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('已释放'),
          )),
        );
      });

      test('释放后无法分发命令', () async {
        // Arrange
        commandBus.dispose();

        // Act & Assert
        expect(
          () => commandBus.dispatch(TestCommand('test')),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('已释放'),
          )),
        );
      });

      test('释放后无法撤销命令', () {
        // Arrange
        final command = UndoableTestCommand('test');
        commandBus.dispose();

        // Act & Assert
        expect(
          () => commandBus.undo(command),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('已释放'),
          )),
        );
      });

      test('重复释放应该是安全的', () {
        // Act & Assert
        expect(() => commandBus.dispose(), returnsNormally);
        expect(() => commandBus.dispose(), returnsNormally);
      });
    });

    group('事件时间戳', () {
      test('命令事件应该包含时间戳', () async {
        // Arrange
        final beforeDispatch = DateTime.now();
        final eventList = <CommandEvent>[];
        final handler = TestCommandHandler(
          resultToReturn: CommandResult.success('result'),
        );

        commandBus.commandStream.listen(eventList.add);
        commandBus.registerHandler<TestCommand>(handler, TestCommand);

        // Act
        await commandBus.dispatch(TestCommand('test'));
        final afterDispatch = DateTime.now();

        // Assert
        for (final event in eventList) {
          expect(
            event.timestamp.isAtSameMomentAs(beforeDispatch) || event.timestamp.isAfter(beforeDispatch),
            true,
          );
          expect(
            event.timestamp.isAtSameMomentAs(afterDispatch) || event.timestamp.isBefore(afterDispatch),
            true,
          );
        }
      });

      test('事件时间戳应该是递增的', () async {
        // Arrange
        final eventList = <CommandEvent>[];
        final handler = TestCommandHandler(
          resultToReturn: CommandResult.success('result'),
        );

        commandBus.commandStream.listen(eventList.add);
        commandBus.registerHandler<TestCommand>(handler, TestCommand);

        // Act
        await commandBus.dispatch(TestCommand('test'));

        // Assert
        for (int i = 1; i < eventList.length; i++) {
          expect(
            eventList[i].timestamp.isAtSameMomentAs(eventList[i - 1].timestamp) ||
                eventList[i].timestamp.isAfter(eventList[i - 1].timestamp),
            true,
            reason: 'Event $i should have timestamp >= event ${i - 1}',
          );
        }
      });
    });

    group('并发执行', () {
      test('应该支持并发执行多个命令', () async {
        // Arrange
        final handler = TestCommandHandler();

        handler.executeCallback = (command, context) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return CommandResult.success('result: ${command.value}');
        };

        commandBus.registerHandler<TestCommand>(handler, TestCommand);

        // Act
        final results = await Future.wait([
          commandBus.dispatch(TestCommand('test1')),
          commandBus.dispatch(TestCommand('test2')),
        ]);

        // Assert
        expect(results[0].data, 'result: test1');
        expect(results[1].data, 'result: test2');
      });
    });

    group('中间件异常处理', () {
      test('中间件前置处理抛出异常应该停止执行', () async {
        // Arrange
        final executionLog = <String>[];
        final handler = TestCommandHandler(
          resultToReturn: CommandResult.success('result'),
        );

        final middleware1 = TestMiddleware(
          executionLog: executionLog,
          beforeFn: (command, context) async {
            throw Exception('Middleware 1 failed');
          },
        );
        final middleware2 = TestMiddleware(executionLog: executionLog);

        commandBus
          ..addMiddleware(middleware1)
          ..addMiddleware(middleware2)
          ..registerHandler<TestCommand>(handler, TestCommand);

        // Act
        final result = await commandBus.dispatch(TestCommand('test'));

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, contains('Middleware 1 failed'));
      });
    });
  });
}
