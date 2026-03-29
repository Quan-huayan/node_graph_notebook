import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/models/command.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/middleware/performance_middleware.dart';

class TestCommand extends Command<dynamic> {
  TestCommand({this.shouldFail = false, this.delayMs = 0});

  final bool shouldFail;
  final int delayMs;

  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async {
    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    if (shouldFail) {
      return CommandResult.failure('命令执行失败');
    }
    return CommandResult.success('结果');
  }

  @override
  String get name => '测试命令';

  @override
  String get description => '用于性能中间件测试的命令';
}

class ErrorCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async {
    throw Exception('命令错误');
  }

  @override
  String get name => '错误命令';

  @override
  String get description => '抛出错误的命令';
}

void main() {
  group('PerformanceMiddleware', () {
    late PerformanceMiddleware middleware;
    late CommandContext context;

    setUp(() {
      middleware = PerformanceMiddleware();
      context = CommandContext();
    });

    tearDown(() {
      middleware.onDispose();
    });

    group('元数据', () {
      test('应该有正确的元数据', () {
        expect(middleware.metadata.id, 'performance_middleware');
        expect(middleware.metadata.name, 'Performance Middleware');
        expect(middleware.metadata.version, '1.0.0');
      });

      test('应该有正确的优先级', () {
        expect(middleware.priority, 70);
      });
    });

    group('canHandle', () {
      test('应该处理所有命令', () {
        final command = TestCommand();
        expect(middleware.canHandle(command), true);
      });
    });

    group('handle', () {
      test('应该记录成功的命令执行', () async {
        final command = TestCommand();

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.success('结果');

        await middleware.handle(command, context, next);

        final metrics = middleware.getMetrics();
        expect(metrics.length, 1);
        expect(metrics.first.commandType, 'TestCommand');
        expect(metrics.first.success, true);
      });

      test('应该将返回失败结果的命令记录为成功', () async {
        final command = TestCommand();

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.failure('错误');

        await middleware.handle(command, context, next);

        final metrics = middleware.getMetrics();
        expect(metrics.length, 1);
        expect(metrics.first.success, true);
      });

      test('应该记录执行时间', () async {
        final command = TestCommand();

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return CommandResult.success('结果');
        }

        await middleware.handle(command, context, next);

        final metrics = middleware.getMetrics();
        expect(metrics.first.durationMs, greaterThanOrEqualTo(10));
      });

      test('应该将错误命令执行记录为失败', () async {
        final command = ErrorCommand();

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            cmd.execute(ctx);

        try {
          await middleware.handle(command, context, next);
        } catch (e) {
          // 预期内的异常
        }

        final metrics = middleware.getMetrics();
        expect(metrics.length, 1);
        expect(metrics.first.success, false);
      });

      test('应该将异常记录为失败', () async {
        final command = TestCommand();

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          throw Exception('测试错误');
        }

        try {
          await middleware.handle(command, context, next);
        } catch (e) {
          // 预期内的异常
        }

        final metrics = middleware.getMetrics();
        expect(metrics.length, 1);
        expect(metrics.first.success, false);
      });
    });

    group('getAverageDuration', () {
      test('当没有指标时应该返回0', () {
        expect(middleware.getAverageDuration(null), 0);
      });

      test('应该计算平均持续时间', () async {
        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.success('结果');

        await middleware.handle(TestCommand(), context, next);
        await middleware.handle(TestCommand(), context, next);

        final avg = middleware.getAverageDuration(null);
        expect(avg, greaterThanOrEqualTo(0));
      });

      test('应该按命令类型过滤', () async {
        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.success('结果');

        await middleware.handle(TestCommand(), context, next);

        final avg = middleware.getAverageDuration('TestCommand');
        expect(avg, greaterThanOrEqualTo(0));

        final avgOther = middleware.getAverageDuration('OtherCommand');
        expect(avgOther, 0);
      });
    });

    group('getSuccessRate', () {
      test('当没有指标时应该返回0', () {
        expect(middleware.getSuccessRate(null), 0);
      });

      test('应该计算带异常的成功率', () async {
        Future<CommandResult?> successNext(
          Command cmd,
          CommandContext ctx,
        ) async =>
            CommandResult.success('结果');

        Future<CommandResult?> errorNext(
          Command cmd,
          CommandContext ctx,
        ) async {
          throw Exception('错误');
        }

        await middleware.handle(TestCommand(), context, successNext);
        await middleware.handle(TestCommand(), context, successNext);
        try {
          await middleware.handle(TestCommand(), context, errorNext);
        } catch (e) {
          // 预期内的异常
        }

        final rate = middleware.getSuccessRate(null);
        expect(rate, closeTo(0.667, 0.01));
      });

      test('应该按命令类型过滤', () async {
        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.success('结果');

        await middleware.handle(TestCommand(), context, next);

        final rate = middleware.getSuccessRate('TestCommand');
        expect(rate, 1.0);

        final rateOther = middleware.getSuccessRate('OtherCommand');
        expect(rateOther, 0);
      });
    });

    group('clearMetrics', () {
      test('应该清除所有指标', () async {
        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.success('结果');

        await middleware.handle(TestCommand(), context, next);
        expect(middleware.getMetrics().length, 1);

        middleware.clearMetrics();
        expect(middleware.getMetrics().length, 0);
      });
    });

    group('metrics limit', () {
      test('应该将指标限制为maxMetrics', () async {
        final smallMiddleware = PerformanceMiddleware();
        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.success('结果');

        for (var i = 0; i < 1100; i++) {
          await smallMiddleware.handle(TestCommand(), context, next);
        }

        expect(smallMiddleware.getMetrics().length, lessThanOrEqualTo(1000));
      });
    });

    group('lifecycle', () {
      test('应该正确释放', () async {
        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.success('结果');

        await middleware.handle(TestCommand(), context, next);
        expect(middleware.getMetrics().length, 1);

        await middleware.onDispose();
        expect(middleware.getMetrics().length, 0);
      });
    });
  });

  group('PerformanceMetric', () {
    test('应该创建带有所有字段的指标', () {
      final metric = PerformanceMetric(
        commandType: 'TestCommand',
        durationMs: 100,
        success: true,
        timestamp: DateTime.now(),
      );

      expect(metric.commandType, 'TestCommand');
      expect(metric.durationMs, 100);
      expect(metric.success, true);
      expect(metric.timestamp, isNotNull);
    });
  });
}
