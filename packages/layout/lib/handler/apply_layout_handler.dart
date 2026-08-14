import 'package:core/cqrs/commands/command_bus.dart';
import 'package:core/cqrs/commands/models/command.dart';
import 'package:core/cqrs/commands/models/command_context.dart';
import 'package:core/cqrs/commands/models/command_handler.dart';
import 'package:core/plugin/hook/coordinate_system.dart';
import 'package:core/plugin/hook/ui_layout_service.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:node_graph/service/graph_service.dart';

import '../command/layout_commands.dart';
import '../event/layout_events.dart';
import '../service/layout_service.dart';

/// 应用布局命令处理器
///
/// 负责执行布局算法并更新节点位置
class ApplyLayoutHandler implements CommandHandler<ApplyLayoutCommand> {
  /// 构造函数
  ///
  /// [_graphService] - 图形服务
  /// [_layoutService] - 布局服务
  /// [_uiLayoutService] - UI 布局服务，用于获取节点当前位置
  /// [_commandBus] - 命令总线
  ApplyLayoutHandler(
    this._graphService,
    this._layoutService,
    this._uiLayoutService,
    this._commandBus,
  );

  final GraphService _graphService;
  final LayoutService _layoutService;
  final UILayoutService _uiLayoutService;
  final CommandBus _commandBus;

  @override
  Future<CommandResult> execute(
    ApplyLayoutCommand command,
    CommandContext context,
  ) async {
    try {
      // 使用便捷访问器获取仓库
      final graphRepo = context.graphRepository;
      final nodeRepo = context.nodeRepository;

      // 获取当前图或指定的图
      final graphId = command.graphId ?? (await graphRepo.getCurrent())?.id;
      if (graphId == null) {
        return CommandResult.failure('No graph loaded');
      }

      // 获取图中的所有节点
      final graph = await _graphService.getGraph(graphId);
      if (graph == null) {
        return CommandResult.failure('Graph not found: $graphId');
      }

      final nodes = await nodeRepo.queryAll();
      final graphNodes = nodes
          .where((n) => graph.nodeIds.contains(n.id))
          .toList();

      if (graphNodes.isEmpty) {
        return CommandResult.success({});
      }

      // 从 UILayoutService 获取节点当前位置
      final currentPositions = <String, Offset>{};
      for (final node in graphNodes) {
        final attachment = _uiLayoutService.getNodeAttachment(node.id);
        if (attachment != null) {
          currentPositions[node.id] = Offset(
            attachment.localPosition.x,
            attachment.localPosition.y,
          );
        }
      }

      // 将布局类型转换为 LayoutAlgorithm 枚举
      final algorithm = _mapLayoutType(command.layoutType);
      if (algorithm == null) {
        return CommandResult.failure(
          'Unknown layout type: ${command.layoutType}',
        );
      }

      // 应用布局算法
      final positions = await _layoutService.applyLayout(
        nodes: graphNodes,
        currentPositions: currentPositions,
        algorithm: algorithm,
      );

      // 批量移动节点到新位置
      if (positions.isNotEmpty) {
        await _commandBus.dispatch(BatchMoveNodesCommand(positions: positions));
      }

      // 发布布局应用事件（使用新API）
      context.publishEvent(
        LayoutAppliedEvent(
          graphId: graphId,
          layoutType: command.layoutType,
          nodeCount: positions.length,
        ),
      );

      return CommandResult.success(positions);
    } catch (e) {
      return CommandResult.failure('Failed to apply layout: $e');
    }
  }

  /// 映射布局类型字符串到 LayoutAlgorithm 枚举
  LayoutAlgorithm? _mapLayoutType(String layoutType) {
    switch (layoutType.toLowerCase()) {
      case 'force_directed':
      case 'force-directed':
        return LayoutAlgorithm.forceDirected;
      case 'tree':
      case 'hierarchical':
        return LayoutAlgorithm.hierarchical;
      case 'circular':
        return LayoutAlgorithm.circular;
      case 'grid':
      case 'free':
        return LayoutAlgorithm.free;
      default:
        return null;
    }
  }
}

/// 批量移动节点命令处理器
///
/// 用于布局算法批量更新节点位置
class BatchMoveNodesHandler implements CommandHandler<BatchMoveNodesCommand> {
  /// 构造函数
  ///
  /// [_nodeRepository] - 节点仓库
  /// [_uiLayoutService] - UI 布局服务，用于获取和更新节点位置
  BatchMoveNodesHandler(this._nodeRepository, this._uiLayoutService);

  final NodeRepository _nodeRepository;
  final UILayoutService _uiLayoutService;

  @override
  Future<CommandResult> execute(
    BatchMoveNodesCommand command,
    CommandContext context,
  ) async {
    try {
      // 保存原始位置（用于撤销）
      command.oldPositions = {};

      // 批量更新节点位置
      for (final entry in command.positions.entries) {
        final node = await _nodeRepository.load(entry.key);
        if (node != null) {
          // 从 UILayoutService 获取当前位置
          final attachment = _uiLayoutService.getNodeAttachment(entry.key);
          if (attachment != null) {
            command.oldPositions![entry.key] = Offset(
              attachment.localPosition.x,
              attachment.localPosition.y,
            );
          }

          // 通过 UILayoutService 更新位置
          await _uiLayoutService.updateNodePosition(
            nodeId: entry.key,
            newPosition: LocalPosition.absolute(entry.value.dx, entry.value.dy),
          );
        }
      }

      // 发布节点位置变化事件（使用新API）
      context.publishEvent(
        NodePositionsChangedEvent(nodeIds: command.positions.keys.toList()),
      );

      return CommandResult.success(null);
    } catch (e) {
      return CommandResult.failure('Failed to move nodes: $e');
    }
  }
}
