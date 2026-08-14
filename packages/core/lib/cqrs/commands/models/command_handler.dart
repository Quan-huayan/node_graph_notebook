import 'command.dart';
import 'command_context.dart';

/// 命令处理器接口
///
/// 定义如何处理特定类型的命令
/// 每个命令类型应该有对应的处理器实现
abstract class CommandHandler<T extends Command> {
  /// 执行命令
  ///
  /// [command] 要执行的命令对象
  /// [context] 执行上下文，提供所需的服务和依赖
  ///
  /// 返回命令执行结果
  Future<CommandResult> execute(T command, CommandContext context);
}

/// 命令处理器未找到异常
///
/// 当尝试执行没有注册处理器的命令时抛出
class CommandHandlerNotFoundException implements Exception {
  /// 创建一个命令处理器未找到异常
  ///
  /// [commandType] - 命令类型
  CommandHandlerNotFoundException(this.commandType);

  /// 命令类型
  final Type commandType;

  @override
  String toString() =>
      'CommandHandlerNotFoundException: '
      '未找到命令 $commandType 的处理器';
}
