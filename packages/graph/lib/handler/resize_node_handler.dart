import 'package:core/cqrs/commands/events/app_events.dart';
import 'package:core/cqrs/commands/models/command.dart';
import 'package:core/cqrs/commands/models/command_context.dart';
import 'package:core/cqrs/commands/models/command_handler.dart';

import '../command/node_commands.dart';
import '../service/node_service.dart';

/// 调整节点大小处理器
///
/// 处理调整节点大小的命令
class ResizeNodeHandler implements CommandHandler<ResizeNodeCommand> {
  /// 构造函数
  ///
  /// [_nodeService] - 节点服务，用于更新节点
  ResizeNodeHandler(this._nodeService);

  final NodeService _nodeService;

  @override
  Future<CommandResult<void>> execute(
    ResizeNodeCommand command,
    CommandContext context,
  ) async {
    try {
      final node = await _nodeService.getNode(command.nodeId);
      if (node == null) {
        return CommandResult.failure('节点不存在: ${command.nodeId}');
      }

      // 保存旧大小（用于撤销）
      command.oldSize = node.size;

      // 通过 Service 更新大小
      final updatedNode = await _nodeService.updateNode(
        command.nodeId,
        size: command.newSize,
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
