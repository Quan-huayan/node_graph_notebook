// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'node_reference.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NodeReference _$NodeReferenceFromJson(Map<String, dynamic> json) =>
    NodeReference(
      nodeId: json['nodeId'] as String,
      properties: json['properties'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$NodeReferenceToJson(NodeReference instance) =>
    <String, dynamic>{
      'nodeId': instance.nodeId,
      'properties': instance.properties,
    };
