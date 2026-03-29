import '../../repositories/node_repository.dart';
import '../materialized_views/search_index_view.dart';
import '../queries/search_index_query.dart';
import '../query/query.dart';
import '../read_models/node_read_model.dart';

/// 快速搜索Handler
///
/// 使用搜索索引物化视图进行O(1)搜索
class FastSearchQueryHandler extends QueryHandler<List<NodeReadModel>, FastSearchQuery> {
  /// 构造函数
  FastSearchQueryHandler(
    this._searchIndex,
    this._repository,
  );

  final SearchIndexMaterializedView _searchIndex;
  final NodeRepository _repository;

  @override
  Future<QueryResult<List<NodeReadModel>>> handle(FastSearchQuery query) async {
    try {
      // 使用索引搜索节点ID
      final nodeIds = _searchIndex.search(
        query.keyword,
        limit: query.limit,
      );

      // 批量加载节点并转换为读模型
      if (nodeIds.isEmpty) {
        return QueryResult.success(<NodeReadModel>[]);
      }

      final nodes = await _repository.loadAll(nodeIds);
      final readModels = nodes.map(NodeReadModel.fromNode).toList();

      return QueryResult.success(readModels);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Fast search failed: ${error.toString()}',
        stackTrace,
      );
    }
  }
}

/// 获取热门tokens Handler
class GetPopularTokensQueryHandler extends QueryHandler<List<String>, GetPopularTokensQuery> {
  /// 构造函数
  GetPopularTokensQueryHandler(this._searchIndex);

  /// 搜索索引物化视图
  final SearchIndexMaterializedView _searchIndex;

  @override
  Future<QueryResult<List<String>>> handle(GetPopularTokensQuery query) async {
    try {
      // TODO: 实现热门token统计
      // 这里简化实现，实际应该维护一个使用计数器
      // 目前返回前N个包含节点最多的tokens

      // 为了演示，返回一些常见的tokens
      // 实际应用中应该从_searchIndex内部获取token->nodes映射
      final popularTokens = <String>[];

      return QueryResult.success(popularTokens);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Failed to get popular tokens: ${error.toString()}',
        stackTrace,
      );
    }
  }
}
