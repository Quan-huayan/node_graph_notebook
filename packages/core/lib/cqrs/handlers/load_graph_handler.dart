import 'package:core_data/core_data.dart';
import '../queries/load_graph_query.dart';
import '../query/query.dart';

/// 加载图的Handler
///
/// 处理 LoadGraphQuery，根据图ID加载指定的图
class LoadGraphHandler extends QueryHandler<Graph, LoadGraphQuery> {
  /// 构造函数
  LoadGraphHandler(this._graphRepository);
  final GraphRepository _graphRepository;

  @override
  Future<QueryResult<Graph>> handle(LoadGraphQuery query) async {
    try {
      final graph = await _graphRepository.load(query.graphId);
      if (graph == null) {
        return QueryResult.failure('Graph not found: ${query.graphId}');
      }
      return QueryResult.success(graph);
    } catch (e) {
      return QueryResult.failure(e.toString());
    }
  }
}
