import '../command.dart';
import '../command_context.dart';
import '../command_handler.dart';
import '../impl/node_commands.dart';
import '../../models/node.dart';
import '../../services/node_service.dart';
import '../../events/app_events.dart';

/// 更新节点处理器
///
/// 处理更新节点的命令，包含验证逻辑和事件发布
class UpdateNodeHandler implements CommandHandler<UpdateNodeCommand> {
  UpdateNodeHandler(this._service);

  final NodeService _service;

  @override
  Future<CommandResult<Node>> execute(
    UpdateNodeCommand command,
    CommandContext context,
  ) async {
    try {
      // 验证节点ID
      if (command.oldNode.id != command.newNode.id) {
        return CommandResult.failure('节点ID不匹配');
      }

      // 更新节点
      // NodeService.updateNode 需要 nodeId 和命名参数，而不是 Node 对象
      await _service.updateNode(
        command.newNode.id,
        title: command.newNode.title,
        content: command.newNode.content,
        position: command.newNode.position,
        size: command.newNode.size,
        viewMode: command.newNode.viewMode,
        color: command.newNode.color,
        metadata: command.newNode.metadata,
      );

      // 发布事件
      context.eventBus.publish(NodeDataChangedEvent(
        changedNodes: [command.newNode],
        action: DataChangeAction.update,
      ));

      return CommandResult.success(command.newNode);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
