import 'package:core/cqrs/commands/models/command.dart';
import 'package:core/cqrs/commands/models/command_context.dart';
import 'package:core/plugin/hook/coordinate_system.dart';
import 'package:core/plugin/hook/ui_layout_service.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

/// 加载图命令
///
/// 用于加载指定的图
class LoadGraphCommand extends Command<Graph> {
  /// 创建加载图命令
  LoadGraphCommand({required this.graphId});

  /// 图 ID
  final String graphId;

  @override
  String get name => 'LoadGraph';

  @override
  String get description => '加载图: $graphId';

  @override
  Future<CommandResult<Graph>> execute(CommandContext context) async {
    // 由 LoadGraphHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  bool get isUndoable => false;
}

/// 创建图命令
///
/// 用于创建新的图
class CreateGraphCommand extends Command<Graph> {
  /// 创建创建图命令
  CreateGraphCommand({required this.graphName});

  /// 图名称
  final String graphName;

  @override
  String get name => 'CreateGraph';

  @override
  String get description => '创建图: $graphName';

  @override
  Future<CommandResult<Graph>> execute(CommandContext context) async {
    // 由 CreateGraphHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 撤销：删除创建的图
    // 注意：需要 handler 在执行时存储创建的图 ID
    // 当前实现：跳过撤销，因为图 ID 未传递回命令
    debugPrint('Undo graph creation not fully implemented');
  }
}

/// 更新图命令
///
/// 用于更新图的配置
/// 
/// 注意：节点位置现在由 UILayoutService 管理，不通过此命令传递
class UpdateGraphCommand extends Command<Graph> {
  /// 创建更新图命令
  UpdateGraphCommand({
    required this.graphId,
    this.updatedName,
    this.viewConfig,
    this.nodeIds,
  });

  /// 图 ID
  final String graphId;

  /// 新名称（可选）
  final String? updatedName;

  /// 新视图配置（可选）
  final GraphViewConfig? viewConfig;

  /// 新节点 ID 列表（可选）
  final List<String>? nodeIds;

  @override
  String get name => 'UpdateGraph';

  @override
  String get description => '更新图: $graphId';

  @override
  Future<CommandResult<Graph>> execute(CommandContext context) async {
    // 由 UpdateGraphHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 撤销：恢复旧配置
    if (oldGraph != null) {
      final repository = context.read<GraphRepository>();
      await repository.save(oldGraph!);
    }
  }

  /// 旧图状态（用于撤销）
  ///
  /// 公共字段，允许 Handler 在执行时设置旧值以支持撤销操作
  Graph? oldGraph;
}

/// 重命名图命令
///
/// 用于重命名图
class RenameGraphCommand extends Command<Graph> {
  /// 创建重命名图命令
  RenameGraphCommand({required this.graphId, required this.updatedName});

  /// 图 ID
  final String graphId;

  /// 新名称
  final String updatedName;

  @override
  String get name => 'RenameGraph';

  @override
  String get description => '重命名图: $graphId -> $updatedName';

  @override
  Future<CommandResult<Graph>> execute(CommandContext context) async {
    // 由 RenameGraphHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 撤销：恢复旧名称
    if (previousName != null) {
      final repository = context.read<GraphRepository>();
      final graph = await repository.load(graphId);
      if (graph != null) {
        await repository.save(graph.copyWith(name: previousName));
      }
    }
  }

  /// 旧名称（用于撤销）
  ///
  /// 公共字段，允许 Handler 在执行时设置旧值以支持撤销操作
  String? previousName;
}

/// 添加节点到图命令
///
/// 用于将节点添加到图中
class AddNodeToGraphCommand extends Command<void> {
  /// 创建添加节点到图命令
  AddNodeToGraphCommand({
    required this.graphId,
    required this.nodeId,
    this.position,
  });

  /// 图 ID
  final String graphId;

  /// 节点 ID
  final String nodeId;

  /// 节点位置（可选）
  final Offset? position;

  @override
  String get name => 'AddNodeToGraph';

  @override
  String get description => '添加节点到图: $graphId + $nodeId';

  @override
  Future<CommandResult<void>> execute(CommandContext context) async {
    // 由 AddNodeToGraphHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 撤销：从图中移除节点
    final repository = context.read<GraphRepository>();
    final graph = await repository.load(graphId);
    if (graph != null) {
      final updatedNodeIds = List<String>.from(graph.nodeIds)..remove(nodeId);
      await repository.save(graph.copyWith(nodeIds: updatedNodeIds));
    }
  }
}

/// 从图中移除节点命令
///
/// 用于从图中移除节点（不删除节点本身）
class RemoveNodeFromGraphCommand extends Command<void> {
  /// 创建从图中移除节点命令
  RemoveNodeFromGraphCommand({required this.graphId, required this.nodeId});

  /// 图 ID
  final String graphId;

  /// 节点 ID
  final String nodeId;

  @override
  String get name => 'RemoveNodeFromGraph';

  @override
  String get description => '从图中移除节点: $graphId - $nodeId';

  @override
  Future<CommandResult<void>> execute(CommandContext context) async {
    // 由 RemoveNodeFromGraphHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 撤销：重新添加节点到图
    final repository = context.read<GraphRepository>();
    final graph = await repository.load(graphId);
    if (graph != null && !graph.nodeIds.contains(nodeId)) {
      final updatedNodeIds = List<String>.from(graph.nodeIds)..add(nodeId);
      await repository.save(graph.copyWith(nodeIds: updatedNodeIds));
    }
  }
}

/// 更新节点位置命令
///
/// 用于更新图中节点的位置
class UpdateNodePositionCommand extends Command<void> {
  /// 创建更新节点位置命令
  UpdateNodePositionCommand({
    required this.graphId,
    required this.nodeId,
    required this.newPosition,
  });

  /// 图 ID
  final String graphId;

  /// 节点 ID
  final String nodeId;

  /// 新位置
  final Offset newPosition;

  @override
  String get name => 'UpdateNodePosition';

  @override
  String get description => '更新节点位置: $nodeId';

  @override
  Future<CommandResult<void>> execute(CommandContext context) async {
    // 由 UpdateNodePositionHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 撤销：恢复旧位置
    // 注意：撤销操作需要通过 UILayoutService 完成
    if (oldPosition != null) {
      final layoutService = context.read<UILayoutService>();
      await layoutService.updateNodePosition(
        nodeId: nodeId,
        newPosition: LocalPosition.absolute(oldPosition!.dx, oldPosition!.dy),
      );
        }
  }

  /// 旧位置（用于撤销）
  ///
  /// 公共字段，允许 Handler 在执行时设置旧值以支持撤销操作
  Offset? oldPosition;
}

/// 更新视图相机命令
///
/// 用于更新图的视图相机配置（缩放和位置）
class UpdateViewCameraCommand extends Command<Graph> {
  /// 创建更新视图相机命令
  UpdateViewCameraCommand({
    required this.graphId,
    required this.position,
    this.zoomLevel,
  });

  /// 图 ID
  final String graphId;

  /// 相机位置
  final Offset position;

  /// 缩放级别（可选，如果只提供位置则保持当前缩放）
  final double? zoomLevel;

  @override
  String get name => 'UpdateViewCamera';

  @override
  String get description => '更新视图相机：$graphId';

  @override
  Future<CommandResult<Graph>> execute(CommandContext context) async {
    // 由 UpdateViewCameraHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 撤销：恢复旧相机配置
    if (oldViewConfig != null) {
      final repository = context.read<GraphRepository>();
      final graph = await repository.load(graphId);
      if (graph != null) {
        await repository.save(graph.copyWith(viewConfig: oldViewConfig));
      }
    }
  }

  /// 旧视图配置（用于撤销）
  ///
  /// 公共字段，允许 Handler 在执行时设置旧值以支持撤销操作
  GraphViewConfig? oldViewConfig;
}

/// 批量节点操作命令
///
/// 用于批量添加和移出节点
class BatchNodeOperationsCommand extends Command<Graph> {
  /// 创建批量节点操作命令
  BatchNodeOperationsCommand({
    required this.graphId,
    required this.nodeIdsToAdd,
    required this.nodeIdsToMoveOut,
  });

  /// 图 ID
  final String graphId;

  /// 要添加的节点 ID 列表
  final List<String> nodeIdsToAdd;

  /// 要移出的节点 ID 列表
  final List<String> nodeIdsToMoveOut;

  @override
  String get name => 'BatchNodeOperations';

  @override
  String get description => '批量节点操作：$graphId';

  @override
  Future<CommandResult<Graph>> execute(CommandContext context) async {
    // 由 BatchNodeOperationsHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 撤销：恢复旧节点 ID 列表
    if (oldNodeIds != null) {
      final repository = context.read<GraphRepository>();
      final graph = await repository.load(graphId);
      if (graph != null) {
        await repository.save(graph.copyWith(nodeIds: oldNodeIds));
      }
    }
  }

  /// 旧节点 ID 列表（用于撤销）
  ///
  /// 公共字段，允许 Handler 在执行时设置旧值以支持撤销操作
  List<String>? oldNodeIds;
}
