import '../../../../core/commands/command.dart';
import '../../../../core/commands/command_context.dart';
import '../../../../core/commands/command_handler.dart';
import '../command/node_commands.dart';
import '../../../../core/repositories/node_repository.dart';
import '../../../../core/events/app_events.dart';

/// 调整节点大小处理器
///
/// 处理调整节点大小的命令
class ResizeNodeHandler implements CommandHandler<ResizeNodeCommand> {
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
      final updatedNode = node.copyWith(
        size: command.newSize,
      );

      await _repository.save(updatedNode);

      // 发布事件
      context.eventBus.publish(NodeDataChangedEvent(
        changedNodes: [updatedNode],
        action: DataChangeAction.update,
      ));

      return CommandResult.success();
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
