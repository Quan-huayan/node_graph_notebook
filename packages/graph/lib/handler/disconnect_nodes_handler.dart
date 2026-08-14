import 'package:core/cqrs/commands/events/app_events.dart';
import 'package:core/cqrs/commands/models/command.dart';
import 'package:core/cqrs/commands/models/command_context.dart';
import 'package:core/cqrs/commands/models/command_handler.dart';

import '../command/node_commands.dart';
import '../service/node_service.dart';

/// 断开节点连接处理器
///
/// 处理断开节点连接的命令，移除节点间的引用关系
class DisconnectNodesHandler implements CommandHandler<DisconnectNodesCommand> {
  /// 构造函数
  ///
  /// [_nodeService] - 节点服务，用于断开节点连接
  DisconnectNodesHandler(this._nodeService);

  final NodeService _nodeService;

  @override
  Future<CommandResult<void>> execute(
    DisconnectNodesCommand command,
    CommandContext context,
  ) async {
    try {
      // 检查源节点是否存在
      final sourceNode = await _nodeService.getNode(command.sourceId);
      if (sourceNode == null) {
        return CommandResult.failure('源节点不存在: ${command.sourceId}');
      }

      // 查找要删除的引用
      final reference = sourceNode.references[command.targetId];
      if (reference == null) {
        return CommandResult.failure('节点连接不存在');
      }

      // 保存原始引用（用于撤销）
      command.originalReference = reference;

      // 通过 Service 断开节点连接
      final updatedNode = await _nodeService.disconnectNodes(
        fromNodeId: command.sourceId,
        toNodeId: command.targetId,
      );

      context.publishEvent(NodeDataChangedEvent(
        changedNodes: [updatedNode],
        action: DataChangeAction.update,
      ));

      return CommandResult.success();
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
