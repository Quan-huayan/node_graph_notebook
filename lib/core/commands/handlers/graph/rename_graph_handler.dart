import '../../command.dart';
import '../../command_context.dart';
import '../../command_handler.dart';
import '../../../models/graph.dart';
import '../../../services/graph_service.dart';
import '../../impl/graph_commands.dart';

/// 重命名图处理器
///
/// 处理重命名图的命令
class RenameGraphHandler implements CommandHandler<RenameGraphCommand> {
  RenameGraphHandler(this._service);

  final GraphService _service;

  @override
  Future<CommandResult<Graph>> execute(
    RenameGraphCommand command,
    CommandContext context,
  ) async {
    try {
      // 验证新名称
      if (command.updatedName.trim().isEmpty) {
        return CommandResult.failure('图名称不能为空');
      }

      // 获取当前图
      final currentGraph = await _service.getGraph(command.graphId);
      if (currentGraph == null) {
        return CommandResult.failure('图不存在: ${command.graphId}');
      }

      // 保存旧名称（用于撤销）
      command.previousName = currentGraph.name;

      // 更新图名称
      final updatedGraph = await _service.updateGraph(
        command.graphId,
        name: command.updatedName,
      );

      return CommandResult.success(updatedGraph);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
