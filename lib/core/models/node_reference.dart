import 'package:json_annotation/json_annotation.dart';

part 'node_reference.g.dart';

/// 节点引用关系
///
/// 存储节点间的各种关系，所有关系属性都存储在 `properties` Map 中。
/// 标准关系类型包括：mentions, contains, dependsOn, causes, partOf, relatesTo, references, instanceOf
///
/// 示例：
/// ```dart
/// NodeReference(
///   nodeId: 'targetId',
///   properties: {
///     'type': 'contains',
///     'role': 'section',
///     'strength': 0.8,
///   },
/// )
/// ```
@JsonSerializable()
class NodeReference {
  /// 创建一个节点引用关系
  ///
  /// [nodeId] - 被引用的节点ID
  /// [properties] - 关系属性（包含类型、角色、权重等所有信息）
  const NodeReference({required this.nodeId, required this.properties});

  /// 从JSON创建
  factory NodeReference.fromJson(Map<String, dynamic> json) =>
      _$NodeReferenceFromJson(json);

  /// 被引用的节点ID
  final String nodeId;

  /// 关系属性（包含类型、角色、权重等所有信息）
  ///
  /// 标准属性：
  /// - `type`: 关系类型（字符串），如 'contains', 'dependsOn' 等
  /// - `role`: 可选的角色标签
  /// - 其他自定义属性
  final Map<String, dynamic> properties;

  /// 获取关系类型
  String get type => properties['type'] as String? ?? 'relatesTo';

  /// 获取角色标签
  String? get role => properties['role'] as String?;

  /// 转换为JSON
  Map<String, dynamic> toJson() => _$NodeReferenceToJson(this);

  /// 复制并更新部分字段
  NodeReference copyWith({String? nodeId, Map<String, dynamic>? properties}) => NodeReference(
      nodeId: nodeId ?? this.nodeId,
      properties: properties ?? this.properties,
    );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeReference &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          type == other.type;

  @override
  int get hashCode => nodeId.hashCode ^ type.hashCode;

  @override
  String toString() =>
      'NodeReference(nodeId: $nodeId, type: $type, properties: $properties)';
}
