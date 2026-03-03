import 'dart:ui';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

/// 节点服务接口
abstract class NodeService {
  /// 创建节点
  Future<Node> createNode({
    required NodeType type,
    required String title,
    String? content,
    Offset? position,
    Size? size,
    Map<String, NodeReference>? references,
  });

  /// 创建内容节点
  Future<Node> createContentNode({
    required String title,
    required String content,
    Offset? position,
  });

  /// 创建概念节点
  Future<Node> createConceptNode({
    required String title,
    required String description,
    required List<String> containedNodeIds,
  });

  /// 更新节点
  Future<Node> updateNode(String nodeId, {
    String? title,
    String? content,
    Offset? position,
    Size? size,
    NodeViewMode? viewMode,
    Map<String, NodeReference>? references,
    Map<String, dynamic>? metadata,
  });

  /// 删除节点
  Future<void> deleteNode(String nodeId);

  /// 获取节点
  Future<Node?> getNode(String nodeId);

  /// 获取所有节点
  Future<List<Node>> getAllNodes();

  /// 搜索节点
  Future<List<Node>> searchNodes(String query);

  /// 连接两个节点
  Future<void> connectNodes({
    required String fromNodeId,
    required String toNodeId,
    required ReferenceType type,
    String? role,
  });

  /// 断开连接
  Future<void> disconnectNodes({
    required String fromNodeId,
    required String toNodeId,
  });

  /// 提升关系为概念节点
  Future<Node> elevateConnectionToConcept({
    required String fromNodeId,
    required String toNodeId,
    required String conceptTitle,
    required String conceptDescription,
  });

  /// 批量操作
  Future<void> batchUpdate(List<NodeUpdate> updates);
  Future<void> batchDelete(List<String> nodeIds);
}

/// 节点服务实现
class NodeServiceImpl implements NodeService {
  NodeServiceImpl(this._repository);

  final NodeRepository _repository;
  final Uuid _uuid = const Uuid();

  @override
  Future<Node> createNode({
    required NodeType type,
    required String title,
    String? content,
    Offset? position,
    Size? size,
    Map<String, NodeReference>? references,
  }) async {
    // 验证
    _validateTitle(title);

    if (type == NodeType.content && (content == null || content.isEmpty)) {
      throw const ValidationException('Content node must have content');
    }

    // 创建节点
    final now = DateTime.now();

    // 如果没有指定位置，生成一个稍微随机的位置，避免重叠
    final defaultPosition = position ?? Offset(
      100 + (now.millisecond % 300).toDouble(),
      100 + (now.microsecond % 300).toDouble(),
    );

    final node = Node(
      id: _uuid.v4(),
      type: type,
      title: title,
      content: content,
      references: references ?? {},
      position: defaultPosition,
      size: size ?? const Size(200, 250),  // 减小默认尺寸
      viewMode: NodeViewMode.titleWithPreview,
      createdAt: now,
      updatedAt: now,
      metadata: const {},
    );

    await _repository.save(node);
    return node;
  }

  @override
  Future<Node> createContentNode({
    required String title,
    required String content,
    Offset? position,
  }) async {
    return createNode(
      type: NodeType.content,
      title: title,
      content: content,
      position: position,
    );
  }

  @override
  Future<Node> createConceptNode({
    required String title,
    required String description,
    required List<String> containedNodeIds,
  }) async {
    final references = <String, NodeReference>{};
    for (final nodeId in containedNodeIds) {
      references[nodeId] = NodeReference(
        nodeId: nodeId,
        type: ReferenceType.contains,
        role: 'contained',
      );
    }

    return createNode(
      type: NodeType.concept,
      title: title,
      content: description,
      references: references,
    );
  }

  @override
  Future<Node> updateNode(String nodeId, {
    String? title,
    String? content,
    Offset? position,
    Size? size,
    NodeViewMode? viewMode,
    Map<String, NodeReference>? references,
    Map<String, dynamic>? metadata,
  }) async {
    final node = await _repository.load(nodeId);
    if (node == null) {
      throw NodeNotFoundException(nodeId);
    }

    // 验证
    if (title != null) {
      _validateTitle(title);
    }

    final updatedNode = node.copyWith(
      title: title ?? node.title,
      content: content ?? node.content,
      position: position ?? node.position,
      size: size ?? node.size,
      viewMode: viewMode ?? node.viewMode,
      references: references ?? node.references,
      metadata: metadata ?? node.metadata,
      updatedAt: DateTime.now(),
    );

    await _repository.save(updatedNode);
    return updatedNode;
  }

  @override
  Future<void> deleteNode(String nodeId) async {
    final node = await _repository.load(nodeId);
    if (node == null) {
      throw NodeNotFoundException(nodeId);
    }

    await _repository.delete(nodeId);
  }

  @override
  Future<Node?> getNode(String nodeId) async {
    return _repository.load(nodeId);
  }

  @override
  Future<List<Node>> getAllNodes() async {
    return _repository.queryAll();
  }

  @override
  Future<List<Node>> searchNodes(String query) async {
    return _repository.search(title: query, content: query);
  }

  @override
  Future<void> connectNodes({
    required String fromNodeId,
    required String toNodeId,
    required ReferenceType type,
    String? role,
  }) async {
    final fromNode = await _repository.load(fromNodeId);
    if (fromNode == null) {
      throw NodeNotFoundException(fromNodeId);
    }

    final toNode = await _repository.load(toNodeId);
    if (toNode == null) {
      throw NodeNotFoundException(toNodeId);
    }

    // 添加引用
    final reference = NodeReference(
      nodeId: toNodeId,
      type: type,
      role: role,
    );

    final updatedNode = fromNode.addReference(toNodeId, reference);
    await _repository.save(updatedNode);
  }

  @override
  Future<void> disconnectNodes({
    required String fromNodeId,
    required String toNodeId,
  }) async {
    final fromNode = await _repository.load(fromNodeId);
    if (fromNode == null) {
      throw NodeNotFoundException(fromNodeId);
    }

    final updatedNode = fromNode.removeReference(toNodeId);
    await _repository.save(updatedNode);
  }

  @override
  Future<Node> elevateConnectionToConcept({
    required String fromNodeId,
    required String toNodeId,
    required String conceptTitle,
    required String conceptDescription,
  }) async {
    // 创建概念节点
    final conceptNode = await createConceptNode(
      title: conceptTitle,
      description: conceptDescription,
      containedNodeIds: [fromNodeId, toNodeId],
    );

    // 更新原始节点的引用
    await connectNodes(
      fromNodeId: fromNodeId,
      toNodeId: conceptNode.id,
      type: ReferenceType.partOf,
      role: 'part_of_concept',
    );

    await connectNodes(
      fromNodeId: toNodeId,
      toNodeId: conceptNode.id,
      type: ReferenceType.partOf,
      role: 'part_of_concept',
    );

    return conceptNode;
  }

  @override
  Future<void> batchUpdate(List<NodeUpdate> updates) async {
    for (final update in updates) {
      await updateNode(
        update.nodeId,
        title: update.title,
        content: update.content,
        position: update.position,
        size: update.size,
        viewMode: update.viewMode,
        references: update.references,
      );
    }
  }

  @override
  Future<void> batchDelete(List<String> nodeIds) async {
    for (final nodeId in nodeIds) {
      await deleteNode(nodeId);
    }
  }

  void _validateTitle(String title) {
    if (title.trim().isEmpty) {
      throw const ValidationException('Title cannot be empty');
    }
    if (title.length > 200) {
      throw const ValidationException('Title too long (max 200 characters)');
    }
  }
}

/// 节点更新
class NodeUpdate {
  const NodeUpdate({
    required this.nodeId,
    this.title,
    this.content,
    this.position,
    this.size,
    this.viewMode,
    this.references,
  });

  final String nodeId;
  final String? title;
  final String? content;
  final Offset? position;
  final Size? size;
  final NodeViewMode? viewMode;
  final Map<String, NodeReference>? references;
}

/// 节点未找到异常
class NodeNotFoundException implements Exception {
  const NodeNotFoundException(this.nodeId);

  final String nodeId;

  @override
  String toString() => 'Node not found: $nodeId';
}

/// 验证异常
class ValidationException implements Exception {
  const ValidationException(this.message);

  final String message;

  @override
  String toString() => 'Validation failed: $message';
}
