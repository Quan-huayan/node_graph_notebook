import 'package:core/cqrs/commands/models/command.dart';
import 'package:core/cqrs/commands/models/command_context.dart';
import 'package:core/cqrs/commands/models/command_handler.dart';
import 'package:core/plugin/hook/coordinate_system.dart';
import 'package:core/plugin/hook/ui_layout_service.dart';
import 'package:flutter/material.dart';

import '../command/graph_commands.dart';

/// 更新节点位置处理器
///
/// 处理更新图中节点位置的命令
/// 
/// 注意：此处理器现在使用 UILayoutService 来管理节点位置
class UpdateNodePositionHandler
    implements CommandHandler<UpdateNodePositionCommand> {
  /// 构造函数
  ///
  /// [_layoutService] - UI 布局服务，用于管理节点位置
  UpdateNodePositionHandler(this._layoutService);

  final UILayoutService _layoutService;

  @override
  Future<CommandResult<void>> execute(
    UpdateNodePositionCommand command,
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

      return CommandResult.success(null);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
