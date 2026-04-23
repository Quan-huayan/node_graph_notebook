import '../cqrs/commands/models/command.dart';
import '../cqrs/commands/models/command_context.dart';
import '../cqrs/commands/models/middleware.dart';
import '../utils/logger.dart';

/// 事务中间件日志记录器
const _log = AppLogger('TransactionMiddleware');

/// 事务中间件
///
/// 确保命令执行的原子性：
/// - 如果命令执行失败，自动撤销已执行的操作
/// - 支持嵌套事务
///
/// 注意：此中间件依赖于命令的 undo 方法实现
class TransactionMiddleware extends CommandMiddlewareBase {
  @override
  Future<void> processBefore(Command command, CommandContext context) async {
    // 标记事务开始
    context..setMetadata('_transaction_active', true)
    ..setMetadata('_transaction_command', command);
  }

  @override
  Future<void> processAfter(
    Command command,
    CommandContext context,
    CommandResult result,
  ) async {
    context.setMetadata('_transaction_active', null);
    context.setMetadata('_transaction_command', null);

    if (!result.isSuccess && command.isUndoable) {
      try {
        await command.undo(context);
      } catch (e) {
        // 撤销失败时忽略异常，因为事务已经失败
        _log.warning('Undo failed during transaction rollback', error: e);
      }
    }
  }
}
