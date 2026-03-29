import '../../models/node.dart';
import '../../repositories/node_repository.dart';
import '../queries/search_nodes_query.dart';
import '../query/query.dart';

/// 搜索节点的Handler
class SearchNodesQueryHandler extends QueryHandler<List<Node>, SearchNodesQuery> {
  /// 构造函数
  SearchNodesQueryHandler(this._repository);

  final NodeRepository _repository;

  @override
  Future<QueryResult<List<Node>>> handle(SearchNodesQuery query) async {
    try {
      final nodes = await _repository.search(
        title: query.keyword,
        content: query.keyword,
      );

      // 应用分页
      final start = query.offset;
      final paginatedNodes = nodes.skip(start).take(query.limit).toList();

      return QueryResult.success(paginatedNodes);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Failed to search nodes: ${error.toString()}',
        stackTrace,
      );
    }
  }
}

/// 过滤节点的Handler
class FilterNodesQueryHandler extends QueryHandler<List<Node>, FilterNodesQuery> {
  /// 构造函数
  FilterNodesQueryHandler(this._repository);

  final NodeRepository _repository;

  @override
  Future<QueryResult<List<Node>>> handle(FilterNodesQuery query) async {
    try {
      // 如果有标签过滤，使用search方法
      if (query.tags != null && query.tags!.isNotEmpty) {
        final nodes = await _repository.search(
          tags: query.tags,
          startDate: query.createdAtStart,
          endDate: query.createdAtEnd,
        );

        // 应用分页
        final start = query.offset;
        final paginatedNodes = nodes.skip(start).take(query.limit).toList();

        return QueryResult.success(paginatedNodes);
      }

      // 否则获取所有节点并过滤
      final allNodes = await _repository.queryAll();
      var filtered = allNodes;

      // 按创建时间过滤
      if (query.createdAtStart != null) {
        filtered = filtered
            .where((n) => n.createdAt.isAfter(query.createdAtStart!))
            .toList();
      }
      if (query.createdAtEnd != null) {
        filtered = filtered
            .where((n) => n.createdAt.isBefore(query.createdAtEnd!))
            .toList();
      }

      // 按更新时间过滤
      if (query.updatedAtStart != null) {
        filtered = filtered
            .where((n) => n.updatedAt.isAfter(query.updatedAtStart!))
            .toList();
      }
      if (query.updatedAtEnd != null) {
        filtered = filtered
            .where((n) => n.updatedAt.isBefore(query.updatedAtEnd!))
            .toList();
      }

      // 应用分页
      final start = query.offset;
      final paginatedNodes = filtered.skip(start).take(query.limit).toList();

      return QueryResult.success(paginatedNodes);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Failed to filter nodes: ${error.toString()}',
        stackTrace,
      );
    }
  }
}

/// 获取最近节点的Handler
class GetRecentNodesQueryHandler extends QueryHandler<List<Node>, GetRecentNodesQuery> {
  /// 构造函数
  GetRecentNodesQueryHandler(this._repository);

  final NodeRepository _repository;

  @override
  Future<QueryResult<List<Node>>> handle(GetRecentNodesQuery query) async {
    try {
      final allNodes = await _repository.queryAll();

      // 按更新时间降序排序
      allNodes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      // 取前N个
      final recentNodes = allNodes.take(query.limit).toList();

      return QueryResult.success(recentNodes);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Failed to get recent nodes: ${error.toString()}',
        stackTrace,
      );
    }
  }
}
