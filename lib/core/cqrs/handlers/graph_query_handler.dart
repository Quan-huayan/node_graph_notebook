import 'dart:collection';

import '../../graph/adjacency_list.dart';
import '../../models/node.dart';
import '../../repositories/node_repository.dart';
import '../queries/graph_query.dart';
import '../query/query.dart';

/// 获取邻居节点的Handler
///
/// 使用AdjacencyList优化查询，提供O(1)复杂度的邻居查询
class GetNeighborNodesQueryHandler extends QueryHandler<List<Node>, GetNeighborNodesQuery> {
  /// 构造函数
  GetNeighborNodesQueryHandler(
    this._repository,
    this._adjacencyList,
  );

  final NodeRepository _repository;
  final AdjacencyList _adjacencyList;

  @override
  Future<QueryResult<List<Node>>> handle(GetNeighborNodesQuery query) async {
    try {
      // 加载中心节点
      final centerNode = await _repository.load(query.nodeId);
      if (centerNode == null) {
        return QueryResult.failure('Center node not found: ${query.nodeId}');
      }

      // 使用AdjacencyList获取邻居ID
      final neighborIds = <String>{};

      if (query.direction == NeighborDirection.outgoing ||
          query.direction == NeighborDirection.both) {
        neighborIds.addAll(_adjacencyList.getOutgoingNeighbors(query.nodeId));
      }

      if (query.direction == NeighborDirection.incoming ||
          query.direction == NeighborDirection.both) {
        neighborIds.addAll(_adjacencyList.getIncomingNeighbors(query.nodeId));
      }

      // 批量加载邻居节点
      if (neighborIds.isEmpty) {
        return QueryResult.success(<Node>[]);
      }

      final neighbors = await _repository.loadAll(neighborIds.toList());

      return QueryResult.success(neighbors);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Failed to get neighbor nodes: ${error.toString()}',
        stackTrace,
      );
    }
  }
}

/// 获取出边引用的Handler
class GetOutgoingReferencesQueryHandler extends QueryHandler<List<Node>, GetOutgoingReferencesQuery> {
  /// 构造函数
  GetOutgoingReferencesQueryHandler(this._repository);

  final NodeRepository _repository;

  @override
  Future<QueryResult<List<Node>>> handle(GetOutgoingReferencesQuery query) async {
    try {
      final node = await _repository.load(query.nodeId);
      if (node == null) {
        return QueryResult.failure('Node not found: ${query.nodeId}');
      }

      // 获取所有引用的节点ID
      final referencedIds = node.references.keys.toList();

      // 批量加载节点
      if (referencedIds.isEmpty) {
        return QueryResult.success(<Node>[]);
      }

      final referencedNodes = await _repository.loadAll(referencedIds);

      return QueryResult.success(referencedNodes);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Failed to get outgoing references: ${error.toString()}',
        stackTrace,
      );
    }
  }
}

/// 获取入边引用的Handler
///
/// 使用AdjacencyList优化查询，提供O(1)复杂度的入边查询
class GetIncomingReferencesQueryHandler extends QueryHandler<List<Node>, GetIncomingReferencesQuery> {
  /// 构造函数
  GetIncomingReferencesQueryHandler(
    this._repository,
    this._adjacencyList,
  );

  final NodeRepository _repository;
  final AdjacencyList _adjacencyList;

  @override
  Future<QueryResult<List<Node>>> handle(GetIncomingReferencesQuery query) async {
    try {
      // 使用AdjacencyList获取入边邻居ID
      final incomingIds = _adjacencyList.getIncomingNeighbors(query.nodeId);

      if (incomingIds.isEmpty) {
        return QueryResult.success(<Node>[]);
      }

      // 批量加载节点
      final incomingNodes = await _repository.loadAll(incomingIds.toList());

      return QueryResult.success(incomingNodes);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Failed to get incoming references: ${error.toString()}',
        stackTrace,
      );
    }
  }
}

/// 获取节点路径的Handler（BFS算法）
class GetNodePathQueryHandler extends QueryHandler<List<Node>?, GetNodePathQuery> {
  /// 构造函数
  GetNodePathQueryHandler(this._repository);

  final NodeRepository _repository;

  @override
  Future<QueryResult<List<Node>?>> handle(GetNodePathQuery query) async {
    try {
      // 加载起始和目标节点
      final fromNode = await _repository.load(query.fromNodeId);
      final toNode = await _repository.load(query.toNodeId);

      if (fromNode == null) {
        return QueryResult.failure('From node not found: ${query.fromNodeId}');
      }
      if (toNode == null) {
        return QueryResult.failure('To node not found: ${query.toNodeId}');
      }

      // 如果是同一个节点
      if (query.fromNodeId == query.toNodeId) {
        return QueryResult.success([fromNode]);
      }

      // BFS寻找最短路径
      final path = await _bfs(
        from: fromNode,
        toId: query.toNodeId,
        maxDepth: query.maxDepth,
      );

      return QueryResult.success(path);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Failed to get node path: ${error.toString()}',
        stackTrace,
      );
    }
  }

  /// BFS算法寻找最短路径
  Future<List<Node>?> _bfs({
    required Node from,
    required String toId,
    required int maxDepth,
  }) async {
    final queue = Queue<List<Node>>();
    final visited = <String>{};

    queue.add([from]);
    visited.add(from.id);

    while (queue.isNotEmpty) {
      final path = queue.removeFirst();
      final current = path.last;

      // 达到最大深度
      if (path.length > maxDepth) {
        continue;
      }

      // 找到目标
      if (current.id == toId) {
        return path;
      }

      // 获取邻居节点
      final neighborIds = current.references.keys.toList();
      if (neighborIds.isEmpty) continue;

      final neighbors = await _repository.loadAll(neighborIds);

      for (final neighbor in neighbors) {
        if (visited.contains(neighbor.id)) continue;

        visited.add(neighbor.id);
        queue.add([...path, neighbor]);
      }
    }

    // 未找到路径
    return null;
  }
}

/// 获取节点度数的Handler
///
/// 使用AdjacencyList优化查询，提供O(1)复杂度的度数查询
class GetNodeDegreeQueryHandler extends QueryHandler<NodeDegree, GetNodeDegreeQuery> {
  /// 构造函数
  GetNodeDegreeQueryHandler(
    this._repository,
    this._adjacencyList,
  );

  final NodeRepository _repository;
  final AdjacencyList _adjacencyList;

  @override
  Future<QueryResult<NodeDegree>> handle(GetNodeDegreeQuery query) async {
    try {
      final node = await _repository.load(query.nodeId);
      if (node == null) {
        return QueryResult.failure('Node not found: ${query.nodeId}');
      }

      // 使用AdjacencyList获取度数
      final outDegree = _adjacencyList.getOutDegree(query.nodeId);
      final inDegree = _adjacencyList.getInDegree(query.nodeId);

      final degree = NodeDegree(
        inDegree: inDegree,
        outDegree: outDegree,
      );

      return QueryResult.success(degree);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Failed to get node degree: ${error.toString()}',
        stackTrace,
      );
    }
  }
}
