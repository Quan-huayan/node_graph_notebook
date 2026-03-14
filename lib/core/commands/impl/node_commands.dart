import 'package:flutter/material.dart';
import '../command.dart';
import '../command_context.dart';
import '../../models/node.dart';
import '../../models/node_reference.dart';
import '../../models/enums.dart';
import '../../repositories/node_repository.dart';

/// 创建节点命令
///
/// 用于创建新的概念节点
class CreateNodeCommand extends Command<Node> {
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
  UpdateNodeCommand({
    required this.oldNode,
    required this.newNode,
  });

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
  DeleteNodeCommand({
    required this.node,
    this.cascadeConnections = true,
  });

  /// 要删除的节点
  final Node node;

  /// 是否级联删除相关连接
  final bool cascadeConnections;

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

    // TODO: 恢复相关连接
  }
}

/// 连接节点命令
///
/// 用于在两个节点之间创建引用关系
class ConnectNodesCommand extends Command<void> {
  ConnectNodesCommand({
    required this.sourceId,
    required this.targetId,
    required this.type,
    this.role,
    this.connectionDescription,
  });

  /// 源节点ID
  final String sourceId;

  /// 目标节点ID
  final String targetId;

  /// 引用类型
  final ReferenceType type;

  /// 引用角色（可选）
  final String? role;

  /// 引用描述（可选）
  ///
  /// 重命名为 connectionDescription 以避免与基类的 description getter 冲突
  final String? connectionDescription;

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
      final updatedReferences = Map<String, NodeReference>.from(sourceNode.references);
      updatedReferences.remove(targetId);
      await repository.save(sourceNode.copyWith(
        references: updatedReferences,
      ));
    }
  }
}

/// 断开节点连接命令
///
/// 用于移除两个节点之间的引用关系
class DisconnectNodesCommand extends Command<void> {
  DisconnectNodesCommand({
    required this.sourceId,
    required this.targetId,
    required this.type,
    this.role,
  });

  /// 源节点ID
  final String sourceId;

  /// 目标节点ID
  final String targetId;

  /// 引用类型
  final ReferenceType type;

  /// 引用角色（可选）
  final String? role;

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
      final updatedReferences = Map<String, NodeReference>.from(sourceNode.references);
      updatedReferences[targetId] = originalReference;
      await repository.save(sourceNode.copyWith(
        references: updatedReferences,
      ));
    }
  }
}

/// 移动节点命令
///
/// 用于更新节点在图形中的位置
class MoveNodeCommand extends Command<void> {
  MoveNodeCommand({
    required this.nodeId,
    required this.newPosition,
  });

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
      await repository.save(node.copyWith(
        position: oldPosition,
      ));
    }
  }
}

/// 调整节点大小命令
///
/// 用于更新节点的大小
class ResizeNodeCommand extends Command<void> {
  ResizeNodeCommand({
    required this.nodeId,
    required this.newSize,
  });

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
      await repository.save(node.copyWith(
        size: oldSize,
      ));
    }
  }
}
