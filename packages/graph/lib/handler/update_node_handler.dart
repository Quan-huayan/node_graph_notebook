import 'package:core/cqrs/commands/events/app_events.dart';
import 'package:core/cqrs/commands/models/command.dart';
import 'package:core/cqrs/commands/models/command_context.dart';
import 'package:core/cqrs/commands/models/command_handler.dart';
import 'package:core_data/core_data.dart';

import '../command/node_commands.dart';
import '../service/node_service.dart';

/// 更新节点处理器
///
/// 处理更新节点的命令，包含验证逻辑和事件发布
class UpdateNodeHandler implements CommandHandler<UpdateNodeCommand> {
  /// 构造函数
  ///
  /// [_service] - 节点服务，用于更新节点
  UpdateNodeHandler(this._service);

  final NodeService _service;

  @override
  Future<CommandResult<Node>> execute(
    UpdateNodeCommand command,
    CommandContext context,
  ) async {
    try {
      // 验证节点ID
      if (command.oldNode.id != command.newNode.id) {
        return CommandResult.failure('节点ID不匹配');
      }

      // 更新节点
      // NodeService.updateNode 需要 nodeId 和命名参数，而不是 Node 对象
      await _service.updateNode(
        command.newNode.id,
        title: command.newNode.title,
        content: command.newNode.content,
        size: command.newNode.size,
        viewMode: command.newNode.viewMode,
        color: command.newNode.color,
        metadata: command.newNode.metadata,
      );

      context.publishEvent(NodeDataChangedEvent(
        changedNodes: [command.newNode],
        action: DataChangeAction.update,
      ));

      return CommandResult.success(command.newNode);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
