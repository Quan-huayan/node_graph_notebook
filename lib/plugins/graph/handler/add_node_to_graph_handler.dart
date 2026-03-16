import '../../../../core/commands/models/command.dart';
import '../../../../core/commands/models/command_context.dart';
import '../../../../core/commands/models/command_handler.dart';
import '../../../../core/events/app_events.dart';
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

      // 发布事件（使用便捷方法）
      context.publishGraphRelationEvent(
        command.graphId,
        [command.nodeId],
        RelationChangeAction.addedToGraph,
      );

      return CommandResult.success(null);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
