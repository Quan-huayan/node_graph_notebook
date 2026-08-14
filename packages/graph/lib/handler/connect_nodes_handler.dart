import 'package:core/cqrs/commands/events/app_events.dart';
import 'package:core/cqrs/commands/models/command.dart';
import 'package:core/cqrs/commands/models/command_context.dart';
import 'package:core/cqrs/commands/models/command_handler.dart';

import '../command/node_commands.dart';
import '../service/node_service.dart';

/// 连接节点处理器
///
/// 处理连接节点的命令，创建节点间的引用关系
class ConnectNodesHandler implements CommandHandler<ConnectNodesCommand> {
  /// 构造函数
  ///
  /// [_nodeService] - 节点服务，用于连接节点
  ConnectNodesHandler(this._nodeService);

  final NodeService _nodeService;

  @override
  Future<CommandResult<void>> execute(
    ConnectNodesCommand command,
    CommandContext context,
  ) async {
    try {
      // 检查源节点是否存在
      final sourceNode = await _nodeService.getNode(command.sourceId);
      if (sourceNode == null) {
        return CommandResult.failure('源节点不存在: ${command.sourceId}');
      }

      // 检查目标节点是否存在
      final targetNode = await _nodeService.getNode(command.targetId);
      if (targetNode == null) {
        return CommandResult.failure('目标节点不存在: ${command.targetId}');
      }

      // 检查是否已存在连接
      final existingReference = sourceNode.references[command.targetId];
      if (existingReference != null) {
        return CommandResult.failure('节点连接已存在');
      }

      // 通过 Service 连接节点
      final updatedNode = await _nodeService.connectNodes(
        fromNodeId: command.sourceId,
        toNodeId: command.targetId,
        properties: command.properties,
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
