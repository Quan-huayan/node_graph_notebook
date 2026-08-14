/// ValueRect —— 数值矩形（core 零 Flutter 依赖；视口契约用）。
///
/// UIManager.onViewportChanged 的载荷类型（architecture.md §5.1）：
/// 视口变化 → 窗口化物化的输入。不 import dart:ui（04 §三 约束 2）。
library;

/// 不可变数值矩形。
class ValueRect {
  /// 视图区几何（x/y 为左上角）。
  const ValueRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// 左上角 x。
  final double x;

  /// 左上角 y。
  final double y;

  /// 宽度。
  final double width;

  /// 高度。
  final double height;

  /// 点是否在矩形内（含边界）。
  bool contains(double px, double py) =>
      px >= x && px <= x + width && py >= y && py <= y + height;
}
