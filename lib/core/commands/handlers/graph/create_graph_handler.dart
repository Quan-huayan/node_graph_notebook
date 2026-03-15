import '../../command.dart';
import '../../command_context.dart';
import '../../command_handler.dart';
import '../../../models/graph.dart';
import '../../../services/graph_service.dart';
import '../../impl/graph_commands.dart';

/// 创建图处理器
///
/// 处理创建图的命令，包含验证逻辑
class CreateGraphHandler implements CommandHandler<CreateGraphCommand> {
  CreateGraphHandler(this._service);

  final GraphService _service;

  @override
  Future<CommandResult<Graph>> execute(
    CreateGraphCommand command,
    CommandContext context,
  ) async {
    try {
      // 验证图名
      if (command.graphName.trim().isEmpty) {
        return CommandResult.failure('图名称不能为空');
      }

      // 创建图
      final graph = await _service.createGraph(name: command.graphName);

      // TODO: 发布图变化事件（需要定义新的事件类型）

      return CommandResult.success(graph);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
