import '../../../core/cqrs/commands/events/app_events.dart';
import '../../../core/cqrs/commands/models/command.dart';
import '../../../core/cqrs/commands/models/command_context.dart';
import '../../../core/cqrs/commands/models/command_handler.dart';
import '../command/graph_commands.dart';
import '../service/graph_service.dart';

/// 从图中移除节点处理器
///
/// 处理从图中移除节点的命令
class RemoveNodeFromGraphHandler
    implements CommandHandler<RemoveNodeFromGraphCommand> {
  /// 构造函数
  ///
  /// [_service] - 图形服务，用于从图中移除节点
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

      // 发布事件（使用便捷方法）
      context.publishGraphRelationEvent(
        command.graphId,
        [command.nodeId],
        RelationChangeAction.removedFromGraph,
      );

      return CommandResult.success(null);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
