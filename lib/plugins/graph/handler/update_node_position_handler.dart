import 'package:flutter/material.dart';
import '../../../../core/commands/models/command.dart';
import '../../../../core/commands/models/command_context.dart';
import '../../../../core/commands/models/command_handler.dart';
import '../../../../core/repositories/graph_repository.dart';
import '../../layout/event/layout_events.dart';
import '../command/graph_commands.dart';

/// 更新节点位置处理器
///
/// 处理更新图中节点位置的命令
class UpdateNodePositionHandler
    implements CommandHandler<UpdateNodePositionCommand> {
  /// 构造函数
  ///
  /// [_repository] - 图形仓库，用于加载和保存图
  UpdateNodePositionHandler(this._repository);

  final GraphRepository _repository;

  @override
  Future<CommandResult<void>> execute(
    UpdateNodePositionCommand command,
    CommandContext context,
  ) async {
    try {
      // 加载图
      final graph = await _repository.load(command.graphId);
      if (graph == null) {
        return CommandResult.failure('图不存在: ${command.graphId}');
      }

      // 保存旧位置（用于撤销）
      command.oldPosition = graph.nodePositions[command.nodeId];

      // 更新节点位置
      final updatedPositions = Map<String, Offset>.from(graph.nodePositions);
      updatedPositions[command.nodeId] = command.newPosition;

      final updatedGraph = graph.copyWith(nodePositions: updatedPositions);
      await _repository.save(updatedGraph);

      // 发布节点位置变化事件（使用新API）
      context.publishEvent(
        NodePositionsChangedEvent(nodeIds: [command.nodeId]),
      );

      return CommandResult.success(null);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
