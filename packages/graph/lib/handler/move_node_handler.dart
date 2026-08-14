import 'package:core/cqrs/commands/models/command.dart';
import 'package:core/cqrs/commands/models/command_context.dart';
import 'package:core/cqrs/commands/models/command_handler.dart';
import 'package:core/plugin/hook/coordinate_system.dart';
import 'package:core/plugin/hook/ui_layout_service.dart';
import 'package:flutter/material.dart';
import 'package:node_layout/event/layout_events.dart';

import '../command/node_commands.dart';

/// 移动节点处理器
///
/// 处理移动节点的命令，更新节点在图形中的位置
/// 
/// 注意：此处理器使用 UILayoutService 来管理节点位置
class MoveNodeHandler implements CommandHandler<MoveNodeCommand> {
  /// 构造函数
  ///
  /// [_layoutService] - UI 布局服务，用于管理节点位置
  MoveNodeHandler(this._layoutService);

  final UILayoutService _layoutService;

  @override
  Future<CommandResult<void>> execute(
    MoveNodeCommand command,
    CommandContext context,
  ) async {
    try {
      // 保存旧位置（用于撤销）
      final attachment = _layoutService.getNodeAttachment(command.nodeId);
      if (attachment != null) {
        command.oldPosition = Offset(
          attachment.localPosition.x,
          attachment.localPosition.y,
        );
      }

      // 使用 UILayoutService 更新节点位置
      await _layoutService.updateNodePosition(
        nodeId: command.nodeId,
        newPosition: LocalPosition.absolute(
          command.newPosition.dx,
          command.newPosition.dy,
        ),
      );

      // 发布节点位置变化事件
      context.publishEvent(
        NodePositionsChangedEvent(nodeIds: [command.nodeId]),
      );

      return CommandResult.success();
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
