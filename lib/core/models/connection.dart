import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';
import 'node.dart';

part 'connection.g.dart';

/// 连接关系（计算属性，从 Node 的 references 得出）
@JsonSerializable()
class Connection {
  const Connection({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.referenceType,
    this.role,
    this.color,
    required this.lineStyle,
    required this.thickness,
  });

  factory Connection.fromJson(Map<String, dynamic> json) =>
      _$ConnectionFromJson(json);

  /// 连接ID（自动生成：fromId_toId）
  final String id;

  /// 起始节点ID
  final String fromNodeId;

  /// 目标节点ID
  final String toNodeId;

  /// 引用类型（决定边的语义）
  final ReferenceType referenceType;

  /// 角色标签
  final String? role;

  /// 颜色
  final String? color;

  /// 线型
  final LineStyle lineStyle;

  /// 线宽
  final double thickness;

  /// 从 references 计算连接列表
  static List<Connection> calculateConnections(List<Node> nodes) {
    final connections = <Connection>[];
    final nodeMap = {for (var n in nodes) n.id: n};

    for (final node in nodes) {
      for (final ref in node.references.values) {
        if (nodeMap.containsKey(ref.nodeId)) {
          final connectionId = '${node.id}_${ref.nodeId}';
          connections.add(Connection(
            id: connectionId,
            fromNodeId: node.id,
            toNodeId: ref.nodeId,
            referenceType: ref.type,
            role: ref.role,
            lineStyle: _getLineStyleForType(ref.type),
            thickness: _getThicknessForType(ref.type),
          ));
        }
      }
    }

    return connections;
  }

  Map<String, dynamic> toJson() => _$ConnectionToJson(this);

  /// 根据引用类型获取线型
  static LineStyle _getLineStyleForType(ReferenceType type) {
    switch (type) {
      case ReferenceType.contains:
        return LineStyle.dashed; // 包含关系用虚线
      case ReferenceType.causes:
        return LineStyle.solid; // 因果关系用实线
      default:
        return LineStyle.solid;
    }
  }

  /// 根据引用类型获取线宽
  static double _getThicknessForType(ReferenceType type) {
    switch (type) {
      case ReferenceType.contains:
        return 2.0;
      case ReferenceType.causes:
        return 3.0;
      default:
        return 1.5;
    }
  }

  /// 获取反向连接
  Connection get reverse {
    return Connection(
      id: '${toNodeId}_$fromNodeId',
      fromNodeId: toNodeId,
      toNodeId: fromNodeId,
      referenceType: referenceType,
      role: role,
      color: color,
      lineStyle: lineStyle,
      thickness: thickness,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Connection &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Connection($fromNodeId -> $toNodeId, type: $referenceType)';
}
