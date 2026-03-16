import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/commands/models/command.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/commands/models/command_handler.dart';
import 'package:node_graph_notebook/core/commands/models/middleware.dart';

// Mock command class
class MockCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async => CommandResult.success();

  @override
  String get name => 'MockCommand';

  @override
  String get description => 'Mock command for testing';
}

// Mock command handler
class MockCommandHandler extends CommandHandler<MockCommand> {
  @override
  Future<CommandResult> execute(MockCommand command, CommandContext context) async => CommandResult.success();
}

// Mock middleware
class MockMiddleware extends CommandMiddleware {
  int beforeCount = 0;
  int afterCount = 0;

  @override
  Future<void> processBefore(Command command, CommandContext context) async => beforeCount++;

  @override
  Future<void> processAfter(Command command, CommandContext context, CommandResult result) async => afterCount++;
}

// Error command for testing
class ErrorCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async => throw Exception('Command error');

  @override
  String get name => 'ErrorCommand';

  @override
  String get description => 'Command that throws error';
}

// Error command handler
class ErrorCommandHandler extends CommandHandler<ErrorCommand> {
  @override
  Future<CommandResult> execute(ErrorCommand command, CommandContext context) async => command.execute(context);
}

// Undoable command
class UndoableCommand extends Command<dynamic> {
  bool undone = false;

  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async => CommandResult.success();

  @override
  Future<void> undo(CommandContext context) async => undone = true;

  @override
  String get name => 'UndoableCommand';

  @override
  String get description => 'Command that can be undone';
}

// Non-undoable command
class NonUndoableCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async => CommandResult.success();

  @override
  bool get isUndoable => false;

  @override
  String get name => 'NonUndoableCommand';

  @override
  String get description => 'Command that cannot be undone';
}

// Undo error command
class UndoErrorCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async => CommandResult.success();

  @override
  Future<void> undo(CommandContext context) async => throw Exception('Undo error');

  @override
  String get name => 'UndoErrorCommand';

  @override
  String get description => 'Command that throws error on undo';
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

    test('should register and dispatch command successfully', () async {
      // Register handler
      commandBus.registerHandler(MockCommandHandler(), MockCommand);

      // Dispatch command
      final result = await commandBus.dispatch(MockCommand());

      expect(result.isSuccess, true);
    });

    test('should throw error when no handler registered', () async {
      final result = await commandBus.dispatch(MockCommand());
      expect(result.isSuccess, false);
      expect(result.error, contains('CommandHandlerNotFoundException'));
    });

    test('should execute middleware', () async {
      final middleware = MockMiddleware();
      commandBus
        ..addMiddleware(middleware)
        ..registerHandler(MockCommandHandler(), MockCommand);

      await commandBus.dispatch(MockCommand());

      expect(middleware.beforeCount, 1);
      expect(middleware.afterCount, 1);
    });

    test('should handle command execution error', () async {
      commandBus.registerHandler(ErrorCommandHandler(), ErrorCommand);

      final result = await commandBus.dispatch(ErrorCommand());
      expect(result.isSuccess, false);
      expect(result.error, contains('Command error'));
    });

    test('should undo command if undoable', () async {
      final command = UndoableCommand();
      commandBus.registerHandler(MockCommandHandler(), UndoableCommand);

      await commandBus.dispatch(command);
      await commandBus.undo(command);

      expect(command.undone, true);
    });

    test('should throw error when undoing non-undoable command', () async {
      final command = NonUndoableCommand();
      commandBus.registerHandler(MockCommandHandler(), NonUndoableCommand);

      await commandBus.dispatch(command);
      expect(() => commandBus.undo(command), throwsA(isA<UnsupportedError>()));
    });

    test('should handle undo error', () async {
      final command = UndoErrorCommand();
      commandBus.registerHandler(MockCommandHandler(), UndoErrorCommand);

      await commandBus.dispatch(command);
      expect(() => commandBus.undo(command), throwsA(isA<Exception>()));
    });

    test('should dispose resources', () {
      commandBus.dispose();
      expect(() => commandBus.registerHandler(MockCommandHandler(), MockCommand), throwsA(isA<StateError>()));
    });

    test('should emit command events', () async {
      final events = <CommandEvent>[];
      commandBus.commandStream.listen(events.add);

      commandBus.registerHandler(MockCommandHandler(), MockCommand);
      await commandBus.dispatch(MockCommand());

      expect(events.length, greaterThanOrEqualTo(1)); // At least CommandStarted
      expect(events[0], isA<CommandStarted>());
      // Check if we have CommandSucceeded or CommandFailed
      if (events.length > 1) {
        expect(events[1], isA<CommandSucceeded>());
      }
    });
  });
}
