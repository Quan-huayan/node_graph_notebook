import '../../../../core/commands/command_bus.dart';
import '../../../../core/commands/models/command.dart';
import '../../../../core/commands/models/command_context.dart';
import '../../../../core/commands/models/command_handler.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/repositories/node_repository.dart';
import '../../graph/service/graph_service.dart';
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
  /// [_commandBus] - 命令总线
  ApplyLayoutHandler(this._graphService, this._layoutService, this._commandBus);

  final GraphService _graphService;
  final LayoutService _layoutService;
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

      // 保存原始位置用于撤销（注释掉，因为无法访问命令的私有字段）
      // final originalPositions = <String, Offset>{};
      // for (final node in graphNodes) {
      //   originalPositions[node.id] = node.position;
      // }

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
        algorithm: algorithm,
      );

      // 批量移动节点到新位置
      if (positions.isNotEmpty) {
        await _commandBus.dispatch(BatchMoveNodesCommand(positions: positions));
      }

      // 发布布局应用事件
      context.eventBus.publish(
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
  BatchMoveNodesHandler(this._nodeRepository);

  final NodeRepository _nodeRepository;

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
          // 保存原始位置
          command.oldPositions[entry.key] = node.position;

          // 更新位置
          await _nodeRepository.save(node.copyWith(position: entry.value));
        }
      }

      // 发布节点位置变化事件
      context.eventBus.publish(
        NodePositionsChangedEvent(nodeIds: command.positions.keys.toList()),
      );

      return CommandResult.success(null);
    } catch (e) {
      return CommandResult.failure('Failed to move nodes: $e');
    }
  }
}
