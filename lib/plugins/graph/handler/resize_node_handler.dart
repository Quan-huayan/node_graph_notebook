import '../../../../core/repositories/node_repository.dart';
import '../../../core/cqrs/commands/events/app_events.dart';
import '../../../core/cqrs/commands/models/command.dart';
import '../../../core/cqrs/commands/models/command_context.dart';
import '../../../core/cqrs/commands/models/command_handler.dart';
import '../command/node_commands.dart';

/// 调整节点大小处理器
///
/// 处理调整节点大小的命令
class ResizeNodeHandler implements CommandHandler<ResizeNodeCommand> {
  /// 构造函数
  ///
  /// [_repository] - 节点仓库，用于加载和保存节点
  ResizeNodeHandler(this._repository);

  final NodeRepository _repository;

  @override
  Future<CommandResult<void>> execute(
    ResizeNodeCommand command,
    CommandContext context,
  ) async {
    try {
      // 加载节点
      final node = await _repository.load(command.nodeId);
      if (node == null) {
        return CommandResult.failure('节点不存在: ${command.nodeId}');
      }

      // 保存旧大小（用于撤销）
      command.oldSize = node.size;

      // 更新大小
      final updatedNode = node.copyWith(size: command.newSize);

      await _repository.save(updatedNode);

      // 发布事件（使用便捷方法）
      context.publishSingleNodeEvent(updatedNode, DataChangeAction.update);

      return CommandResult.success();
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
