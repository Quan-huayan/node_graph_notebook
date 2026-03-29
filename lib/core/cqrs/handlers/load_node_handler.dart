import '../../models/node.dart';
import '../../repositories/node_repository.dart';
import '../queries/load_node_query.dart';
import '../query/query.dart';

/// 加载单个节点的Handler
class LoadNodeQueryHandler extends QueryHandler<Node?, LoadNodeQuery> {
  /// 构造函数
  LoadNodeQueryHandler(this._repository);

  final NodeRepository _repository;

  @override
  Future<QueryResult<Node?>> handle(LoadNodeQuery query) async {
    try {
      final node = await _repository.load(query.nodeId);
      return QueryResult.success(node);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Failed to load node: ${error.toString()}',
        stackTrace,
      );
    }
  }
}

/// 批量加载节点的Handler
class LoadNodesQueryHandler extends QueryHandler<List<Node>, LoadNodesQuery> {
  /// 构造函数
  LoadNodesQueryHandler(this._repository);

  final NodeRepository _repository;

  @override
  Future<QueryResult<List<Node>>> handle(LoadNodesQuery query) async {
    try {
      final nodes = await _repository.loadAll(query.nodeIds);
      return QueryResult.success(nodes);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Failed to load nodes: ${error.toString()}',
        stackTrace,
      );
    }
  }
}

/// 加载所有节点的Handler
class LoadAllNodesQueryHandler extends QueryHandler<List<Node>, LoadAllNodesQuery> {
  /// 构造函数
  LoadAllNodesQueryHandler(this._repository);

  final NodeRepository _repository;

  @override
  Future<QueryResult<List<Node>>> handle(LoadAllNodesQuery query) async {
    try {
      final nodes = await _repository.queryAll();
      return QueryResult.success(nodes);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Failed to load all nodes: ${error.toString()}',
        stackTrace,
      );
    }
  }
}
