import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/models/command.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/middleware/cache_middleware.dart';

class TestCacheableCommand extends Command<dynamic> implements CacheableCommand {
  TestCacheableCommand({this.cacheTtl});

  @override
  final Duration? cacheTtl;

  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async =>
      CommandResult.success('cached_result');

  @override
  String get name => 'TestCacheableCommand';

  @override
  String get description => 'Cacheable test command';
}

class TestNonCacheableCommand extends Command<dynamic> {
  TestNonCacheableCommand();

  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async =>
      CommandResult.success('non_cached_result');

  @override
  String get name => 'TestNonCacheableCommand';

  @override
  String get description => 'Non-cacheable test command';
}

void main() {
  group('CacheMiddleware', () {
    late CacheMiddleware middleware;
    late CommandContext context;

    setUp(() {
      middleware = CacheMiddleware();
      context = CommandContext();
    });

    tearDown(() {
      middleware.onDispose();
    });

    group('metadata', () {
      test('should have correct metadata', () {
        expect(middleware.metadata.id, 'cache_middleware');
        expect(middleware.metadata.name, 'Cache Middleware');
        expect(middleware.metadata.version, '1.0.0');
      });

      test('should have correct priority', () {
        expect(middleware.priority, 50);
      });
    });

    group('canHandle', () {
      test('should handle cacheable commands', () {
        final command = TestCacheableCommand();
        expect(middleware.canHandle(command), true);
      });

      test('should not handle non-cacheable commands', () {
        final command = TestNonCacheableCommand();
        expect(middleware.canHandle(command), false);
      });
    });

    group('handle', () {
      test('should execute command and cache result', () async {
        final command = TestCacheableCommand();
        var executed = false;

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          executed = true;
          return CommandResult.success('result');
        }

        final result = await middleware.handle(command, context, next);

        expect(executed, true);
        expect(result?.isSuccess, true);
        expect(result?.data, 'result');
      });

      test('should return cached result on second call', () async {
        final command = TestCacheableCommand();
        var executionCount = 0;

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          executionCount++;
          return CommandResult.success('result_$executionCount');
        }

        final result1 = await middleware.handle(command, context, next);
        final result2 = await middleware.handle(command, context, next);

        expect(result1?.data, 'result_1');
        expect(result2?.data, 'result_1');
        expect(executionCount, 1);
      });

      test('should not cache non-cacheable commands', () async {
        final command = TestNonCacheableCommand();
        var executionCount = 0;

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          executionCount++;
          return CommandResult.success('result_$executionCount');
        }

        await middleware.handle(command, context, next);
        await middleware.handle(command, context, next);

        expect(executionCount, 2);
      });
    });

    group('clearCache', () {
      test('should clear all cache', () async {
        final command = TestCacheableCommand();
        var executionCount = 0;

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          executionCount++;
          return CommandResult.success('result_$executionCount');
        }

        await middleware.handle(command, context, next);
        middleware.clearCache();
        await middleware.handle(command, context, next);

        expect(executionCount, 2);
      });
    });

    group('clearCacheForCommand', () {
      test('should clear cache for specific command', () async {
        final command1 = TestCacheableCommand();
        final command2 = TestCacheableCommand();
        var executionCount = 0;

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          executionCount++;
          return CommandResult.success('result_$executionCount');
        }

        await middleware.handle(command1, context, next);
        middleware.clearCacheForCommand(command1);
        await middleware.handle(command2, context, next);

        expect(executionCount, 2);
      });
    });

    group('lifecycle', () {
      test('should dispose correctly', () async {
        final command = TestCacheableCommand();
        var executionCount = 0;

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          executionCount++;
          return CommandResult.success('result_$executionCount');
        }

        await middleware.handle(command, context, next);
        expect(executionCount, 1);

        await middleware.onDispose();

        await middleware.handle(command, context, next);
        expect(executionCount, 2);
      });
    });
  });

  group('CacheableCommand', () {
    test('should allow null cacheTtl', () {
      final command = TestCacheableCommand(cacheTtl: null);
      expect(command.cacheTtl, isNull);
    });

    test('should allow custom cacheTtl', () {
      final command = TestCacheableCommand(
        cacheTtl: const Duration(minutes: 10),
      );
      expect(command.cacheTtl, const Duration(minutes: 10));
    });
  });
}
