import 'package:core/cqrs/commands/events/app_events.dart';
import 'package:core/cqrs/commands/models/command.dart';
import 'package:core/cqrs/commands/models/command_context.dart';
import 'package:core/cqrs/commands/models/command_handler.dart';
import '../command/graph_commands.dart';
import '../service/graph_service.dart';

/// 添加节点到图处理器
///
/// 处理将节点添加到图的命令
class AddNodeToGraphHandler implements CommandHandler<AddNodeToGraphCommand> {
  /// 构造函数
  ///
  /// [_service] - 图形服务，用于将节点添加到图
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

      context.publishEvent(GraphNodeRelationChangedEvent(
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
