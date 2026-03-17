import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/models/command.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
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
    return CommandResult.failure('Command failed');
  }

  @override
  Future<void> undo(CommandContext context) async {
    undone = true;
  }

  @override
  String get name => 'UndoableTestCommand';

  @override
  String get description => 'Undoable test command';
}

class NonUndoableTestCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async =>
      CommandResult.success();

  @override
  bool get isUndoable => false;

  @override
  String get name => 'NonUndoableTestCommand';

  @override
  String get description => 'Non-undoable test command';
}

class UndoErrorCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async =>
      CommandResult.success();

  @override
  Future<void> undo(CommandContext context) async {
    throw Exception('Undo failed');
  }

  @override
  String get name => 'UndoErrorCommand';

  @override
  String get description => 'Command with undo error';
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
      test('should track successful undoable command', () async {
        final command = UndoableTestCommand();
        final result = CommandResult.success();

        await middleware.processAfter(command, context, result);

        expect(middleware.canUndo, true);
        expect(middleware.undoStackSnapshot.length, 1);
        expect(middleware.undoStackSnapshot.first, command);
      });

      test('should not track failed command', () async {
        final command = UndoableTestCommand(shouldSucceed: false);
        final result = CommandResult.failure('Failed');

        await middleware.processAfter(command, context, result);

        expect(middleware.canUndo, false);
        expect(middleware.undoStackSnapshot.length, 0);
      });

      test('should not track non-undoable command', () async {
        final command = NonUndoableTestCommand();
        final result = CommandResult.success();

        await middleware.processAfter(command, context, result);

        expect(middleware.canUndo, false);
        expect(middleware.undoStackSnapshot.length, 0);
      });

      test('should clear redo stack on new command', () async {
        final command1 = UndoableTestCommand();
        final command2 = UndoableTestCommand();
        final result = CommandResult.success();

        await middleware.processAfter(command1, context, result);
        await middleware.undo(context);
        expect(middleware.canRedo, true);

        await middleware.processAfter(command2, context, result);
        expect(middleware.canRedo, false);
      });

      test('should limit stack size', () async {
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
      test('should undo last command', () async {
        final command = UndoableTestCommand();
        final result = CommandResult.success();

        await middleware.processAfter(command, context, result);
        await middleware.undo(context);

        expect(command.undone, true);
        expect(middleware.canUndo, false);
        expect(middleware.canRedo, true);
      });

      test('should throw when no command to undo', () async {
        expect(
          () => middleware.undo(context),
          throwsA(isA<StateError>()),
        );
      });

      test('should move command to redo stack after undo', () async {
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
      test('should redo last undone command', () async {
        final command = UndoableTestCommand();
        final result = CommandResult.success();

        await middleware.processAfter(command, context, result);
        await middleware.undo(context);
        final redoResult = await middleware.redo(context);

        expect(redoResult.isSuccess, true);
        expect(middleware.canRedo, false);
        expect(middleware.canUndo, true);
      });

      test('should throw when no command to redo', () async {
        expect(
          () => middleware.redo(context),
          throwsA(isA<StateError>()),
        );
      });

      test('should move command back to undo stack after redo', () async {
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
      test('should clear both stacks', () async {
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
      test('should support multiple undo/redo operations', () async {
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
