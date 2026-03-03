import 'package:json_annotation/json_annotation.dart';

/// 节点类型
enum NodeType {
  /// 内容节点：存储笔记内容
  @JsonValue('content')
  content,

  /// 概念节点：代表关系或抽象概念
  @JsonValue('concept')
  concept,
}

/// 引用类型
enum ReferenceType {
  /// 提及：在content中提到了该节点
  @JsonValue('mentions')
  mentions,

  /// 包含：概念节点包含该节点（一阶关系）
  @JsonValue('contains')
  contains,

  /// 依赖：当前节点依赖于该节点
  @JsonValue('dependsOn')
  dependsOn,

  /// 导致：当前节点导致该节点（因果关系）
  @JsonValue('causes')
  causes,

  /// 属于：当前节点属于该节点（分类关系）
  @JsonValue('partOf')
  partOf,

  /// 关联：一般性关联
  @JsonValue('relatesTo')
  relatesTo,

  /// 引用：引用或参考
  @JsonValue('references')
  references,

  /// 实例化：当前节点是该节点的实例
  @JsonValue('instanceOf')
  instanceOf,
}

/// 节点显示模式
enum NodeViewMode {
  /// 仅标题
  @JsonValue('titleOnly')
  titleOnly,

  /// 标题+摘要（前几行）
  @JsonValue('titleWithPreview')
  titleWithPreview,

  /// 完整 Markdown 内容
  @JsonValue('fullContent')
  fullContent,

  /// 紧凑模式（小图标）
  @JsonValue('compact')
  compact,

  /// 概念地图模式（特殊样式）
  @JsonValue('conceptMap')
  conceptMap,
}

/// 视图模式类型
enum ViewModeType {
  /// 普通图示
  @JsonValue('normalGraph')
  normalGraph,

  /// 概念地图
  @JsonValue('conceptMap')
  conceptMap,

  /// 混合模式
  @JsonValue('mixed')
  mixed,
}

/// 布局算法
enum LayoutAlgorithm {
  /// 力导向
  @JsonValue('forceDirected')
  forceDirected,

  /// 层级
  @JsonValue('hierarchical')
  hierarchical,

  /// 环形
  @JsonValue('circular')
  circular,

  /// 概念地图专用
  @JsonValue('conceptMap')
  conceptMap,

  /// 自由布局
  @JsonValue('free')
  free,
}

/// 背景样式
enum BackgroundStyle {
  /// 网格
  @JsonValue('grid')
  grid,

  /// 点阵
  @JsonValue('dots')
  dots,

  /// 无
  @JsonValue('none')
  none,
}

/// 连接线型
enum LineStyle {
  /// 实线
  @JsonValue('solid')
  solid,

  /// 虚线
  @JsonValue('dashed')
  dashed,

  /// 点线
  @JsonValue('dotted')
  dotted,
}
