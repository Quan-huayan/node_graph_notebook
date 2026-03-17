import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/models/command.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/middleware/validation_middleware.dart';

class TestCommand extends Command<dynamic> {
  TestCommand({this.value = ''});

  final String value;

  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async =>
      CommandResult.success();

  @override
  String get name => 'TestCommand';

  @override
  String get description => 'Test command for validation';
}

class AnotherCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async =>
      CommandResult.success();

  @override
  String get name => 'AnotherCommand';

  @override
  String get description => 'Another test command';
}

class TestCommandValidator extends CommandValidator<TestCommand> {

  TestCommandValidator({this.shouldPass = true});
  final bool shouldPass;

  @override
  Future<ValidationResult> validate(
    TestCommand command,
    CommandContext context,
  ) async {
    if (shouldPass) {
      return ValidationResult.success();
    }
    return ValidationResult.failure(['Validation failed', 'Value is invalid']);
  }
}

class ValueValidator extends CommandValidator<TestCommand> {
  @override
  Future<ValidationResult> validate(
    TestCommand command,
    CommandContext context,
  ) async {
    if (command.value.isEmpty) {
      return ValidationResult.singleError('Value cannot be empty');
    }
    return ValidationResult.success();
  }
}

void main() {
  group('ValidationMiddleware', () {
    late ValidationMiddleware middleware;
    late CommandContext context;

    setUp(() {
      middleware = ValidationMiddleware();
      context = CommandContext();
    });

    test('should pass command without validator', () async {
      final command = TestCommand();

      await middleware.processBefore(command, context);
    });

    test('should pass command with passing validator', () async {
      final command = TestCommand();
      middleware.registerValidator<TestCommand>(
        TestCommandValidator(shouldPass: true),
      );

      await middleware.processBefore(command, context);
    });

    test('should throw exception when validation fails', () async {
      final command = TestCommand();
      middleware.registerValidator<TestCommand>(
        TestCommandValidator(shouldPass: false),
      );

      expect(
        () => middleware.processBefore(command, context),
        throwsA(isA<CommandValidationException>()),
      );
    });

    test('should validate command value', () async {
      final emptyCommand = TestCommand(value: '');
      final validCommand = TestCommand(value: 'test');
      middleware.registerValidator<TestCommand>(ValueValidator());

      expect(
        () => middleware.processBefore(emptyCommand, context),
        throwsA(isA<CommandValidationException>()),
      );

      await middleware.processBefore(validCommand, context);
    });

    test('should only validate registered command types', () async {
      final testCommand = TestCommand();
      final anotherCommand = AnotherCommand();

      middleware.registerValidator<TestCommand>(
        TestCommandValidator(shouldPass: false),
      );

      expect(
        () => middleware.processBefore(testCommand, context),
        throwsA(isA<CommandValidationException>()),
      );

      await middleware.processBefore(anotherCommand, context);
    });

    test('should allow multiple validators for different types', () async {
      final testCommand = TestCommand();
      final anotherCommand = AnotherCommand();

      middleware.registerValidator<TestCommand>(
        TestCommandValidator(shouldPass: true),
      );

      await middleware.processBefore(testCommand, context);
      await middleware.processBefore(anotherCommand, context);
    });
  });

  group('ValidationResult', () {
    test('should create success result', () {
      final result = ValidationResult.success();

      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });

    test('should create failure result with multiple errors', () {
      final result = ValidationResult.failure(['Error 1', 'Error 2']);

      expect(result.isValid, false);
      expect(result.errors.length, 2);
      expect(result.errors, contains('Error 1'));
      expect(result.errors, contains('Error 2'));
    });

    test('should create single error result', () {
      final result = ValidationResult.singleError('Single error');

      expect(result.isValid, false);
      expect(result.errors.length, 1);
      expect(result.errors.first, 'Single error');
    });
  });

  group('CommandValidationException', () {
    test('should contain command and errors', () {
      final command = TestCommand();
      final errors = ['Error 1', 'Error 2'];
      final exception = CommandValidationException(
        command: command,
        errors: errors,
      );

      expect(exception.command, command);
      expect(exception.errors, errors);
    });

    test('should format toString correctly', () {
      final command = TestCommand();
      final exception = CommandValidationException(
        command: command,
        errors: ['Error 1', 'Error 2'],
      );

      expect(exception.toString(), contains('TestCommand'));
      expect(exception.toString(), contains('Error 1'));
      expect(exception.toString(), contains('Error 2'));
    });
  });
}
