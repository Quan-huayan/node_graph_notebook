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
      return CommandResult.failure('Command failed');
    }
    return CommandResult.success('result');
  }

  @override
  String get name => 'TestCommand';

  @override
  String get description => 'Test command for performance middleware';
}

class ErrorCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async {
    throw Exception('Command error');
  }

  @override
  String get name => 'ErrorCommand';

  @override
  String get description => 'Command that throws error';
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

    group('metadata', () {
      test('should have correct metadata', () {
        expect(middleware.metadata.id, 'performance_middleware');
        expect(middleware.metadata.name, 'Performance Middleware');
        expect(middleware.metadata.version, '1.0.0');
      });

      test('should have correct priority', () {
        expect(middleware.priority, 70);
      });
    });

    group('canHandle', () {
      test('should handle all commands', () {
        final command = TestCommand();
        expect(middleware.canHandle(command), true);
      });
    });

    group('handle', () {
      test('should record successful command execution', () async {
        final command = TestCommand();

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.success('result');

        await middleware.handle(command, context, next);

        final metrics = middleware.getMetrics();
        expect(metrics.length, 1);
        expect(metrics.first.commandType, 'TestCommand');
        expect(metrics.first.success, true);
      });

      test('should record command that returns failure result as success', () async {
        final command = TestCommand();

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.failure('error');

        await middleware.handle(command, context, next);

        final metrics = middleware.getMetrics();
        expect(metrics.length, 1);
        expect(metrics.first.success, true);
      });

      test('should record execution time', () async {
        final command = TestCommand();

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return CommandResult.success('result');
        }

        await middleware.handle(command, context, next);

        final metrics = middleware.getMetrics();
        expect(metrics.first.durationMs, greaterThanOrEqualTo(10));
      });

      test('should record error command execution as failure', () async {
        final command = ErrorCommand();

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            cmd.execute(ctx);

        try {
          await middleware.handle(command, context, next);
        } catch (e) {
          // Expected
        }

        final metrics = middleware.getMetrics();
        expect(metrics.length, 1);
        expect(metrics.first.success, false);
      });

      test('should record exception as failure', () async {
        final command = TestCommand();

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          throw Exception('Test error');
        }

        try {
          await middleware.handle(command, context, next);
        } catch (e) {
          // Expected
        }

        final metrics = middleware.getMetrics();
        expect(metrics.length, 1);
        expect(metrics.first.success, false);
      });
    });

    group('getAverageDuration', () {
      test('should return 0 when no metrics', () {
        expect(middleware.getAverageDuration(null), 0);
      });

      test('should calculate average duration', () async {
        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.success('result');

        await middleware.handle(TestCommand(), context, next);
        await middleware.handle(TestCommand(), context, next);

        final avg = middleware.getAverageDuration(null);
        expect(avg, greaterThanOrEqualTo(0));
      });

      test('should filter by command type', () async {
        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.success('result');

        await middleware.handle(TestCommand(), context, next);

        final avg = middleware.getAverageDuration('TestCommand');
        expect(avg, greaterThanOrEqualTo(0));

        final avgOther = middleware.getAverageDuration('OtherCommand');
        expect(avgOther, 0);
      });
    });

    group('getSuccessRate', () {
      test('should return 0 when no metrics', () {
        expect(middleware.getSuccessRate(null), 0);
      });

      test('should calculate success rate with exceptions', () async {
        Future<CommandResult?> successNext(
          Command cmd,
          CommandContext ctx,
        ) async =>
            CommandResult.success('result');

        Future<CommandResult?> errorNext(
          Command cmd,
          CommandContext ctx,
        ) async {
          throw Exception('error');
        }

        await middleware.handle(TestCommand(), context, successNext);
        await middleware.handle(TestCommand(), context, successNext);
        try {
          await middleware.handle(TestCommand(), context, errorNext);
        } catch (e) {
          // Expected
        }

        final rate = middleware.getSuccessRate(null);
        expect(rate, closeTo(0.667, 0.01));
      });

      test('should filter by command type', () async {
        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.success('result');

        await middleware.handle(TestCommand(), context, next);

        final rate = middleware.getSuccessRate('TestCommand');
        expect(rate, 1.0);

        final rateOther = middleware.getSuccessRate('OtherCommand');
        expect(rateOther, 0);
      });
    });

    group('clearMetrics', () {
      test('should clear all metrics', () async {
        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.success('result');

        await middleware.handle(TestCommand(), context, next);
        expect(middleware.getMetrics().length, 1);

        middleware.clearMetrics();
        expect(middleware.getMetrics().length, 0);
      });
    });

    group('metrics limit', () {
      test('should limit metrics to maxMetrics', () async {
        final smallMiddleware = PerformanceMiddleware();
        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.success('result');

        for (var i = 0; i < 1100; i++) {
          await smallMiddleware.handle(TestCommand(), context, next);
        }

        expect(smallMiddleware.getMetrics().length, lessThanOrEqualTo(1000));
      });
    });

    group('lifecycle', () {
      test('should dispose correctly', () async {
        Future<CommandResult?> next(Command cmd, CommandContext ctx) async =>
            CommandResult.success('result');

        await middleware.handle(TestCommand(), context, next);
        expect(middleware.getMetrics().length, 1);

        await middleware.onDispose();
        expect(middleware.getMetrics().length, 0);
      });
    });
  });

  group('PerformanceMetric', () {
    test('should create metric with all fields', () {
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
