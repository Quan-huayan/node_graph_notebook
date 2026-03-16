import 'package:json_annotation/json_annotation.dart';

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
