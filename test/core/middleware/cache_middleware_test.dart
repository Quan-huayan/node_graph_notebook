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
      CommandResult.success('缓存结果');

  @override
  String get name => '可缓存测试命令';

  @override
  String get description => '可缓存的测试命令';
}

class TestNonCacheableCommand extends Command<dynamic> {
  TestNonCacheableCommand();

  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async =>
      CommandResult.success('非缓存结果');

  @override
  String get name => '不可缓存测试命令';

  @override
  String get description => '不可缓存的测试命令';
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
      test('应该有正确的元数据', () {
        expect(middleware.metadata.id, 'cache_middleware');
        expect(middleware.metadata.name, 'Cache Middleware');
        expect(middleware.metadata.version, '1.0.0');
      });

      test('应该有正确的优先级', () {
        expect(middleware.priority, 50);
      });
    });

    group('canHandle', () {
      test('应该处理可缓存的命令', () {
        final command = TestCacheableCommand();
        expect(middleware.canHandle(command), true);
      });

      test('不应该处理不可缓存的命令', () {
        final command = TestNonCacheableCommand();
        expect(middleware.canHandle(command), false);
      });
    });

    group('handle', () {
      test('应该执行命令并缓存结果', () async {
        final command = TestCacheableCommand();
        var executed = false;

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          executed = true;
          return CommandResult.success('结果');
        }

        final result = await middleware.handle(command, context, next);

        expect(executed, true);
        expect(result?.isSuccess, true);
        expect(result?.data, '结果');
      });

      test('第二次调用应该返回缓存的结果', () async {
        final command = TestCacheableCommand();
        var executionCount = 0;

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          executionCount++;
          return CommandResult.success('结果_$executionCount');
        }

        final result1 = await middleware.handle(command, context, next);
        final result2 = await middleware.handle(command, context, next);

        expect(result1?.data, '结果_1');
        expect(result2?.data, '结果_1');
        expect(executionCount, 1);
      });

      test('不应该缓存不可缓存的命令', () async {
        final command = TestNonCacheableCommand();
        var executionCount = 0;

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          executionCount++;
          return CommandResult.success('结果_$executionCount');
        }

        await middleware.handle(command, context, next);
        await middleware.handle(command, context, next);

        expect(executionCount, 2);
      });
    });

    group('clearCache', () {
      test('应该清除所有缓存', () async {
        final command = TestCacheableCommand();
        var executionCount = 0;

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          executionCount++;
          return CommandResult.success('结果_$executionCount');
        }

        await middleware.handle(command, context, next);
        middleware.clearCache();
        await middleware.handle(command, context, next);

        expect(executionCount, 2);
      });
    });

    group('clearCacheForCommand', () {
      test('应该清除特定命令的缓存', () async {
        final command1 = TestCacheableCommand();
        final command2 = TestCacheableCommand();
        var executionCount = 0;

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          executionCount++;
          return CommandResult.success('结果_$executionCount');
        }

        await middleware.handle(command1, context, next);
        middleware.clearCacheForCommand(command1);
        await middleware.handle(command2, context, next);

        expect(executionCount, 2);
      });
    });

    group('lifecycle', () {
      test('应该正确释放', () async {
        final command = TestCacheableCommand();
        var executionCount = 0;

        Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
          executionCount++;
          return CommandResult.success('结果_$executionCount');
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
    test('应该允许null缓存过期时间', () {
      final command = TestCacheableCommand(cacheTtl: null);
      expect(command.cacheTtl, isNull);
    });

    test('应该允许自定义缓存过期时间', () {
      final command = TestCacheableCommand(
        cacheTtl: const Duration(minutes: 10),
      );
      expect(command.cacheTtl, const Duration(minutes: 10));
    });
  });
}
