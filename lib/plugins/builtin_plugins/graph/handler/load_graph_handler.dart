import '../../../../core/commands/command.dart';
import '../../../../core/commands/command_context.dart';
import '../../../../core/commands/command_handler.dart';
import '../../../../core/models/graph.dart';
import '../service/graph_service.dart';
import '../command/graph_commands.dart';

/// 加载图处理器
///
/// 处理加载图的命令
class LoadGraphHandler implements CommandHandler<LoadGraphCommand> {
  LoadGraphHandler(this._service);

  final GraphService _service;

  @override
  Future<CommandResult<Graph>> execute(
    LoadGraphCommand command,
    CommandContext context,
  ) async {
    try {
      final graph = await _service.getGraph(command.graphId);

      if (graph == null) {
        return CommandResult.failure('图不存在: ${command.graphId}');
      }

      return CommandResult.success(graph);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
