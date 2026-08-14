import 'package:core/cqrs/commands/events/app_events.dart';
import 'package:core/cqrs/commands/models/command.dart';
import 'package:core/cqrs/commands/models/command_context.dart';
import 'package:core/cqrs/commands/models/command_handler.dart';
import 'package:core_data/core_data.dart';

import '../command/node_commands.dart';
import '../service/node_service.dart';

/// 创建节点处理器
///
/// 处理创建节点的命令，包含验证逻辑和事件发布
class CreateNodeHandler implements CommandHandler<CreateNodeCommand> {
  /// 构造函数
  ///
  /// [_service] - 节点服务，用于创建节点
  CreateNodeHandler(this._service);

  final NodeService _service;

  @override
  Future<CommandResult<Node>> execute(
    CreateNodeCommand command,
    CommandContext context,
  ) async {
    try {
      // 验证标题
      if (command.title.trim().isEmpty) {
        return CommandResult.failure('节点标题不能为空');
      }

      // 创建节点（使用命名参数）
      final node = await _service.createNode(
        title: command.title,
        content: command.content,
      );

      context.publishEvent(NodeDataChangedEvent(
        changedNodes: [node],
        action: DataChangeAction.create,
      ));

      return CommandResult.success(node);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
