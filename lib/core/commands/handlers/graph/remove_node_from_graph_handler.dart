import '../../command.dart';
import '../../command_context.dart';
import '../../command_handler.dart';
import '../../../services/graph_service.dart';
import '../../../events/app_events.dart';
import '../../impl/graph_commands.dart';

/// 从图中移除节点处理器
///
/// 处理从图中移除节点的命令
class RemoveNodeFromGraphHandler implements CommandHandler<RemoveNodeFromGraphCommand> {
  RemoveNodeFromGraphHandler(this._service);

  final GraphService _service;

  @override
  Future<CommandResult<void>> execute(
    RemoveNodeFromGraphCommand command,
    CommandContext context,
  ) async {
    try {
      // 从图中移除节点
      await _service.removeNodeFromGraph(command.graphId, command.nodeId);

      // 发布事件
      context.eventBus.publish(GraphNodeRelationChangedEvent(
        graphId: command.graphId,
        nodeIds: [command.nodeId],
        action: RelationChangeAction.removedFromGraph,
      ));

      return CommandResult.success(null);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
