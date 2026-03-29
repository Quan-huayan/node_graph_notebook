import '../../models/node.dart';
import '../query/query.dart';

/// 加载单个节点查询
///
/// 根据节点ID加载完整的节点数据
class LoadNodeQuery extends CacheableQuery<Node?> {
  /// 构造函数
  const LoadNodeQuery({
    required this.nodeId,
  });

  /// 节点ID
  final String nodeId;

  @override
  String get cacheKey => 'LoadNode:$nodeId';
}

/// 加载多个节点查询
///
/// 根据节点ID列表批量加载节点数据
class LoadNodesQuery extends CacheableQuery<List<Node>> {
  /// 构造函数
  const LoadNodesQuery({
    required this.nodeIds,
  });

  /// 节点ID列表
  final List<String> nodeIds;

  @override
  String get cacheKey => 'LoadNodes:${nodeIds.join(',')}';

  @override
  Duration? get cacheTtl => const Duration(minutes: 10);
}

/// 加载所有节点查询
///
/// 加载系统中所有节点（谨慎使用，数据量大时性能开销大）
class LoadAllNodesQuery extends Query<List<Node>> {
  /// 构造函数
  const LoadAllNodesQuery();

  /// 是否包含已删除的节点
  final bool includeDeleted = false;
}
