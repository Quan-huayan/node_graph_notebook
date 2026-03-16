import '../../../../core/events/app_events.dart';

/// 布局应用事件
///
/// 发布当布局算法成功应用到图时
class LayoutAppliedEvent extends AppEvent {
  /// 构造函数
  ///
  /// [graphId] - 图 ID
  /// [layoutType] - 布局类型
  /// [nodeCount] - 受影响的节点数量
  const LayoutAppliedEvent({
    required this.graphId,
    required this.layoutType,
    required this.nodeCount,
  });

  /// 图 ID
  final String graphId;

  /// 布局类型
  final String layoutType;

  /// 受影响的节点数量
  final int nodeCount;

  @override
  String toString() =>
      'LayoutAppliedEvent(graph: $graphId, layout: $layoutType, nodes: $nodeCount)';
}

/// 节点位置变化事件
///
/// 发布当批量节点位置发生变化时
class NodePositionsChangedEvent extends AppEvent {
  /// 构造函数
  ///
  /// [nodeIds] - 受影响的节点 ID 列表
  const NodePositionsChangedEvent({required this.nodeIds});

  /// 受影响的节点 ID 列表
  final List<String> nodeIds;

  @override
  String toString() => 'NodePositionsChangedEvent(${nodeIds.length} nodes)';
}
