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
  String get name => '测试命令';

  @override
  String get description => '用于验证中间件测试的命令';
}

class AnotherCommand extends Command<dynamic> {
  @override
  Future<CommandResult<dynamic>> execute(CommandContext context) async =>
      CommandResult.success();

  @override
  String get name => '另一个命令';

  @override
  String get description => '另一个测试命令';
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

    test('应该通过没有验证器的命令', () async {
      final command = TestCommand();

      await middleware.processBefore(command, context);
    });

    test('应该通过带有通过验证器的命令', () async {
      final command = TestCommand();
      middleware.registerValidator<TestCommand>(
        TestCommandValidator(shouldPass: true),
      );

      await middleware.processBefore(command, context);
    });

    test('当验证失败时应该抛出异常', () async {
      final command = TestCommand();
      middleware.registerValidator<TestCommand>(
        TestCommandValidator(shouldPass: false),
      );

      expect(
        () => middleware.processBefore(command, context),
        throwsA(isA<CommandValidationException>()),
      );
    });

    test('应该验证命令值', () async {
      final emptyCommand = TestCommand(value: '');
      final validCommand = TestCommand(value: 'test');
      middleware.registerValidator<TestCommand>(ValueValidator());

      expect(
        () => middleware.processBefore(emptyCommand, context),
        throwsA(isA<CommandValidationException>()),
      );

      await middleware.processBefore(validCommand, context);
    });

    test('应该只验证已注册的命令类型', () async {
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

    test('应该允许不同类型有多个验证器', () async {
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
    test('应该创建成功结果', () {
      final result = ValidationResult.success();

      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });

    test('应该创建带有多个错误的失败结果', () {
      final result = ValidationResult.failure(['错误 1', '错误 2']);

      expect(result.isValid, false);
      expect(result.errors.length, 2);
      expect(result.errors, contains('错误 1'));
      expect(result.errors, contains('错误 2'));
    });

    test('应该创建单个错误结果', () {
      final result = ValidationResult.singleError('单个错误');

      expect(result.isValid, false);
      expect(result.errors.length, 1);
      expect(result.errors.first, '单个错误');
    });
  });

  group('CommandValidationException', () {
    test('应该包含命令和错误', () {
      final command = TestCommand();
      final errors = ['错误 1', '错误 2'];
      final exception = CommandValidationException(
        command: command,
        errors: errors,
      );

      expect(exception.command, command);
      expect(exception.errors, errors);
    });

    test('应该正确格式化toString', () {
      final command = TestCommand();
      final exception = CommandValidationException(
        command: command,
        errors: ['错误 1', '错误 2'],
      );

      expect(exception.toString(), contains('测试命令'));
      expect(exception.toString(), contains('错误 1'));
      expect(exception.toString(), contains('错误 2'));
    });
  });
}
