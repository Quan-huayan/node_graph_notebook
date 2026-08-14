import 'package:core_data/core_data.dart';
import '../query/query.dart';

/// 加载图的查询
///
/// 根据图ID加载指定的图
class LoadGraphQuery extends Query<Graph> {
  /// 构造函数
  const LoadGraphQuery({required this.graphId});

  /// 要加载的图ID
  final String graphId;
}
