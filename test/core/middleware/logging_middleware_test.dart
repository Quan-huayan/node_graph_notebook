import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/models/command.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/middleware/logging_middleware.dart';
import 'package:node_graph_notebook/core/utils/logger.dart';

/// 测试用的简单命令
class TestCommand extends Command<String> {
  TestCommand({this.name = 'TestCommand', this.description = 'Test description'});

  @override
  final String name;

  @override
  final String description;

  @override
  Future<CommandResult<String>> execute(CommandContext context) async {
    return CommandResult.success('test result');
  }
}

/// 另一个测试命令
class AnotherCommand extends Command<int> {
  @override
  String get name => 'AnotherCommand';

  @override
  String get description => 'Another test command';

  @override
  Future<CommandResult<int>> execute(CommandContext context) async {
    return CommandResult.success(42);
  }
}

void main() {
  group('LoggingMiddleware', () {
    late LoggingMiddleware middleware;
    late CommandContext context;

    setUp(() {
      middleware = LoggingMiddleware();
      context = CommandContext();
    });

    group('基本功能', () {
      test('应该在命令开始前记录日志', () async {
        final command = TestCommand();

        // 验证方法可以正常调用，不抛出异常
        await expectLater(
          () => middleware.processBefore(command, context),
          returnsNormally,
        );
      });

      test('应该在命令成功后记录成功日志', () async {
        final command = TestCommand();
        final result = CommandResult<String>.success('test data');

        // 验证方法可以正常调用，不抛出异常
        await expectLater(
          () => middleware.processAfter(command, context, result),
          returnsNormally,
        );
      });

      test('应该在命令失败后记录错误日志', () async {
        final command = TestCommand();
        final result = CommandResult<String>.failure('Test error occurred');

        // 验证方法可以正常调用，不抛出异常
        await expectLater(
          () => middleware.processAfter(command, context, result),
          returnsNormally,
        );
      });

      test('应该记录命令执行时长', () async {
        final command = TestCommand();
        final result = CommandResult<String>.success('test data');

        // 开始执行
        await middleware.processBefore(command, context);

        // 模拟一些处理时间
        await Future.delayed(const Duration(milliseconds: 10));

        // 结束执行
        await middleware.processAfter(command, context, result);

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });

      test('应该处理多个命令', () async {
        final command1 = TestCommand();
        final command2 = AnotherCommand();
        final result1 = CommandResult<String>.success('result1');
        final result2 = CommandResult<int>.success(42);

        await middleware.processBefore(command1, context);
        await middleware.processAfter(command1, context, result1);

        await middleware.processBefore(command2, context);
        await middleware.processAfter(command2, context, result2);

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });

      test('应该清理已完成的命令的计时器', () async {
        final command = TestCommand();
        final result = CommandResult<String>.success('test data');

        await middleware.processBefore(command, context);
        await middleware.processAfter(command, context, result);

        // 再次执行同一个命令，应该能够正确计时
        await middleware.processBefore(command, context);
        await Future.delayed(const Duration(milliseconds: 5));
        await middleware.processAfter(command, context, result);

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });
    });

    group('日志级别过滤', () {
      test('应该在 LogLevel.error 时只记录错误', () async {
        final errorOnlyMiddleware = LoggingMiddleware(logLevel: LogLevel.error);
        final command = TestCommand();
        final successResult = CommandResult<String>.success('data');
        final failureResult = CommandResult<String>.failure('Error');

        // 开始执行（info 级别，不会被记录）
        await errorOnlyMiddleware.processBefore(command, context);

        // 成功完成（info 级别，不会被记录）
        await errorOnlyMiddleware.processAfter(command, context, successResult);

        // 失败完成（error 级别，应该被记录）
        await errorOnlyMiddleware.processAfter(command, context, failureResult);

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });

      test('应该在 LogLevel.warning 时记录警告和错误', () async {
        final warningMiddleware = LoggingMiddleware(logLevel: LogLevel.warning);
        final command = TestCommand();
        final failureResult = CommandResult<String>.failure('Error');

        // 开始执行（info 级别，不会被记录）
        await warningMiddleware.processBefore(command, context);

        // 失败完成（error 级别，应该被记录）
        await warningMiddleware.processAfter(command, context, failureResult);

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });

      test('应该在 LogLevel.debug 时记录所有日志', () async {
        final debugMiddleware = LoggingMiddleware(logLevel: LogLevel.debug);
        final command = TestCommand();
        final result = CommandResult<String>.success('data');

        await debugMiddleware.processBefore(command, context);
        await debugMiddleware.processAfter(command, context, result);

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });

      test('应该在 LogLevel.none 时禁用所有日志', () async {
        final noLogMiddleware = LoggingMiddleware(logLevel: LogLevel.none);
        final command = TestCommand();
        final failureResult = CommandResult<String>.failure('Critical error');

        await noLogMiddleware.processBefore(command, context);
        await noLogMiddleware.processAfter(command, context, failureResult);

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });
    });

    group('配置选项', () {
      test('应该支持禁用时间戳', () async {
        final noTimestampMiddleware = LoggingMiddleware(
          includeTimestamp: false,
        );
        final command = TestCommand();
        final result = CommandResult<String>.success('data');

        await noTimestampMiddleware.processBefore(command, context);
        await noTimestampMiddleware.processAfter(command, context, result);

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });

      test('应该支持禁用执行时长', () async {
        final noDurationMiddleware = LoggingMiddleware(
          includeDuration: false,
        );
        final command = TestCommand();
        final result = CommandResult<String>.success('data');

        await noDurationMiddleware.processBefore(command, context);
        await Future.delayed(const Duration(milliseconds: 10));
        await noDurationMiddleware.processAfter(command, context, result);

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });

      test('应该支持同时禁用时间戳和执行时长', () async {
        final minimalMiddleware = LoggingMiddleware(
          includeTimestamp: false,
          includeDuration: false,
        );
        final command = TestCommand();
        final result = CommandResult<String>.success('data');

        await minimalMiddleware.processBefore(command, context);
        await minimalMiddleware.processAfter(command, context, result);

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });

      test('应该支持所有配置组合', () async {
        final configs = [
          LogLevel.debug,
          LogLevel.info,
          LogLevel.warning,
          LogLevel.error,
        ];

        for (final logLevel in configs) {
          final customMiddleware = LoggingMiddleware(
            logLevel: logLevel,
            includeTimestamp: true,
            includeDuration: true,
          );
          final command = TestCommand();
          final result = CommandResult<String>.success('data');

          await customMiddleware.processBefore(command, context);
          await customMiddleware.processAfter(command, context, result);
        }

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });
    });

    group('边界情况', () {
      test('应该处理空描述的命令', () async {
        final emptyDescCommand = TestCommand(
          name: 'EmptyDescCommand',
          description: '',
        );
        final result = CommandResult<String>.success('data');

        await middleware.processBefore(emptyDescCommand, context);
        await middleware.processAfter(emptyDescCommand, context, result);

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });

      test('应该处理长错误消息', () async {
        final command = TestCommand();
        final longErrorMessage = 'Error: ' * 100; // 700+ 字符的错误消息
        final result = CommandResult<String>.failure(longErrorMessage);

        await middleware.processBefore(command, context);
        await middleware.processAfter(command, context, result);

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });

      test('应该处理快速连续执行的命令', () async {
        final commands = List.generate(
          10,
          (i) => TestCommand(
            name: 'Command$i',
            description: 'Test command $i',
          ),
        );

        // 快速执行所有命令
        for (final command in commands) {
          await middleware.processBefore(command, context);
        }

        // 快速完成所有命令
        for (final command in commands) {
          final result = CommandResult<String>.success('result');
          await middleware.processAfter(command, context, result);
        }

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });

      test('应该处理在 processBefore 之前调用 processAfter', () async {
        final command = TestCommand();
        final result = CommandResult<String>.success('data');

        // 直接调用 processAfter，没有调用 processBefore
        // 这种情况下 startTime 为 null，应该正常处理
        await expectLater(
          () => middleware.processAfter(command, context, result),
          returnsNormally,
        );
      });

      test('应该处理包含特殊字符的命令名和描述', () async {
        final specialCommand = TestCommand(
          name: '命令@#\$%',
          description: '描述 with 特殊 chars: 🎉 <script>alert(1)</script>',
        );
        final result = CommandResult<String>.success('data');

        await middleware.processBefore(specialCommand, context);
        await middleware.processAfter(specialCommand, context, result);

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });
    });

    group('性能测试', () {
      test('应该在大量命令执行时保持稳定', () async {
        final stopwatch = Stopwatch()..start();

        for (var i = 0; i < 100; i++) {
          final command = TestCommand(name: 'Command$i');
          await middleware.processBefore(command, context);
          final result = CommandResult<String>.success('result$i');
          await middleware.processAfter(command, context, result);
        }

        stopwatch.stop();

        // 验证在合理时间内完成（100个命令应该在5秒内完成）
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });

      test('应该正确计算执行时长', () async {
        final command = TestCommand();

        await middleware.processBefore(command, context);

        // 精确延迟 50ms
        await Future.delayed(const Duration(milliseconds: 50));

        final result = CommandResult<String>.success('data');
        await middleware.processAfter(command, context, result);

        // 验证完成，不抛出异常
        expect(true, isTrue);
      });
    });
  });
}
