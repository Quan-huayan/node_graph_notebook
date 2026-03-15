import '../../command.dart';
import '../../command_context.dart';
import '../../command_handler.dart';
import '../../../models/graph.dart';
import '../../../services/graph_service.dart';
import '../../impl/graph_commands.dart';

/// 更新图处理器
///
/// 处理更新图配置的命令
class UpdateGraphHandler implements CommandHandler<UpdateGraphCommand> {
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
