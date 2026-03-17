import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/models/command.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
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
    return CommandResult.failure('Command failed');
  }

  @override
  Future<void> undo(CommandContext context) async {
    if (undoShouldFail) {
      throw Exception('Undo failed');
    }
    undone = true;
  }

  @override
  String get name => 'TestCommand';

  @override
  String get description => 'Test command for transaction middleware';
}

class NonUndoableTestCommand extends Command<dynamic> {
  NonUndoableTestCommand({this.shouldSucceed = true});

  final bool shouldSucceed;

  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async {
    if (shouldSucceed) {
      return CommandResult.success();
    }
    return CommandResult.failure('Command failed');
  }

  @override
  bool get isUndoable => false;

  @override
  String get name => 'NonUndoableTestCommand';

  @override
  String get description => 'Non-undoable test command';
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
      test('should set transaction metadata', () async {
        final command = TestCommand();

        await middleware.processBefore(command, context);

        expect(context.getMetadata('_transaction_active'), true);
        expect(context.getMetadata('_transaction_command'), command);
      });
    });

    group('processAfter', () {
      test('should clear metadata after processing', () async {
        final command = TestCommand();
        final result = CommandResult.success();

        await middleware.processBefore(command, context);
        await middleware.processAfter(command, context, result);

        expect(context.getMetadata('_transaction_active'), isNull);
        expect(context.getMetadata('_transaction_command'), isNull);
      });

      test('should not undo successful command', () async {
        final command = TestCommand();
        final result = CommandResult.success();

        await middleware.processBefore(command, context);
        await middleware.processAfter(command, context, result);

        expect(command.undone, false);
      });

      test('should undo failed undoable command', () async {
        final command = TestCommand(shouldSucceed: false);
        final result = CommandResult.failure('Failed');

        await middleware.processBefore(command, context);
        await middleware.processAfter(command, context, result);

        expect(command.undone, true);
      });

      test('should not undo failed non-undoable command', () async {
        final command = NonUndoableTestCommand(shouldSucceed: false);
        final result = CommandResult.failure('Failed');

        await middleware.processBefore(command, context);
        await middleware.processAfter(command, context, result);
      });

      test('should handle undo failure gracefully', () async {
        final command = TestCommand(
          shouldSucceed: false,
          undoShouldFail: true,
        );
        final result = CommandResult.failure('Failed');

        await middleware.processBefore(command, context);
        await middleware.processAfter(command, context, result);
      });
    });

    group('transaction workflow', () {
      test('should handle complete transaction cycle', () async {
        final command = TestCommand();
        final result = CommandResult.success();

        await middleware.processBefore(command, context);
        expect(context.getMetadata('_transaction_active'), true);

        await middleware.processAfter(command, context, result);
        expect(context.getMetadata('_transaction_active'), isNull);
      });

      test('should handle failed transaction cycle', () async {
        final command = TestCommand(shouldSucceed: false);
        final result = CommandResult.failure('Failed');

        await middleware.processBefore(command, context);
        expect(context.getMetadata('_transaction_active'), true);

        await middleware.processAfter(command, context, result);
        expect(context.getMetadata('_transaction_active'), isNull);
        expect(command.undone, true);
      });
    });
  });
}
