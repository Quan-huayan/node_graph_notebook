import 'dart:ui';
import 'package:json_annotation/json_annotation.dart';

/// Offset 序列化转换器
///
/// 用于在 JSON 和 Offset 对象之间进行转换
class OffsetConverter implements JsonConverter<Offset, Map<String, dynamic>> {
  /// 创建一个 Offset 序列化转换器
  const OffsetConverter();

  @override
  Offset fromJson(Map<String, dynamic> json) => Offset(
      (json['dx'] as num).toDouble(),
      (json['dy'] as num).toDouble(),
    );

  @override
  Map<String, dynamic> toJson(Offset object) => {'dx': object.dx, 'dy': object.dy};
}

/// Size 序列化转换器
///
/// 用于在 JSON 和 Size 对象之间进行转换
class SizeConverter implements JsonConverter<Size, Map<String, dynamic>> {
  /// 创建一个 Size 序列化转换器
  const SizeConverter();

  @override
  Size fromJson(Map<String, dynamic> json) => Size(
      (json['width'] as num).toDouble(),
      (json['height'] as num).toDouble(),
    );

  @override
  Map<String, dynamic> toJson(Size object) => {'width': object.width, 'height': object.height};
}
