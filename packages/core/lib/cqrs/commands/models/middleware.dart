import 'command.dart';
import 'command_context.dart';

/// 命令中间件接口
///
/// 中间件可以在命令执行前后添加横切关注点
/// 例如：日志、验证、事务、性能监控等
abstract class CommandMiddleware {
  /// 命令执行前处理
  ///
  /// [command] 即将执行的命令
  /// [context] 执行上下文
  ///
  /// 可以修改上下文或抛出异常阻止命令执行
  Future<void> processBefore(Command command, CommandContext context);

  /// 命令执行后处理
  ///
  /// [command] 已执行的命令
  /// [context] 执行上下文
  /// [result] 执行结果
  ///
  /// 可以修改结果或执行清理操作
  Future<void> processAfter(
    Command command,
    CommandContext context,
    CommandResult result,
  );
}

/// 中间件基类
///
/// 提供默认实现，子类只需重写需要的方法
abstract class CommandMiddlewareBase implements CommandMiddleware {
  @override
  Future<void> processBefore(Command command, CommandContext context) async {
    // 默认不做任何处理
  }

  @override
  Future<void> processAfter(
    Command command,
    CommandContext context,
    CommandResult result,
  ) async {
    // 默认不做任何处理
  }
}
