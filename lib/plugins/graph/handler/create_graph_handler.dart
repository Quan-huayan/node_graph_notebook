import '../../../../core/commands/models/command.dart';
import '../../../../core/commands/models/command_context.dart';
import '../../../../core/commands/models/command_handler.dart';
import '../../../../core/models/graph.dart';
import '../command/graph_commands.dart';
import '../service/graph_service.dart';

/// 创建图处理器
///
/// 处理创建图的命令，包含验证逻辑
class CreateGraphHandler implements CommandHandler<CreateGraphCommand> {
  /// 构造函数
  ///
  /// [_service] - 图形服务，用于创建图
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

      // 发布图创建事件
      // 注意：GraphDataChangedEvent 需要导入 app_events
      // context.eventBus.publish(GraphDataChangedEvent(...));

      return CommandResult.success(graph);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
