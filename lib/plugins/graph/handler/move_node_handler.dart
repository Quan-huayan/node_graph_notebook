import '../../../../core/commands/models/command.dart';
import '../../../../core/commands/models/command_context.dart';
import '../../../../core/commands/models/command_handler.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/repositories/node_repository.dart';
import '../command/node_commands.dart';

/// 移动节点处理器
///
/// 处理移动节点的命令，更新节点在图形中的位置
class MoveNodeHandler implements CommandHandler<MoveNodeCommand> {
  /// 构造函数
  ///
  /// [_repository] - 节点仓库，用于加载和保存节点
  MoveNodeHandler(this._repository);

  final NodeRepository _repository;

  @override
  Future<CommandResult<void>> execute(
    MoveNodeCommand command,
    CommandContext context,
  ) async {
    try {
      // 加载节点
      final node = await _repository.load(command.nodeId);
      if (node == null) {
        return CommandResult.failure('节点不存在: ${command.nodeId}');
      }

      // 保存旧位置（用于撤销）
      command.oldPosition = node.position;

      // 更新位置
      final updatedNode = node.copyWith(position: command.newPosition);

      await _repository.save(updatedNode);

      // 发布事件（使用便捷方法）
      context.publishSingleNodeEvent(updatedNode, DataChangeAction.update);

      return CommandResult.success();
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
