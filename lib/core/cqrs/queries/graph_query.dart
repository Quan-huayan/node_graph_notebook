import '../../models/node.dart';
import '../query/query.dart';

/// 获取节点的邻居
///
/// 获取指定节点的所有邻居节点（通过引用关系连接）
class GetNeighborNodesQuery extends CacheableQuery<List<Node>> {
  /// 构造函数
  const GetNeighborNodesQuery({
    required this.nodeId,
    this.direction = NeighborDirection.both,
  });

  /// 中心节点ID
  final String nodeId;

  /// 邻居方向
  final NeighborDirection direction;

  @override
  String get cacheKey => 'GetNeighbors:$nodeId:${direction.name}';

  @override
  Duration? get cacheTtl => const Duration(minutes: 5);
}

/// 获取节点的引用关系
///
/// 获取节点引用的所有其他节点（outgoing references）
class GetOutgoingReferencesQuery extends CacheableQuery<List<Node>> {
  /// 构造函数
  const GetOutgoingReferencesQuery({
    required this.nodeId,
  });

  /// 源节点ID
  final String nodeId;

  @override
  String get cacheKey => 'GetOutgoingRefs:$nodeId';

  @override
  Duration? get cacheTtl => const Duration(minutes: 5);
}

/// 获取引用到节点的所有节点
///
/// 获取所有引用到指定节点的节点（incoming references）
class GetIncomingReferencesQuery extends CacheableQuery<List<Node>> {
  /// 构造函数
  const GetIncomingReferencesQuery({
    required this.nodeId,
  });

  /// 目标节点ID
  final String nodeId;

  @override
  String get cacheKey => 'GetIncomingRefs:$nodeId';

  @override
  Duration? get cacheTtl => const Duration(minutes: 5);
}

/// 获取节点的路径
///
/// 获取从一个节点到另一个节点的最短路径
class GetNodePathQuery extends CacheableQuery<List<Node>?> {
  /// 构造函数
  const GetNodePathQuery({
    required this.fromNodeId,
    required this.toNodeId,
    this.maxDepth = 5,
  });

  /// 起始节点ID
  final String fromNodeId;

  /// 目标节点ID
  final String toNodeId;

  /// 最大搜索深度
  final int maxDepth;

  @override
  String get cacheKey => 'GetPath:$fromNodeId:$toNodeId:$maxDepth';

  @override
  Duration? get cacheTtl => const Duration(minutes: 10);
}

/// 获取节点的度数
///
/// 获取节点的入度和出度信息
class GetNodeDegreeQuery extends CacheableQuery<NodeDegree> {
  /// 构造函数
  const GetNodeDegreeQuery({
    required this.nodeId,
  });

  /// 节点ID
  final String nodeId;

  @override
  String get cacheKey => 'GetNodeDegree:$nodeId';

  @override
  Duration? get cacheTtl => const Duration(minutes: 5);
}

/// 邻居方向枚举
enum NeighborDirection {
  /// 仅出边（当前节点引用的节点）
  outgoing,

  /// 仅入边（引用当前节点的节点）
  incoming,

  /// 双向（所有邻居）
  both,
}

/// 节点度数信息
class NodeDegree {
  /// 构造函数
  const NodeDegree({
    required this.inDegree,
    required this.outDegree,
  });

  /// 入度（有多少节点引用了此节点）
  final int inDegree;

  /// 出度（此节点引用了多少其他节点）
  final int outDegree;

  /// 总度数
  int get total => inDegree + outDegree;

  @override
  String toString() => 'NodeDegree(in: $inDegree, out: $outDegree, total: $total)';
}
