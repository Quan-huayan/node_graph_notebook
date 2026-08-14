// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Connection _$ConnectionFromJson(Map<String, dynamic> json) => Connection(
  id: json['id'] as String,
  fromNodeId: json['fromNodeId'] as String,
  toNodeId: json['toNodeId'] as String,
  type: json['type'] as String,
  role: json['role'] as String?,
  color: json['color'] as String?,
  lineStyle: $enumDecode(_$LineStyleEnumMap, json['lineStyle']),
  thickness: (json['thickness'] as num).toDouble(),
);

Map<String, dynamic> _$ConnectionToJson(Connection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromNodeId': instance.fromNodeId,
      'toNodeId': instance.toNodeId,
      'type': instance.type,
      'role': instance.role,
      'color': instance.color,
      'lineStyle': _$LineStyleEnumMap[instance.lineStyle]!,
      'thickness': instance.thickness,
    };

const _$LineStyleEnumMap = {
  LineStyle.solid: 'solid',
  LineStyle.dashed: 'dashed',
  LineStyle.dotted: 'dotted',
};
