import '../commands/models/command.dart';
import '../commands/models/command_context.dart';
import '../commands/models/middleware.dart';

/// 验证中间件
///
/// 在命令执行前进行参数验证
/// 如果验证失败，抛出 [CommandValidationException]
class ValidationMiddleware extends CommandMiddlewareBase {
  /// 验证器注册表
  final Map<Type, CommandValidator> _validators = {};

  /// 注册验证器
  ///
  /// [T] 命令类型
  /// [validator] 验证器实例
  void registerValidator<T extends Command>(CommandValidator<T> validator) {
    _validators[T] = validator;
  }

  @override
  Future<void> processBefore(Command command, CommandContext context) async {
    final validator = _validators[command.runtimeType];
    if (validator != null) {
      final result = await validator.validate(command, context);
      if (!result.isValid) {
        throw CommandValidationException(
          command: command,
          errors: result.errors,
        );
      }
    }
  }
}

/// 命令验证器接口
///
/// 定义如何验证特定类型的命令
abstract class CommandValidator<T extends Command> {
  /// 验证命令
  ///
  /// [command] 要验证的命令
  /// [context] 执行上下文
  ///
  /// 返回验证结果
  Future<ValidationResult> validate(T command, CommandContext context);
}

/// 验证结果
///
/// 封装验证的结果信息
class ValidationResult {
  ValidationResult._({required this.isValid, required this.errors});

  /// 创建成功的验证结果
  factory ValidationResult.success() => ValidationResult._(isValid: true, errors: []);

  /// 创建失败的验证结果
  factory ValidationResult.failure(List<String> errors) => ValidationResult._(isValid: false, errors: errors);

  /// 创建单个错误的验证结果
  factory ValidationResult.singleError(String error) => ValidationResult.failure([error]);

  /// 是否通过验证
  final bool isValid;

  /// 错误信息列表
  ///
  /// 如果验证通过，此列表为空
  final List<String> errors;
}

/// 命令验证异常
///
/// 当命令验证失败时抛出
class CommandValidationException implements Exception {
  /// 创建命令验证异常
  ///
  /// [command] 被验证的命令
  /// [errors] 验证错误列表
  CommandValidationException({required this.command, required this.errors});

  /// 被验证的命令
  final Command command;

  /// 验证错误列表
  final List<String> errors;

  @override
  String toString() =>
      'CommandValidationException: '
      '命令 ${command.name} 验证失败: ${errors.join(', ')}';
}
