import 'package:core_data/core_data.dart';
import '../queries/load_nodes_by_ids_query.dart';
import '../query/query.dart';

/// 根据ID列表加载节点的Handler
///
/// 处理 LoadNodesByIdsQuery，根据节点ID列表批量加载节点
class LoadNodesByIdsHandler extends QueryHandler<List<Node>, LoadNodesByIdsQuery> {
  /// 构造函数
  LoadNodesByIdsHandler(this._nodeRepository);
  final NodeRepository _nodeRepository;

  @override
  Future<QueryResult<List<Node>>> handle(LoadNodesByIdsQuery query) async {
    try {
      final nodes = await _nodeRepository.loadAll(query.nodeIds);
      return QueryResult.success(nodes);
    } catch (e) {
      return QueryResult.failure(e.toString());
    }
  }
}
