import '../../models/node.dart';
import '../query/query.dart';

/// 节点搜索查询
///
/// 根据关键词搜索节点标题和内容
class SearchNodesQuery extends CacheableQuery<List<Node>> {
  /// 构造函数
  const SearchNodesQuery({
    required this.keyword,
    this.limit = 100,
    this.offset = 0,
  });

  /// 搜索关键词
  final String keyword;

  /// 返回结果最大数量
  final int limit;

  /// 结果偏移量（分页）
  final int offset;

  @override
  String get cacheKey => 'SearchNodes:$keyword:$limit:$offset';

  @override
  Duration? get cacheTtl => const Duration(minutes: 5);
}

/// 节点过滤查询
///
/// 根据条件过滤节点
class FilterNodesQuery extends CacheableQuery<List<Node>> {
  /// 构造函数
  const FilterNodesQuery({
    this.tags,
    this.createdAtStart,
    this.createdAtEnd,
    this.updatedAtStart,
    this.updatedAtEnd,
    this.limit = 100,
    this.offset = 0,
  });

  /// 标签过滤
  final List<String>? tags;

  /// 创建时间范围起始
  final DateTime? createdAtStart;

  /// 创建时间范围结束
  final DateTime? createdAtEnd;

  /// 更新时间范围起始
  final DateTime? updatedAtStart;

  /// 更新时间范围结束
  final DateTime? updatedAtEnd;

  /// 返回结果最大数量
  final int limit;

  /// 结果偏移量（分页）
  final int offset;

  @override
  String get cacheKey => 'FilterNodes:'
      '${tags?.join(',') ?? "all"}:'
      '${createdAtStart?.millisecondsSinceEpoch ?? "any"}:'
      '${createdAtEnd?.millisecondsSinceEpoch ?? "any"}:'
      '${updatedAtStart?.millisecondsSinceEpoch ?? "any"}:'
      '${updatedAtEnd?.millisecondsSinceEpoch ?? "any"}:'
      '$limit:$offset';

  @override
  Duration? get cacheTtl => const Duration(minutes: 5);
}

/// 获取最近更新的节点
///
/// 获取最近更新的N个节点
class GetRecentNodesQuery extends CacheableQuery<List<Node>> {
  /// 构造函数
  const GetRecentNodesQuery({
    this.limit = 20,
  });

  /// 返回节点数量
  final int limit;

  @override
  String get cacheKey => 'GetRecentNodes:$limit';

  @override
  Duration? get cacheTtl => const Duration(minutes: 2);
}
