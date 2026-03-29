import '../query/query.dart';
import '../read_models/node_read_model.dart';

/// 获取节点列表查询（轻量级）
///
/// 使用 NodeReadModel 返回轻量级节点数据
/// 适用于列表展示、图可视化等场景
class ListNodesQuery extends CacheableQuery<List<NodeReadModel>> {
  /// 构造函数
  const ListNodesQuery({
    this.limit = 1000,
    this.offset = 0,
    this.sortBy = ListSortBy.updatedAt,
    this.ascending = false,
  });

  /// 返回结果最大数量
  final int limit;

  /// 结果偏移量（分页）
  final int offset;

  /// 排序字段
  final ListSortBy sortBy;

  /// 是否升序排列
  final bool ascending;

  @override
  String get cacheKey => 'ListNodes:$limit:$offset:${sortBy.name}:$ascending';

  @override
  Duration? get cacheTtl => const Duration(minutes: 5);
}

/// 列表排序字段
enum ListSortBy {
  /// 按标题排序
  title,

  /// 按创建时间排序
  createdAt,

  /// 按更新时间排序
  updatedAt,
}

/// 获取节点读模型查询
///
/// 根据ID列表获取轻量级节点数据
class GetNodeReadModelsQuery extends CacheableQuery<List<NodeReadModel>> {
  /// 构造函数
  const GetNodeReadModelsQuery({
    required this.nodeIds,
  });

  /// 节点ID列表
  final List<String> nodeIds;

  @override
  String get cacheKey => 'GetNodeReadModels:${nodeIds.join(',')}';

  @override
  Duration? get cacheTtl => const Duration(minutes: 10);
}
