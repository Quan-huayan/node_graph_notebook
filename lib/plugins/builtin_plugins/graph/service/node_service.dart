import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/models/models.dart';
import '../../../../core/repositories/repositories.dart';

/// 节点服务接口
abstract class NodeService {
  /// 创建节点
  Future<Node> createNode({
    required String title,
    String? content,
    Offset? position,
    Size? size,
    String? color,
    Map<String, NodeReference>? references,
    Map<String, dynamic>? metadata,
  });

  /// 更新节点
  Future<Node> updateNode(
    String nodeId, {
    String? title,
    String? content,
    Offset? position,
    Size? size,
    NodeViewMode? viewMode,
    String? color,
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
  ///
  /// 创建从 [fromNodeId] 到 [toNodeId] 的引用关系
  /// [properties] 是可选的引用属性，插件可以自由定义
  Future<void> connectNodes({
    required String fromNodeId,
    required String toNodeId,
    Map<String, dynamic>? properties,
  });

  /// 断开连接
  Future<void> disconnectNodes({
    required String fromNodeId,
    required String toNodeId,
  });

  /// 批量操作
  Future<void> batchUpdate(List<NodeUpdate> updates);
  /// 批量删除节点
  Future<void> batchDelete(List<String> nodeIds);

  /// 计算节点图中每个节点的深度（层级）
  ///
  /// 返回 Map<节点ID, 深度>，根节点深度为0
  /// 如果存在循环引用，返回 -1
  ///
  /// 深度定义：
  /// - 根节点（没有被任何节点引用）: depth = 0
  /// - 被根节点引用的节点: depth = 1
  /// - 依此类推...
  ///
  /// 使用场景：
  /// - 第0-n层：正常显示为节点
  /// - 第n+1层：显示为引用（reference）
  /// - 第n+2层及更高：隐藏
  Future<Map<String, int>> calculateNodeDepths(List<Node> nodes);
}

/// 节点服务实现
class NodeServiceImpl implements NodeService {
  /// 构造函数
  ///
  /// [_repository] - 节点仓库
  NodeServiceImpl(this._repository);

  final NodeRepository _repository;
  final Uuid _uuid = const Uuid();

  @override
  Future<Node> createNode({
    required String title,
    String? content,
    Offset? position,
    Size? size,
    String? color,
    Map<String, NodeReference>? references,
    Map<String, dynamic>? metadata,
  }) async {
    // 验证
    _validateTitle(title);

    // 创建节点
    final now = DateTime.now();

    // 如果没有指定位置，生成一个稍微随机的位置，避免重叠
    final defaultPosition =
        position ??
        Offset(
          100 + (now.millisecond % 300).toDouble(),
          100 + (now.microsecond % 300).toDouble(),
        );

    final node = Node(
      id: _uuid.v4(),
      title: title,
      content: content,
      references: references ?? {},
      position: defaultPosition,
      size: size ?? const Size(200, 250), // 减小默认尺寸
      viewMode: NodeViewMode.titleWithPreview,
      color: color,
      createdAt: now,
      updatedAt: now,
      metadata: metadata ?? const {},
    );

    await _repository.save(node);
    return node;
  }

  @override
  Future<Node> updateNode(
    String nodeId, {
    String? title,
    String? content,
    Offset? position,
    Size? size,
    NodeViewMode? viewMode,
    String? color,
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
      color: color ?? node.color,
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
  Future<Node?> getNode(String nodeId) async => _repository.load(nodeId);

  @override
  Future<List<Node>> getAllNodes() async => _repository.queryAll();

  @override
  Future<List<Node>> searchNodes(String query) async => _repository.search(title: query, content: query);

  @override
  Future<void> connectNodes({
    required String fromNodeId,
    required String toNodeId,
    Map<String, dynamic>? properties,
  }) async {
    final fromNode = await _repository.load(fromNodeId);
    if (fromNode == null) {
      throw NodeNotFoundException(fromNodeId);
    }

    final toNode = await _repository.load(toNodeId);
    if (toNode == null) {
      throw NodeNotFoundException(toNodeId);
    }

    // 添加引用，使用插件提供的属性
    final reference = NodeReference(
      nodeId: toNodeId,
      properties: properties ?? {},
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

  @override
  Future<Map<String, int>> calculateNodeDepths(List<Node> nodes) async {
    final depths = <String, int>{};
    final visited = <String>{};

    /// 计算单个节点的深度（使用DFS）
    int getDepth(String nodeId) {
      // 如果已经计算过，直接返回
      if (depths.containsKey(nodeId)) {
        return depths[nodeId]!;
      }

      // 检测循环
      if (visited.contains(nodeId)) {
        depths[nodeId] = -1;
        return -1;
      }

      visited.add(nodeId);

      // 找到所有引用该节点的父节点
      final parents = nodes.where((n) => n.references.containsKey(nodeId));

      if (parents.isEmpty) {
        // 没有父节点，这是根节点
        depths[nodeId] = 0;
      } else {
        // 计算所有父节点的最大深度
        var maxParentDepth = -1;
        for (final parent in parents) {
          final parentDepth = getDepth(parent.id);
          if (parentDepth == -1) {
            // 父节点存在循环，该节点也标记为循环
            depths[nodeId] = -1;
            visited.remove(nodeId);
            return -1;
          }
          if (parentDepth > maxParentDepth) {
            maxParentDepth = parentDepth;
          }
        }
        depths[nodeId] = maxParentDepth + 1;
      }

      visited.remove(nodeId);
      return depths[nodeId]!;
    }

    // 计算所有节点的深度
    for (final node in nodes) {
      getDepth(node.id);
    }

    return depths;
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
  /// 构造函数
  ///
  /// [nodeId] - 节点ID
  /// [title] - 标题，可选
  /// [content] - 内容，可选
  /// [position] - 位置，可选
  /// [size] - 大小，可选
  /// [viewMode] - 视图模式，可选
  /// [references] - 引用，可选
  const NodeUpdate({
    required this.nodeId,
    this.title,
    this.content,
    this.position,
    this.size,
    this.viewMode,
    this.references,
  });

  /// 节点ID
  final String nodeId;
  /// 标题，可选
  final String? title;
  /// 内容，可选
  final String? content;
  /// 位置，可选
  final Offset? position;
  /// 大小，可选
  final Size? size;
  /// 视图模式，可选
  final NodeViewMode? viewMode;
  /// 引用，可选
  final Map<String, NodeReference>? references;
}

/// 节点未找到异常
class NodeNotFoundException implements Exception {
  /// 构造函数
  ///
  /// [nodeId] - 未找到的节点的 ID
  const NodeNotFoundException(this.nodeId);

  /// 未找到的节点的 ID
  final String nodeId;

  @override
  String toString() => 'Node not found: $nodeId';
}

/// 验证异常
class ValidationException implements Exception {
  /// 构造函数
  ///
  /// [message] - 验证失败的消息
  const ValidationException(this.message);

  /// 验证失败的消息
  final String message;

  @override
  String toString() => 'Validation failed: $message';
}
