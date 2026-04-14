import '../../../core/cqrs/commands/events/app_events.dart';
import '../../../core/cqrs/commands/models/command.dart';
import '../../../core/cqrs/commands/models/command_context.dart';
import '../../../core/cqrs/commands/models/command_handler.dart';
import '../command/node_commands.dart';
import '../service/node_service.dart';

/// 删除节点处理器
///
/// 处理删除节点的命令，包含级联删除连接和事件发布
class DeleteNodeHandler implements CommandHandler<DeleteNodeCommand> {
  /// 构造函数
  ///
  /// [_service] - 节点服务，用于删除节点
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

      // 发布事件（使用便捷方法）
      context.publishSingleNodeEvent(command.node, DataChangeAction.delete);

      return CommandResult.success();
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
