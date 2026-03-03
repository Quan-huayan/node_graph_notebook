import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';

part 'node_reference.g.dart';

/// 节点引用关系
@JsonSerializable()
class NodeReference {
  const NodeReference({
    required this.nodeId,
    required this.type,
    this.role,
    this.metadata,
  });

  /// 转换为JSON
  factory NodeReference.fromJson(Map<String, dynamic> json) =>
      _$NodeReferenceFromJson(json);

  /// 被引用的节点ID
  final String nodeId;

  /// 引用类型
  final ReferenceType type;

  /// 在当前节点中的角色或标签（可选）
  final String? role;

  /// 额外元数据
  final Map<String, dynamic>? metadata;

  /// 从JSON创建
  Map<String, dynamic> toJson() => _$NodeReferenceToJson(this);

  /// 复制并更新部分字段
  NodeReference copyWith({
    String? nodeId,
    ReferenceType? type,
    String? role,
    Map<String, dynamic>? metadata,
  }) {
    return NodeReference(
      nodeId: nodeId ?? this.nodeId,
      type: type ?? this.type,
      role: role ?? this.role,
      metadata: metadata ?? this.metadata,
    );
  }

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
      'NodeReference(nodeId: $nodeId, type: $type, role: $role)';
}
