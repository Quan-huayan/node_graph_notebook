import 'package:flutter/material.dart';

import '../../../../core/models/node.dart';
import '../../../../core/models/node_reference.dart';
import '../../../../core/repositories/node_repository.dart';
import '../../../core/cqrs/commands/events/app_events.dart';
import '../../../core/cqrs/commands/models/command.dart';
import '../../../core/cqrs/commands/models/command_context.dart';

/// 创建节点命令
///
/// 用于创建新的概念节点
class CreateNodeCommand extends Command<Node> {
  /// 创建创建节点命令
  CreateNodeCommand({
    required this.title,
    this.content,
    this.position,
    this.size,
    this.tags,
    this.nodeType,
  });

  /// 节点标题
  final String title;

  /// 节点内容（可选）
  final String? content;

  /// 节点位置（可选）
  final Offset? position;

  /// 节点大小（可选）
  final Size? size;

  /// 节点标签列表（可选）
  final List<String>? tags;

  /// 节点类型（可选）
  final String? nodeType;

  @override
  String get name => 'CreateNode';

  @override
  String get description => '创建节点: $title';

  @override
  Future<CommandResult<Node>> execute(CommandContext context) async {
    // 由 CreateNodeHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 由 CreateNodeHandler 处理撤销
    throw UnimplementedError('命令撤销由处理器处理');
  }
}

/// 更新节点命令
///
/// 用于更新现有节点的内容和属性
class UpdateNodeCommand extends Command<Node> {
  /// 创建更新节点命令
  UpdateNodeCommand({required this.oldNode, required this.newNode});

  /// 旧节点状态（用于撤销）
  final Node oldNode;

  /// 新节点状态
  final Node newNode;

  @override
  String get name => 'UpdateNode';

  @override
  String get description => '更新节点: ${newNode.title}';

  @override
  Future<CommandResult<Node>> execute(CommandContext context) async {
    // 由 UpdateNodeHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 恢复旧节点状态
    final repository = context.read<NodeRepository>();
    await repository.save(oldNode);
  }
}

/// 删除节点命令
///
/// 用于删除节点及其相关连接
class DeleteNodeCommand extends Command<void> {
  /// 创建删除节点命令
  DeleteNodeCommand({required this.node, this.cascadeConnections = true});

  /// 要删除的节点
  final Node node;

  /// 是否级联删除相关连接
  final bool cascadeConnections;

  /// 保存相关连接信息用于撤销
  Map<String, NodeReference>? _incomingConnections;

  @override
  String get name => 'DeleteNode';

  @override
  String get description => '删除节点: ${node.title}';

  @override
  Future<CommandResult<void>> execute(CommandContext context) async {
    // 由 DeleteNodeHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 恢复节点
    final repository = context.read<NodeRepository>();
    await repository.save(node);

    // 恢复相关连接
    // 重新建立其他节点到此节点的连接
    if (_incomingConnections != null) {
      for (final entry in _incomingConnections!.entries) {
        final nodes = await repository.queryAll();
        final sourceNode = nodes.firstWhere(
          (n) => n.id == entry.key,
          orElse: () => node,
        );
        if (sourceNode.id != node.id) {
          final updatedReferences = Map<String, NodeReference>.from(sourceNode.references);
          updatedReferences[node.id] = entry.value;

          await repository.save(sourceNode.copyWith(references: updatedReferences));
        }
      }

      // 发布连接恢复事件
      context.commandBus.publishEvent(NodeDataChangedEvent(
        changedNodes: [node],
        action: DataChangeAction.update,
      ));
    }
  }
}

/// 连接节点命令
///
/// 用于在两个节点之间创建引用关系
class ConnectNodesCommand extends Command<void> {
  /// 创建连接节点命令
  ConnectNodesCommand({
    required this.sourceId,
    required this.targetId,
    this.properties,
  });

  /// 源节点ID
  final String sourceId;

  /// 目标节点ID
  final String targetId;

  /// 引用属性（可选）
  ///
  /// 插件可以自由定义任意属性
  final Map<String, dynamic>? properties;

  @override
  String get name => 'ConnectNodes';

  @override
  String get description => '连接节点: $sourceId -> $targetId';

  @override
  Future<CommandResult<void>> execute(CommandContext context) async {
    // 由 ConnectNodesHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 移除连接
    final repository = context.read<NodeRepository>();
    final sourceNode = await repository.load(sourceId);
    if (sourceNode != null) {
      // Node.references 是 Map<String, NodeReference>
      final updatedReferences = Map<String, NodeReference>.from(
        sourceNode.references,
      )
      ..remove(targetId);
      await repository.save(sourceNode.copyWith(references: updatedReferences));
    }
  }
}

/// 断开节点连接命令
///
/// 用于移除两个节点之间的引用关系
class DisconnectNodesCommand extends Command<void> {
  /// 创建断开节点连接命令
  DisconnectNodesCommand({required this.sourceId, required this.targetId});

  /// 源节点ID
  final String sourceId;

  /// 目标节点ID
  final String targetId;

  /// 保存原始引用（用于撤销）
  ///
  /// 公共字段，允许 Handler 在执行时设置原始引用以支持撤销操作
  late NodeReference originalReference;

  @override
  String get name => 'DisconnectNodes';

  @override
  String get description => '断开节点: $sourceId -> $targetId';

  @override
  Future<CommandResult<void>> execute(CommandContext context) async {
    // 由 DisconnectNodesHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 恢复连接
    final repository = context.read<NodeRepository>();
    final sourceNode = await repository.load(sourceId);
    if (sourceNode != null) {
      // Node.references 是 Map<String, NodeReference>
      final updatedReferences = Map<String, NodeReference>.from(
        sourceNode.references,
      );
      updatedReferences[targetId] = originalReference;
      await repository.save(sourceNode.copyWith(references: updatedReferences));
    }
  }
}

/// 移动节点命令
///
/// 用于更新节点在图形中的位置
class MoveNodeCommand extends Command<void> {
  /// 创建移动节点命令
  MoveNodeCommand({required this.nodeId, required this.newPosition});

  /// 节点ID
  final String nodeId;

  /// 新位置
  final Offset newPosition;

  /// 旧位置（用于撤销）
  ///
  /// 公共字段，允许 Handler 在执行时设置旧值以支持撤销操作
  late Offset oldPosition;

  @override
  String get name => 'MoveNode';

  @override
  String get description => '移动节点: $nodeId';

  @override
  Future<CommandResult<void>> execute(CommandContext context) async {
    // 由 MoveNodeHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 恢复旧位置
    final repository = context.read<NodeRepository>();
    final node = await repository.load(nodeId);
    if (node != null) {
      await repository.save(node.copyWith(position: oldPosition));
    }
  }
}

/// 调整节点大小命令
///
/// 用于更新节点的大小
class ResizeNodeCommand extends Command<void> {
  /// 创建调整节点大小命令
  ResizeNodeCommand({required this.nodeId, required this.newSize});

  /// 节点ID
  final String nodeId;

  /// 新大小
  final Size newSize;

  /// 旧大小（用于撤销）
  ///
  /// 公共字段，允许 Handler 在执行时设置旧值以支持撤销操作
  late Size oldSize;

  @override
  String get name => 'ResizeNode';

  @override
  String get description => '调整节点大小: $nodeId';

  @override
  Future<CommandResult<void>> execute(CommandContext context) async {
    // 由 ResizeNodeHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 恢复旧大小
    final repository = context.read<NodeRepository>();
    final node = await repository.load(nodeId);
    if (node != null) {
      await repository.save(node.copyWith(size: oldSize));
    }
  }
}
