import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/cqrs/commands/models/command.dart';
import 'package:node_graph_notebook/core/cqrs/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/middleware/undo_middleware.dart';

class UndoableTestCommand extends Command<dynamic> {
  UndoableTestCommand({this.shouldSucceed = true});

  final bool shouldSucceed;
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
    undone = true;
  }

  @override
  String get name => '可撤销测试命令';

  @override
  String get description => '可撤销的测试命令';
}

class NonUndoableTestCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async =>
      CommandResult.success();

  @override
  bool get isUndoable => false;

  @override
  String get name => '不可撤销测试命令';

  @override
  String get description => '不可撤销的测试命令';
}

class UndoErrorCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async =>
      CommandResult.success();

  @override
  Future<void> undo(CommandContext context) async {
    throw Exception('撤销失败');
  }

  @override
  String get name => '撤销错误命令';

  @override
  String get description => '带有撤销错误的命令';
}

void main() {
  group('UndoMiddleware', () {
    late UndoMiddleware middleware;
    late CommandContext context;

    setUp(() {
      middleware = UndoMiddleware();
      context = CommandContext();
    });

    group('processAfter', () {
      test('应该跟踪成功的可撤销命令', () async {
        final command = UndoableTestCommand();
        final result = CommandResult.success();

        await middleware.processAfter(command, context, result);

        expect(middleware.canUndo, true);
        expect(middleware.undoStackSnapshot.length, 1);
        expect(middleware.undoStackSnapshot.first, command);
      });

      test('不应该跟踪失败的命令', () async {
        final command = UndoableTestCommand(shouldSucceed: false);
        final result = CommandResult.failure('失败');

        await middleware.processAfter(command, context, result);

        expect(middleware.canUndo, false);
        expect(middleware.undoStackSnapshot.length, 0);
      });

      test('不应该跟踪不可撤销的命令', () async {
        final command = NonUndoableTestCommand();
        final result = CommandResult.success();

        await middleware.processAfter(command, context, result);

        expect(middleware.canUndo, false);
        expect(middleware.undoStackSnapshot.length, 0);
      });

      test('新命令应该清除重做栈', () async {
        final command1 = UndoableTestCommand();
        final command2 = UndoableTestCommand();
        final result = CommandResult.success();

        await middleware.processAfter(command1, context, result);
        await middleware.undo(context);
        expect(middleware.canRedo, true);

        await middleware.processAfter(command2, context, result);
        expect(middleware.canRedo, false);
      });

      test('应该限制栈大小', () async {
        final smallMiddleware = UndoMiddleware(maxStackSize: 3);
        final result = CommandResult.success();

        for (var i = 0; i < 5; i++) {
          await smallMiddleware.processAfter(
            UndoableTestCommand(),
            context,
            result,
          );
        }

        expect(smallMiddleware.undoStackSnapshot.length, 3);
      });
    });

    group('undo', () {
      test('应该撤销最后一个命令', () async {
        final command = UndoableTestCommand();
        final result = CommandResult.success();

        await middleware.processAfter(command, context, result);
        await middleware.undo(context);

        expect(command.undone, true);
        expect(middleware.canUndo, false);
        expect(middleware.canRedo, true);
      });

      test('当没有命令可撤销时应该抛出异常', () async {
        expect(
          () => middleware.undo(context),
          throwsA(isA<StateError>()),
        );
      });

      test('撤销后应该将命令移到重做栈', () async {
        final command = UndoableTestCommand();
        final result = CommandResult.success();

        await middleware.processAfter(command, context, result);
        await middleware.undo(context);

        expect(middleware.undoStackSnapshot.length, 0);
        expect(middleware.redoStackSnapshot.length, 1);
        expect(middleware.redoStackSnapshot.first, command);
      });
    });

    group('redo', () {
      test('应该重做最后一个撤销的命令', () async {
        final command = UndoableTestCommand();
        final result = CommandResult.success();

        await middleware.processAfter(command, context, result);
        await middleware.undo(context);
        final redoResult = await middleware.redo(context);

        expect(redoResult.isSuccess, true);
        expect(middleware.canRedo, false);
        expect(middleware.canUndo, true);
      });

      test('当没有命令可重做时应该抛出异常', () async {
        expect(
          () => middleware.redo(context),
          throwsA(isA<StateError>()),
        );
      });

      test('重做后应该将命令移回撤销栈', () async {
        final command = UndoableTestCommand();
        final result = CommandResult.success();

        await middleware.processAfter(command, context, result);
        await middleware.undo(context);
        await middleware.redo(context);

        expect(middleware.undoStackSnapshot.length, 1);
        expect(middleware.redoStackSnapshot.length, 0);
      });
    });

    group('clear', () {
      test('应该清除两个栈', () async {
        final command = UndoableTestCommand();
        final result = CommandResult.success();

        await middleware.processAfter(command, context, result);
        await middleware.undo(context);

        middleware.clear();

        expect(middleware.canUndo, false);
        expect(middleware.canRedo, false);
        expect(middleware.undoStackSnapshot.length, 0);
        expect(middleware.redoStackSnapshot.length, 0);
      });
    });

    group('undo/redo workflow', () {
      test('应该支持多次撤销/重做操作', () async {
        final command1 = UndoableTestCommand();
        final command2 = UndoableTestCommand();
        final result = CommandResult.success();

        await middleware.processAfter(command1, context, result);
        await middleware.processAfter(command2, context, result);

        expect(middleware.canUndo, true);
        expect(middleware.undoStackSnapshot.length, 2);

        await middleware.undo(context);
        expect(middleware.undoStackSnapshot.length, 1);
        expect(middleware.redoStackSnapshot.length, 1);

        await middleware.undo(context);
        expect(middleware.canUndo, false);
        expect(middleware.redoStackSnapshot.length, 2);

        await middleware.redo(context);
        expect(middleware.undoStackSnapshot.length, 1);
        expect(middleware.redoStackSnapshot.length, 1);
      });
    });
  });
}
