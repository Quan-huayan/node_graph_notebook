import '../../../../core/commands/command.dart';
import '../../../../core/commands/command_context.dart';
import '../../../../core/commands/command_handler.dart';
import '../service/graph_service.dart';
import '../../../../core/events/app_events.dart';
import '../command/graph_commands.dart';

/// 添加节点到图处理器
///
/// 处理将节点添加到图的命令
class AddNodeToGraphHandler implements CommandHandler<AddNodeToGraphCommand> {
  AddNodeToGraphHandler(this._service);

  final GraphService _service;

  @override
  Future<CommandResult<void>> execute(
    AddNodeToGraphCommand command,
    CommandContext context,
  ) async {
    try {
      // 添加节点到图
      await _service.addNodeToGraph(command.graphId, command.nodeId);

      // 发布事件
      context.eventBus.publish(GraphNodeRelationChangedEvent(
        graphId: command.graphId,
        nodeIds: [command.nodeId],
        action: RelationChangeAction.addedToGraph,
      ));

      return CommandResult.success(null);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
