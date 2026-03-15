import '../../../../core/commands/command.dart';
import '../../../../core/commands/command_context.dart';
import '../../../../core/commands/command_handler.dart';
import '../command/node_commands.dart';
import '../service/node_service.dart';
import '../../../../core/events/app_events.dart';

/// 删除节点处理器
///
/// 处理删除节点的命令，包含级联删除连接和事件发布
class DeleteNodeHandler implements CommandHandler<DeleteNodeCommand> {
  DeleteNodeHandler(this._service);

  final NodeService _service;

  @override
  Future<CommandResult<void>> execute(
    DeleteNodeCommand command,
    CommandContext context,
  ) async {
    try {
      // 删除节点
      await _service.deleteNode(command.node.id);

      // 发布事件
      context.eventBus.publish(NodeDataChangedEvent(
        changedNodes: [command.node],
        action: DataChangeAction.delete,
      ));

      return CommandResult.success();
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
