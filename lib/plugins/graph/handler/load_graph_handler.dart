import '../../../../core/models/graph.dart';
import '../../../core/cqrs/commands/models/command.dart';
import '../../../core/cqrs/commands/models/command_context.dart';
import '../../../core/cqrs/commands/models/command_handler.dart';
import '../command/graph_commands.dart';
import '../service/graph_service.dart';

/// 加载图处理器
///
/// 处理加载图的命令
class LoadGraphHandler implements CommandHandler<LoadGraphCommand> {
  /// 构造函数
  ///
  /// [_service] - 图形服务，用于加载图
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
