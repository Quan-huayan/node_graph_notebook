import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command.dart';
import 'package:node_graph_notebook/core/commands/command_context.dart';
import 'package:node_graph_notebook/core/commands/middleware/logging_middleware.dart';
import 'package:node_graph_notebook/core/commands/middleware/transaction_middleware.dart';
import 'package:node_graph_notebook/core/commands/middleware/validation_middleware.dart';

// 测试用命令
class TestCommand extends Command<String> {
  @override
  String get name => 'TestCommand';

  @override
  String get description => 'Test command for middleware';

  @override
  Future<CommandResult<String>> execute(CommandContext context) async {
    return CommandResult.success('result');
  }

  bool undoCalled = false;

  @override
  Future<void> undo(CommandContext context) async {
    undoCalled = true;
  }
}

void main() {
  group('LoggingMiddleware', () {
    late LoggingMiddleware middleware;
    late CommandContext context;
    late TestCommand command;

    setUp(() {
      middleware = LoggingMiddleware();
      context = CommandContext();
      command = TestCommand();
    });

    test('应该记录命令开始', () async {
      // Act
      await middleware.processBefore(command, context);

      // Assert - 验证没有抛出异常
      // 日志记录到 developer.log，无法直接测试
      expect(middleware, isNotNull);
    });

    test('应该记录命令成功', () async {
      // Arrange
      final result = CommandResult.success('test');

      // Act
      await middleware.processBefore(command, context);
      await middleware.processAfter(command, context, result);

      // Assert
      expect(result.isSuccess, true);
    });

    test('应该记录命令失败', () async {
      // Arrange
      final result = CommandResult.failure('Test error');

      // Act
      await middleware.processBefore(command, context);
      await middleware.processAfter(command, context, result);

      // Assert
      expect(result.isSuccess, false);
    });

    test('应该支持不同的日志级别', () async {
      // Arrange
      final debugMiddleware = LoggingMiddleware(logLevel: LogLevel.debug);
      final errorMiddleware = LoggingMiddleware(logLevel: LogLevel.error);
      final noneMiddleware = LoggingMiddleware(logLevel: LogLevel.none);

      // Act & Assert - 验证创建成功
      expect(debugMiddleware, isNotNull);
      expect(errorMiddleware, isNotNull);
      expect(noneMiddleware, isNotNull);
    });
  });

  group('ValidationMiddleware', () {
    late ValidationMiddleware middleware;
    late CommandContext context;
    late TestCommand command;

    setUp(() {
      middleware = ValidationMiddleware();
      context = CommandContext();
      command = TestCommand();
    });

    test('应该执行注册的验证器', () async {
      // Arrange
      final validator = _TestValidator(shouldPass: true);
      middleware.registerValidator<TestCommand>(validator);

      // Act - 不应该抛出异常
      await middleware.processBefore(command, context);

      // Assert
      expect(validator.called, true);
    });

    test('验证失败应该抛出异常', () async {
      // Arrange
      final validator = _TestValidator(shouldPass: false);
      middleware.registerValidator<TestCommand>(validator);

      // Act & Assert
      expect(
        () => middleware.processBefore(command, context),
        throwsA(isA<CommandValidationException>()),
      );
    });

    test('未注册验证器的命令应该通过', () async {
      // Act - 不应该抛出异常
      await middleware.processBefore(command, context);

      // Assert - 如果没有抛出异常，测试通过
      expect(true, true);
    });

    test('应该返回验证错误信息', () async {
      // Arrange
      final validator = _TestValidator(
        shouldPass: false,
        errors: ['Error 1', 'Error 2'],
      );
      middleware.registerValidator<TestCommand>(validator);

      // Act & Assert
      try {
        await middleware.processBefore(command, context);
        fail('应该抛出异常');
      } on CommandValidationException catch (e) {
        expect(e.errors.length, 2);
        expect(e.errors, contains('Error 1'));
        expect(e.errors, contains('Error 2'));
      }
    });
  });

  group('TransactionMiddleware', () {
    late TransactionMiddleware middleware;
    late CommandContext context;
    late TestCommand command;

    setUp(() {
      middleware = TransactionMiddleware();
      context = CommandContext();
      command = TestCommand();
    });

    test('应该标记事务开始', () async {
      // Act
      await middleware.processBefore(command, context);

      // Assert
      expect(context.getMetadata('_transaction_active'), true);
      expect(context.getMetadata('_transaction_command'), command);
    });

    test('命令成功后应该清除事务标记', () async {
      // Arrange
      final result = CommandResult.success('test');

      // Act
      await middleware.processBefore(command, context);
      await middleware.processAfter(command, context, result);

      // Assert
      expect(context.getMetadata('_transaction_active'), null);
      expect(context.getMetadata('_transaction_command'), null);
    });

    test('命令失败且可撤销时应该自动撤销', () async {
      // Arrange
      final result = CommandResult.failure('Test error');

      // Act
      await middleware.processBefore(command, context);
      await middleware.processAfter(command, context, result);

      // Assert
      expect(command.undoCalled, true);
    });

    test('命令失败但不可撤销时不应该撤销', () async {
      // Arrange
      final nonUndoableCommand = _NonUndoableCommand();
      final result = CommandResult.failure('Test error');

      // Act
      await middleware.processBefore(nonUndoableCommand, context);
      await middleware.processAfter(nonUndoableCommand, context, result);

      // Assert - 不应该抛出异常
      expect(true, true);
    });

    test('命令成功时不需要撤销', () async {
      // Arrange
      final result = CommandResult.success('test');

      // Act
      await middleware.processBefore(command, context);
      await middleware.processAfter(command, context, result);

      // Assert
      expect(command.undoCalled, false);
    });
  });

  group('ValidationResult', () {
    test('应该创建成功的验证结果', () {
      // Act
      final result = ValidationResult.success();

      // Assert
      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });

    test('应该创建失败的验证结果', () {
      // Arrange
      final errors = ['Error 1', 'Error 2'];

      // Act
      final result = ValidationResult.failure(errors);

      // Assert
      expect(result.isValid, false);
      expect(result.errors, errors);
    });

    test('应该创建单个错误的验证结果', () {
      // Arrange
      final error = 'Single error';

      // Act
      final result = ValidationResult.singleError(error);

      // Assert
      expect(result.isValid, false);
      expect(result.errors, [error]);
    });
  });
}

// 测试用验证器
class _TestValidator implements CommandValidator<TestCommand> {
  _TestValidator({required this.shouldPass, this.errors = const []});

  final bool shouldPass;
  final List<String> errors;
  bool called = false;

  @override
  Future<ValidationResult> validate(TestCommand command, CommandContext context) async {
    called = true;
    if (shouldPass) {
      return ValidationResult.success();
    } else {
      return ValidationResult.failure(errors);
    }
  }
}

// 不可撤销的测试命令
class _NonUndoableCommand extends Command<String> {
  @override
  String get name => 'NonUndoableCommand';

  @override
  String get description => 'Non-undoable command';

  @override
  bool get isUndoable => false;

  @override
  Future<CommandResult<String>> execute(CommandContext context) async {
    return CommandResult.success('result');
  }
}
