/// 节点画布样式（M7.3）——判据② 外观直写，键 `style.graph.<nodeId>`。
///
/// 投影不变式（00 4.1）：样式是外观（UIStateStore），结构性数据（kind/
/// 内容/引用）仍走 Graph。样式只在画布卡片壳层应用（_PositionedCard/
/// NodeCard），卡片体 Hook 渲染保持样式无关。
library;

import 'dart:ui';

/// 卡片形态（M7.3 样式模式：卡片 / 圆圈两种样子）。
enum NodeCardMode {
  /// 矩形卡片（默认）。
  card,

  /// 圆形节点。
  circle,
}

/// 画布卡片默认尺寸（node_graph 的 cardSize 引用此常量，唯一默认源）。
const Size defaultCardSize = Size(180, 96);

/// 画布样式键前缀。
const String canvasStylePrefix = 'style.graph.';

/// 节点样式键（`style.graph.<nodeId>`）。
String canvasStyleKey(String nodeId) => '$canvasStylePrefix$nodeId';

/// 节点画布样式（缺省字段 = null = 用默认）。
class NodeStyle {
  /// 构造样式；字段缺省 = null = 默认。
  const NodeStyle({this.color, this.width, this.height, this.mode});

  /// 卡片底色（'#RRGGBB'；null = 按 kind 默认配色）。
  final String? color;

  /// 卡片宽（null = 默认 180）。
  final double? width;

  /// 卡片高（null = 默认 96）。
  final double? height;

  /// 形态（null = 卡片）。
  final NodeCardMode? mode;

  /// 全部字段缺省（用于"恢复默认"）。
  bool get isEmpty =>
      color == null && width == null && height == null && mode == null;

  /// 样式尺寸（缺省字段回退默认）。
  Size get size =>
      Size(width ?? defaultCardSize.width, height ?? defaultCardSize.height);

  /// JSON 序列化（判据② KV 存储）。
  Map<String, dynamic> toJson() => <String, dynamic>{
    if (color != null) 'color': color,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (mode != null) 'mode': mode!.name,
  };
}

/// 容错解析（损坏值/缺字段 → null 字段，永不抛）。
NodeStyle? parseNodeStyle(dynamic value) {
  if (value is! Map<String, dynamic>) {
    return null;
  }
  String? color;
  final rawColor = value['color'];
  if (rawColor is String) {
    color = rawColor;
  }
  double? width;
  final rawWidth = value['width'];
  if (rawWidth is num) {
    width = rawWidth.toDouble();
  }
  double? height;
  final rawHeight = value['height'];
  if (rawHeight is num) {
    height = rawHeight.toDouble();
  }
  NodeCardMode? mode;
  switch (value['mode']) {
    case 'circle':
      mode = NodeCardMode.circle;
    case 'card':
      mode = NodeCardMode.card;
  }
  return NodeStyle(color: color, width: width, height: height, mode: mode);
}

/// '#RRGGBB'（或 '#RRGGBBAA'）→ Color；非法 → null。
Color? parseHexColor(String? hex) {
  if (hex == null) {
    return null;
  }
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) {
    h = 'FF$h';
  }
  final value = int.tryParse(h, radix: 16);
  if (value == null) {
    return null;
  }
  return Color(value);
}

/// 按 kind 的默认配色（null = 走主题）——卡片辨识度（M7.3）。
///
/// 浅色用 50 系浅色（背景不抢文字，用户自定义深色时由对话框提示
/// 对比）；P2-5：暗色变体——暗色主题下浅色 pastel 刺眼且与浅色
/// 文字对比失衡，换同色相深色 tint（暗表面 + 色相倾向，对比度合格）。
Color? defaultColorForKind(String? kind, {Brightness brightness = Brightness.light}) {
  switch (kind) {
    case 'ai':
      // indigo：浅 50 / 暗 tint。
      return brightness == Brightness.dark
          ? const Color(0xFF26263B)
          : const Color(0xFFE8EAF6);
    case 'folder':
      // amber：浅 50 / 暗 tint。
      return brightness == Brightness.dark
          ? const Color(0xFF2A2619)
          : const Color(0xFFFFF8E1);
    default:
      return null;
  }
}
