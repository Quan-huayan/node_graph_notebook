// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'metadata_index.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PositionInfo _$PositionInfoFromJson(Map<String, dynamic> json) => PositionInfo(
  dx: (json['dx'] as num).toDouble(),
  dy: (json['dy'] as num).toDouble(),
);

Map<String, dynamic> _$PositionInfoToJson(PositionInfo instance) =>
    <String, dynamic>{'dx': instance.dx, 'dy': instance.dy};

SizeInfo _$SizeInfoFromJson(Map<String, dynamic> json) => SizeInfo(
  width: (json['width'] as num).toDouble(),
  height: (json['height'] as num).toDouble(),
);

Map<String, dynamic> _$SizeInfoToJson(SizeInfo instance) => <String, dynamic>{
  'width': instance.width,
  'height': instance.height,
};

NodeMetadata _$NodeMetadataFromJson(Map<String, dynamic> json) => NodeMetadata(
  id: json['id'] as String,
  title: json['title'] as String,
  size: SizeInfo.fromJson(json['size'] as Map<String, dynamic>),
  filePath: json['filePath'] as String,
  referencedNodeIds: (json['referencedNodeIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$NodeMetadataToJson(NodeMetadata instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'size': instance.size,
      'filePath': instance.filePath,
      'referencedNodeIds': instance.referencedNodeIds,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

MetadataIndex _$MetadataIndexFromJson(Map<String, dynamic> json) =>
    MetadataIndex(
      nodes: (json['nodes'] as List<dynamic>)
          .map((e) => NodeMetadata.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );

Map<String, dynamic> _$MetadataIndexToJson(MetadataIndex instance) =>
    <String, dynamic>{
      'nodes': instance.nodes,
      'lastUpdated': instance.lastUpdated.toIso8601String(),
    };
