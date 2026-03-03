import 'dart:ui';
import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';
import 'node_reference.dart';

part 'node.g.dart';

/// Offset 序列化转换器
class OffsetConverter implements JsonConverter<Offset, Map<String, double>> {
  const OffsetConverter();

  @override
  Offset fromJson(Map<String, double> json) {
    return Offset(json['dx']!, json['dy']!);
  }

  @override
  Map<String, double> toJson(Offset object) {
    return {'dx': object.dx, 'dy': object.dy};
  }
}

/// Size 序列化转换器
class SizeConverter implements JsonConverter<Size, Map<String, double>> {
  const SizeConverter();

  @override
  Size fromJson(Map<String, double> json) {
    return Size(json['width']!, json['height']!);
  }

  @override
  Map<String, double> toJson(Size object) {
    return {'width': object.width, 'height': object.height};
  }
}

/// 统一节点模型
/// 所有元素（内容、关系、概念）都继承自统一的 Node 模型
@JsonSerializable()
class Node {
  const Node({
    required this.id,
    required this.type,
    required this.title,
    this.content,
    required this.references,
    required this.position,
    required this.size,
    required this.viewMode,
    this.color,
    required this.createdAt,
    required this.updatedAt,
    required this.metadata,
  });

  /// 从JSON创建
  factory Node.fromJson(Map<String, dynamic> json) => _$NodeFromJson(json);

  /// 唯一标识符
  final String id;

  /// 节点类型
  final NodeType type;

  /// 节点标题
  final String title;

  /// Markdown 内容（可选）
  final String? content;

  /// 涉及的节点映射（key: 节点ID, value: 引用关系）
  final Map<String, NodeReference> references;

  /// 位置坐标
  @OffsetConverter()
  final Offset position;

  /// 节点尺寸
  @SizeConverter()
  final Size size;

  /// 显示模式
  final NodeViewMode viewMode;

  /// 颜色
  final String? color;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 元数据
  final Map<String, dynamic> metadata;

  /// 转换为JSON
  Map<String, dynamic> toJson() => _$NodeToJson(this);

  /// 便捷方法：类型标签
  String get typeLabel => type.name;

  /// 便捷方法：是否是概念节点
  bool get isConcept => type == NodeType.concept;

  /// 便捷方法：是否是内容节点
  bool get isContent => type == NodeType.content;

  /// 便捷方法：是否是文件夹
  bool get isFolder => metadata['isFolder'] == true ||
      (metadata['isFolder'] is bool && metadata['isFolder'] as bool);

  /// 获取所有引用的节点ID
  List<String> get referencedNodeIds => references.keys.toList();

  /// 获取特定类型的引用
  List<NodeReference> getReferencesByType(ReferenceType type) {
    return references.values.where((r) => r.type == type).toList();
  }

  /// 复制并更新部分字段
  Node copyWith({
    String? id,
    NodeType? type,
    String? title,
    String? content,
    Map<String, NodeReference>? references,
    Offset? position,
    Size? size,
    NodeViewMode? viewMode,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Node(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      references: references ?? this.references,
      position: position ?? this.position,
      size: size ?? this.size,
      viewMode: viewMode ?? this.viewMode,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// 添加引用
  Node addReference(String nodeId, NodeReference reference) {
    final newReferences = Map<String, NodeReference>.from(references);
    newReferences[nodeId] = reference;
    return copyWith(references: newReferences);
  }

  /// 移除引用
  Node removeReference(String nodeId) {
    final newReferences = Map<String, NodeReference>.from(references);
    newReferences.remove(nodeId);
    return copyWith(references: newReferences);
  }

  /// 更新时间戳
  Node updateTimestamp() {
    return copyWith(updatedAt: DateTime.now());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Node &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Node(id: $id, type: $type, title: $title, refs: ${references.length})';
}
