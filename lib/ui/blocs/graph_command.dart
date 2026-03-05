import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/services/commands/command.dart';

/// Graph Command 接口
/// 扩展基础 Command 接口以支持 BLoC 特性
abstract class GraphCommand implements Command {
  /// 执行命令（从 Command 接口继承）
  @override
  Future<void> execute();

  /// 撤销命令（从 Command 接口继承）
  @override
  Future<void> undo();

  /// 命令描述（从 Command 接口继承）
  @override
  String get description;

  /// 是否可批量
  bool get canBeBatched => true;

  /// 合并命令（用于批量操作）
  GraphCommand? merge(GraphCommand other) => null;

  /// 命令执行时间（用于排序）
  DateTime get timestamp => DateTime.now();
}

/// 移动节点命令
class NodeMoveCommand extends GraphCommand {
  NodeMoveCommand({
    required this.graphService,
    required this.graphId,
    required this.nodeId,
    required this.newPosition,
  });

  final GraphService graphService;
  final String graphId;
  final String nodeId;
  final Offset newPosition;
  Offset? _oldPosition;

  @override
  Future<void> execute() async {
    // 保存旧位置
    final graph = await graphService.getGraph(graphId);
    if (graph != null) {
      _oldPosition = graph.nodePositions[nodeId];
    }

    // 更新位置
    await graphService.updateGraph(
      graphId,
      nodePositions: {nodeId: newPosition},
    );
  }

  @override
  Future<void> undo() async {
    if (_oldPosition != null) {
      await graphService.updateGraph(
        graphId,
        nodePositions: {nodeId: _oldPosition!},
      );
    }
  }

  @override
  String get description => 'Move Node $nodeId';

  @override
  bool get canBeBatched => true;

  @override
  GraphCommand? merge(GraphCommand other) {
    if (other is NodeMoveCommand &&
        other.graphId == graphId &&
        other.nodeId == nodeId) {
      // 合并为最新的位置
      return NodeMoveCommand(
        graphService: graphService,
        graphId: graphId,
        nodeId: nodeId,
        newPosition: other.newPosition,
      );
    }
    return null;
  }
}

/// 批量移动节点命令
class NodeMultiMoveCommand extends GraphCommand {
  NodeMultiMoveCommand({
    required this.graphService,
    required this.graphId,
    required this.movements,
  });

  final GraphService graphService;
  final String graphId;
  final Map<String, Offset> movements;
  Map<String, Offset>? _oldPositions;

  @override
  Future<void> execute() async {
    // 保存旧位置
    final graph = await graphService.getGraph(graphId);
    if (graph != null) {
      _oldPositions = Map<String, Offset>.from(graph.nodePositions);
    }

    // 更新位置
    await graphService.updateGraph(
      graphId,
      nodePositions: movements,
    );
  }

  @override
  Future<void> undo() async {
    if (_oldPositions != null) {
      await graphService.updateGraph(
        graphId,
        nodePositions: _oldPositions!,
      );
    }
  }

  @override
  String get description => 'Move ${movements.length} Nodes';

  @override
  bool get canBeBatched => true;
}

/// 批量命令
class BatchCommand extends GraphCommand {
  BatchCommand({required this.commands});

  final List<GraphCommand> commands;

  @override
  Future<void> execute() async {
    for (final command in commands) {
      await command.execute();
    }
  }

  @override
  Future<void> undo() async {
    for (final command in commands.reversed) {
      await command.undo();
    }
  }

  @override
  String get description => 'Batch (${commands.length} commands)';

  @override
  bool get canBeBatched => false;
}

/// 创建节点命令
class CreateNodeCommand extends GraphCommand {
  CreateNodeCommand({
    required this.nodeService,
    required this.graphService,
    required this.graphId,
    required this.nodeId,
    this.position,
  });

  final NodeService nodeService;
  final GraphService graphService;
  final String graphId;
  final String nodeId;
  final Offset? position;

  Node? _createdNode;

  @override
  Future<void> execute() async {
    // 创建节点
    _createdNode = await nodeService.createNode(
      title: 'New Node',
    );

    // 添加到图
    await graphService.addNodeToGraph(graphId, _createdNode!.id);

    // 设置位置
    if (position != null) {
      await graphService.updateGraph(
        graphId,
        nodePositions: {_createdNode!.id: position!},
      );
    }
  }

  @override
  Future<void> undo() async {
    if (_createdNode != null) {
      await graphService.removeNodeFromGraph(graphId, _createdNode!.id);
      await nodeService.deleteNode(_createdNode!.id);
    }
  }

  @override
  String get description => 'Create Node $nodeId';
}

/// 删除节点命令
class DeleteNodeCommand extends GraphCommand {
  DeleteNodeCommand({
    required this.nodeService,
    required this.graphService,
    required this.graphId,
    required this.nodeId,
  });

  final NodeService nodeService;
  final GraphService graphService;
  final String graphId;
  final String nodeId;

  Node? _deletedNode;
  Offset? _oldPosition;

  @override
  Future<void> execute() async {
    // 保存节点信息
    final graph = await graphService.getGraph(graphId);
    if (graph != null) {
      _oldPosition = graph.nodePositions[nodeId];
    }
    _deletedNode = await nodeService.getNode(nodeId);

    // 从图中移除
    await graphService.removeNodeFromGraph(graphId, nodeId);
  }

  @override
  Future<void> undo() async {
    if (_deletedNode != null) {
      // 重新添加到图
      await graphService.addNodeToGraph(graphId, nodeId);

      // 恢复位置
      if (_oldPosition != null) {
        await graphService.updateGraph(
          graphId,
          nodePositions: {nodeId: _oldPosition!},
        );
      }
    }
  }

  @override
  String get description => 'Delete Node $nodeId';
}

/// 连接节点命令
class ConnectNodesCommand extends GraphCommand {
  ConnectNodesCommand({
    required this.nodeService,
    required this.sourceId,
    required this.targetId,
    this.relationType = 'relates_to',
  });

  final NodeService nodeService;
  final String sourceId;
  final String targetId;
  final String relationType;
  ReferenceType? _referenceType;

  @override
  Future<void> execute() async {
    // 将字符串转换为 ReferenceType
    _referenceType = _getReferenceType(relationType);

    await nodeService.connectNodes(
      fromNodeId: sourceId,
      toNodeId: targetId,
      type: _referenceType!,
    );
  }

  @override
  Future<void> undo() async {
    await nodeService.disconnectNodes(
      fromNodeId: sourceId,
      toNodeId: targetId,
    );
  }

  @override
  String get description => 'Connect $sourceId to $targetId';

  ReferenceType _getReferenceType(String type) {
    switch (type) {
      case 'mentions':
        return ReferenceType.mentions;
      case 'contains':
        return ReferenceType.contains;
      case 'depends_on':
        return ReferenceType.dependsOn;
      case 'relates_to':
        return ReferenceType.relatesTo;
      case 'references':
        return ReferenceType.references;
      default:
        return ReferenceType.relatesTo;
    }
  }
}

/// 断开节点命令
class DisconnectNodesCommand extends GraphCommand {
  DisconnectNodesCommand({
    required this.nodeService,
    required this.sourceId,
    required this.targetId,
  });

  final NodeService nodeService;
  final String sourceId;
  final String targetId;
  ReferenceType? _referenceType;

  @override
  Future<void> execute() async {
    // 获取源节点以保存引用类型
    final sourceNode = await nodeService.getNode(sourceId);
    if (sourceNode != null) {
      // 找到引用并保存关系类型
      for (final ref in sourceNode.references.values) {
        if (ref.nodeId == targetId) {
          _referenceType = ref.type;
          break;
        }
      }
    }

    await nodeService.disconnectNodes(
      fromNodeId: sourceId,
      toNodeId: targetId,
    );
  }

  @override
  Future<void> undo() async {
    await nodeService.connectNodes(
      fromNodeId: sourceId,
      toNodeId: targetId,
      type: _referenceType ?? ReferenceType.relatesTo,
    );
  }

  @override
  String get description => 'Disconnect $sourceId from $targetId';
}

/// 应用布局命令
class ApplyLayoutCommand extends GraphCommand {
  ApplyLayoutCommand({
    required this.graphService,
    required this.graphId,
    required this.algorithm,
  });

  final GraphService graphService;
  final String graphId;
  final LayoutAlgorithm algorithm;

  Map<String, Offset>? _oldPositions;

  @override
  Future<void> execute() async {
    // 保存旧位置
    final graph = await graphService.getGraph(graphId);
    if (graph != null) {
      _oldPositions = Map<String, Offset>.from(graph.nodePositions);
    }

    // 应用布局
    await graphService.applyLayout(graphId, algorithm);
  }

  @override
  Future<void> undo() async {
    if (_oldPositions != null) {
      await graphService.updateGraph(
        graphId,
        nodePositions: _oldPositions!,
      );
    }
  }

  @override
  String get description => 'Apply ${algorithm.name} Layout';
}
