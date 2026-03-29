import '../../repositories/node_repository.dart';
import '../queries/list_nodes_query.dart';
import '../query/query.dart';
import '../read_models/node_read_model.dart';

/// 列出节点Handler（返回轻量级读模型）
class ListNodesQueryHandler extends QueryHandler<List<NodeReadModel>, ListNodesQuery> {
  /// 构造函数
  ListNodesQueryHandler(this._repository);

  final NodeRepository _repository;

  @override
  Future<QueryResult<List<NodeReadModel>>> handle(ListNodesQuery query) async {
    try {
      // 获取所有节点
      final nodes = await _repository.queryAll();

      // 转换为轻量级读模型
      final readModels = nodes.map(NodeReadModel.fromNode).toList();

      // 排序
      switch (query.sortBy) {
        case ListSortBy.title:
          readModels.sort((a, b) => query.ascending
              ? a.title.compareTo(b.title)
              : b.title.compareTo(a.title));
          break;
        case ListSortBy.createdAt:
          readModels.sort((a, b) => query.ascending
              ? a.createdAt.compareTo(b.createdAt)
              : b.createdAt.compareTo(a.createdAt));
          break;
        case ListSortBy.updatedAt:
          readModels.sort((a, b) => query.ascending
              ? a.updatedAt.compareTo(b.updatedAt)
              : b.updatedAt.compareTo(a.updatedAt));
          break;
      }

      // 分页
      final start = query.offset;
      final end = (start + query.limit).clamp(0, readModels.length);
      final paginatedModels = readModels.sublist(start, end);

      return QueryResult.success(paginatedModels);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Failed to list nodes: ${error.toString()}',
        stackTrace,
      );
    }
  }
}

/// 获取节点读模型Handler
class GetNodeReadModelsQueryHandler extends QueryHandler<List<NodeReadModel>, GetNodeReadModelsQuery> {
  /// 构造函数
  GetNodeReadModelsQueryHandler(this._repository);

  final NodeRepository _repository;

  @override
  Future<QueryResult<List<NodeReadModel>>> handle(GetNodeReadModelsQuery query) async {
    try {
      // 批量加载节点
      final nodes = await _repository.loadAll(query.nodeIds);

      // 转换为轻量级读模型
      final readModels = nodes.map(NodeReadModel.fromNode).toList();

      return QueryResult.success(readModels);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Failed to get node read models: ${error.toString()}',
        stackTrace,
      );
    }
  }
}
