import 'dart:math';

/// 简单的 2D 向量类
class Vector2 {
  const Vector2(this.x, this.y);

  final double x;
  final double y;

  static const Vector2 zero = Vector2(0, 0);

  Vector2 operator +(Vector2 other) => Vector2(x + other.x, y + other.y);
  Vector2 operator -(Vector2 other) => Vector2(x - other.x, y - other.y);
  Vector2 operator *(double scalar) => Vector2(x * scalar, y * scalar);

  double get length => sqrt(x * x + y * y);

  Vector2 normalized() {
    final len = length;
    if (len == 0) return Vector2.zero;
    return Vector2(x / len, y / len);
  }

  Vector2 clamp(double min, double max) {
    return Vector2(
      x.clamp(min, max),
      y.clamp(min, max),
    );
  }
}
