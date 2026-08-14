import 'package:core_data/core_data.dart';
import '../query/query.dart';

/// 按节点 ID 列表批量加载节点查询
class LoadNodesByIdsQuery extends Query<List<Node>> {
  /// 创建按 ID 列表加载节点查询
  const LoadNodesByIdsQuery({required this.nodeIds});

  /// 要加载的节点 ID 列表
  final List<String> nodeIds;
}
