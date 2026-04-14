import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/cqrs/commands/models/command.dart';
import 'package:node_graph_notebook/core/cqrs/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/middleware/transaction_middleware.dart';

class TestCommand extends Command<dynamic> {
  TestCommand({this.shouldSucceed = true, this.undoShouldFail = false});

  final bool shouldSucceed;
  final bool undoShouldFail;
  bool undone = false;

  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async {
    if (shouldSucceed) {
      return CommandResult.success();
    }
    return CommandResult.failure('命令执行失败');
  }

  @override
  Future<void> undo(CommandContext context) async {
    if (undoShouldFail) {
      throw Exception('撤销失败');
    }
    undone = true;
  }

  @override
  String get name => '测试命令';

  @override
  String get description => '用于事务中间件测试的命令';
}

class NonUndoableTestCommand extends Command<dynamic> {
  NonUndoableTestCommand({this.shouldSucceed = true});

  final bool shouldSucceed;

  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async {
    if (shouldSucceed) {
      return CommandResult.success();
    }
    return CommandResult.failure('命令执行失败');
  }

  @override
  bool get isUndoable => false;

  @override
  String get name => '不可撤销测试命令';

  @override
  String get description => '不可撤销的测试命令';
}

void main() {
  group('TransactionMiddleware', () {
    late TransactionMiddleware middleware;
    late CommandContext context;

    setUp(() {
      middleware = TransactionMiddleware();
      context = CommandContext();
    });

    group('processBefore', () {
      test('应该设置事务元数据', () async {
        final command = TestCommand();

        await middleware.processBefore(command, context);

        expect(context.getMetadata('_transaction_active'), true);
        expect(context.getMetadata('_transaction_command'), command);
      });
    });

    group('processAfter', () {
      test('处理后应该清除元数据', () async {
        final command = TestCommand();
        final result = CommandResult.success();

        await middleware.processBefore(command, context);
        await middleware.processAfter(command, context, result);

        expect(context.getMetadata('_transaction_active'), isNull);
        expect(context.getMetadata('_transaction_command'), isNull);
      });

      test('不应该撤销成功的命令', () async {
        final command = TestCommand();
        final result = CommandResult.success();

        await middleware.processBefore(command, context);
        await middleware.processAfter(command, context, result);

        expect(command.undone, false);
      });

      test('应该撤销失败的可撤销命令', () async {
        final command = TestCommand(shouldSucceed: false);
        final result = CommandResult.failure('失败');

        await middleware.processBefore(command, context);
        await middleware.processAfter(command, context, result);

        expect(command.undone, true);
      });

      test('不应该撤销失败的不可撤销命令', () async {
        final command = NonUndoableTestCommand(shouldSucceed: false);
        final result = CommandResult.failure('失败');

        await middleware.processBefore(command, context);
        await middleware.processAfter(command, context, result);
      });

      test('应该优雅地处理撤销失败', () async {
        final command = TestCommand(
          shouldSucceed: false,
          undoShouldFail: true,
        );
        final result = CommandResult.failure('失败');

        await middleware.processBefore(command, context);
        await middleware.processAfter(command, context, result);
      });
    });

    group('transaction workflow', () {
      test('应该处理完整的事务周期', () async {
        final command = TestCommand();
        final result = CommandResult.success();

        await middleware.processBefore(command, context);
        expect(context.getMetadata('_transaction_active'), true);

        await middleware.processAfter(command, context, result);
        expect(context.getMetadata('_transaction_active'), isNull);
      });

      test('应该处理失败的事务周期', () async {
        final command = TestCommand(shouldSucceed: false);
        final result = CommandResult.failure('失败');

        await middleware.processBefore(command, context);
        expect(context.getMetadata('_transaction_active'), true);

        await middleware.processAfter(command, context, result);
        expect(context.getMetadata('_transaction_active'), isNull);
        expect(command.undone, true);
      });
    });
  });
}
