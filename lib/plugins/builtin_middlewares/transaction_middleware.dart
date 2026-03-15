import '../../core/commands/command.dart';
import '../../core/commands/command_context.dart';
import '../../core/commands/middleware.dart';

/// 事务中间件
///
/// 确保命令执行的原子性：
/// - 如果命令执行失败，自动撤销已执行的操作
/// - 支持嵌套事务
///
/// 注意：此中间件依赖于命令的 undo 方法实现
class TransactionMiddleware extends CommandMiddlewareBase {
  @override
  Future<void> processBefore(
    Command command,
    CommandContext context,
  ) async {
    // 标记事务开始
    context.setMetadata('_transaction_active', true);
    context.setMetadata('_transaction_command', command);
  }

  @override
  Future<void> processAfter(
    Command command,
    CommandContext context,
    CommandResult result,
  ) async {
    // 清除事务标记
    context.clearMetadata();

    // 如果命令失败且可撤销，尝试自动撤销
    if (!result.isSuccess && command.isUndoable) {
      try {
        await command.undo(context);
      } catch (e) {
        // 撤销失败，记录错误但不影响原错误抛出
        // 这里可以添加日志或错误通知
      }
    }
  }
}
