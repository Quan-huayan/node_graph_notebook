import 'package:flutter/material.dart';
import '../../../../core/commands/models/command.dart';
import '../../../../core/commands/models/command_context.dart';
import '../../../../core/models/graph.dart';
import '../../../../core/repositories/graph_repository.dart';

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
    // TODO: 实现删除逻辑
  }
}

/// 更新图命令
///
/// 用于更新图的配置
class UpdateGraphCommand extends Command<Graph> {
  /// 创建更新图命令
  UpdateGraphCommand({
    required this.graphId,
    this.updatedName,
    this.viewConfig,
    this.nodeIds,
    this.nodePositions,
  });

  /// 图 ID
  final String graphId;

  /// 新名称（可选）
  final String? updatedName;

  /// 新视图配置（可选）
  final GraphViewConfig? viewConfig;

  /// 新节点 ID 列表（可选）
  final List<String>? nodeIds;

  /// 新节点位置（可选）
  final Map<String, Offset>? nodePositions;

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
    if (oldPosition != null) {
      final repository = context.read<GraphRepository>();
      final graph = await repository.load(graphId);
      if (graph != null) {
        final updatedPositions = Map<String, Offset>.from(graph.nodePositions);
        updatedPositions[nodeId] = oldPosition!;
        await repository.save(graph.copyWith(nodePositions: updatedPositions));
      }
    }
  }

  /// 旧位置（用于撤销）
  ///
  /// 公共字段，允许 Handler 在执行时设置旧值以支持撤销操作
  Offset? oldPosition;
}
