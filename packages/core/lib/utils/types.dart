import 'dart:math';

/// 简单的 2D 向量类
///
/// 用于表示二维空间中的位置、方向或速度
class Vector2 {
  /// 创建一个新的 2D 向量
  ///
  /// [x] - x 坐标
  /// [y] - y 坐标
  const Vector2(this.x, this.y);

  /// x 坐标
  final double x;

  /// y 坐标
  final double y;

  /// 零向量 (0, 0)
  static const Vector2 zero = Vector2(0, 0);

  /// 向量加法
  ///
  /// [other] - 要添加的另一个向量
  /// 返回一个新的向量，其值为两个向量的和
  Vector2 operator +(Vector2 other) => Vector2(x + other.x, y + other.y);

  /// 向量减法
  ///
  /// [other] - 要减去的另一个向量
  /// 返回一个新的向量，其值为两个向量的差
  Vector2 operator -(Vector2 other) => Vector2(x - other.x, y - other.y);

  /// 向量乘法（标量）
  ///
  /// [scalar] - 标量值
  /// 返回一个新的向量，其值为原向量乘以标量
  Vector2 operator *(double scalar) => Vector2(x * scalar, y * scalar);

  /// 向量的长度（模）
  double get length => sqrt(x * x + y * y);

  /// 返回单位向量（长度为 1）
  ///
  /// 如果原向量长度为 0，则返回零向量
  Vector2 normalized() {
    final len = length;
    if (len == 0) return Vector2.zero;
    return Vector2(x / len, y / len);
  }

  /// 限制向量的坐标在指定范围内
  ///
  /// [min] - 最小值
  /// [max] - 最大值
  /// 返回一个新的向量，其坐标被限制在 [min, max] 范围内
  Vector2 clamp(double min, double max) => Vector2(
      x.clamp(min, max),
      y.clamp(min, max),
    );
}
