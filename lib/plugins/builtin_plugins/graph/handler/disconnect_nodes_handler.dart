import '../../../../core/commands/command.dart';
import '../../../../core/commands/command_context.dart';
import '../../../../core/commands/command_handler.dart';
import '../command/node_commands.dart';
import '../../../../core/models/node_reference.dart';
import '../../../../core/repositories/node_repository.dart';
import '../../../../core/events/app_events.dart';

/// 断开节点连接处理器
///
/// 处理断开节点连接的命令，移除节点间的引用关系
class DisconnectNodesHandler implements CommandHandler<DisconnectNodesCommand> {
  DisconnectNodesHandler(this._repository);

  final NodeRepository _repository;

  @override
  Future<CommandResult<void>> execute(
    DisconnectNodesCommand command,
    CommandContext context,
  ) async {
    try {
      // 加载源节点
      final sourceNode = await _repository.load(command.sourceId);
      if (sourceNode == null) {
        return CommandResult.failure('源节点不存在: ${command.sourceId}');
      }

      // 查找要删除的引用
      // Node.references 是 Map<String, NodeReference>，key 是 targetId
      final reference = sourceNode.references[command.targetId];
      if (reference == null) {
        return CommandResult.failure('节点连接不存在');
      }

      // 保存原始引用（用于撤销）
      command.originalReference = reference;

      // 移除引用
      final updatedReferences = Map<String, NodeReference>.from(sourceNode.references);
      updatedReferences.remove(command.targetId);

      final updatedNode = sourceNode.copyWith(
        references: updatedReferences,
      );

      await _repository.save(updatedNode);

      // 发布事件
      context.eventBus.publish(NodeDataChangedEvent(
        changedNodes: [updatedNode],
        action: DataChangeAction.update,
      ));

      return CommandResult.success();
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
