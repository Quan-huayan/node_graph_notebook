import 'package:core/cqrs/commands/models/command.dart';
import 'package:core/cqrs/commands/models/command_context.dart';
import 'package:core/cqrs/commands/models/command_handler.dart';

import '../command/graph_commands.dart';
import '../service/graph_service.dart';

/// 批量节点操作处理器
///
/// 处理批量添加和移出节点的命令
class BatchNodeOperationsHandler implements CommandHandler<BatchNodeOperationsCommand> {
  /// 构造函数
  ///
  /// [_service] - 图形服务，用于获取和更新图
  BatchNodeOperationsHandler(this._service);

  final GraphService _service;

  @override
  Future<CommandResult> execute(
    BatchNodeOperationsCommand command,
    CommandContext context,
  ) async {
    try {
      // 获取当前图
      final graph = await _service.getGraph(command.graphId);
      if (graph == null) {
        return CommandResult.failure('图不存在：${command.graphId}');
      }

      // 保存旧节点 ID 列表（用于撤销）
      command.oldNodeIds = List<String>.from(graph.nodeIds);

      // 复制当前节点 ID 列表
      final currentNodeIds = List<String>.from(graph.nodeIds);

      // 移出节点
      command.nodeIdsToMoveOut.forEach(currentNodeIds.remove);

      // 添加节点（去重）
      final nodeIdsToAddSet = command.nodeIdsToAdd.toSet();
      for (final nodeId in nodeIdsToAddSet) {
        if (!currentNodeIds.contains(nodeId)) {
          currentNodeIds.add(nodeId);
        }
      }

      // 更新图
      final updatedGraph = await _service.updateGraph(
        command.graphId,
        nodeIds: currentNodeIds,
      );

      return CommandResult.success(updatedGraph);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
