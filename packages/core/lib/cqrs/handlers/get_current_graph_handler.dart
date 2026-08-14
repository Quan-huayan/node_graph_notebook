import 'package:core_data/core_data.dart';
import '../queries/get_current_graph_query.dart';
import '../query/query.dart';

/// 获取当前图的Handler
///
/// 处理 GetCurrentGraphQuery，返回当前活动的图
class GetCurrentGraphHandler extends QueryHandler<Graph, GetCurrentGraphQuery> {
  /// 构造函数
  GetCurrentGraphHandler(this._graphRepository);
  final GraphRepository _graphRepository;

  @override
  Future<QueryResult<Graph>> handle(GetCurrentGraphQuery query) async {
    try {
      final graph = await _graphRepository.getCurrent();
      if (graph == null) {
        return QueryResult.failure('No current graph found');
      }
      return QueryResult.success(graph);
    } catch (e) {
      return QueryResult.failure(e.toString());
    }
  }
}
