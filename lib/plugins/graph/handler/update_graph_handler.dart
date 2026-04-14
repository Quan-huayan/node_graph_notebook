import '../../../../core/models/graph.dart';
import '../../../core/cqrs/commands/models/command.dart';
import '../../../core/cqrs/commands/models/command_context.dart';
import '../../../core/cqrs/commands/models/command_handler.dart';
import '../command/graph_commands.dart';
import '../service/graph_service.dart';

/// 更新图处理器
///
/// 处理更新图配置的命令
class UpdateGraphHandler implements CommandHandler<UpdateGraphCommand> {
  /// 构造函数
  ///
  /// [_service] - 图形服务，用于获取和更新图
  UpdateGraphHandler(this._service);

  final GraphService _service;

  @override
  Future<CommandResult<Graph>> execute(
    UpdateGraphCommand command,
    CommandContext context,
  ) async {
    try {
      // 保存旧图状态（用于撤销）
      final oldGraph = await _service.getGraph(command.graphId);
      if (oldGraph == null) {
        return CommandResult.failure('图不存在: ${command.graphId}');
      }
      command.oldGraph = oldGraph;

      // 更新图
      final updatedGraph = await _service.updateGraph(
        command.graphId,
        name: command.updatedName,
        nodeIds: command.nodeIds,
        viewConfig: command.viewConfig,
        nodePositions: command.nodePositions,
      );

      return CommandResult.success(updatedGraph);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
