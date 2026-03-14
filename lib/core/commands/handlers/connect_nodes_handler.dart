import '../command.dart';
import '../command_context.dart';
import '../command_handler.dart';
import '../impl/node_commands.dart';
import '../../models/node_reference.dart';
import '../../repositories/node_repository.dart';
import '../../events/app_events.dart';

/// 连接节点处理器
///
/// 处理连接节点的命令，创建节点间的引用关系
class ConnectNodesHandler implements CommandHandler<ConnectNodesCommand> {
  ConnectNodesHandler(this._repository);

  final NodeRepository _repository;

  @override
  Future<CommandResult<void>> execute(
    ConnectNodesCommand command,
    CommandContext context,
  ) async {
    try {
      // 验证节点存在
      final sourceNode = await _repository.load(command.sourceId);
      final targetNode = await _repository.load(command.targetId);

      if (sourceNode == null) {
        return CommandResult.failure('源节点不存在: ${command.sourceId}');
      }

      if (targetNode == null) {
        return CommandResult.failure('目标节点不存在: ${command.targetId}');
      }

      // 检查是否已存在连接
      // Node.references 是 Map<String, NodeReference>，key 是 targetId
      final existingReference = sourceNode.references[command.targetId];
      if (existingReference != null &&
          existingReference.type == command.type &&
          existingReference.role == command.role) {
        return CommandResult.failure('节点连接已存在');
      }

      // 创建引用
      // 注意：NodeReference 使用 nodeId 而不是 targetId
      final reference = NodeReference(
        nodeId: command.targetId,
        type: command.type,
        role: command.role,
        metadata: command.connectionDescription != null
            ? {'description': command.connectionDescription}
            : null,
      );

      // 更新源节点的引用映射
      // 使用 Node 的 addReference 方法或直接复制 Map
      final updatedReferences = Map<String, NodeReference>.from(sourceNode.references);
      updatedReferences[command.targetId] = reference;
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
