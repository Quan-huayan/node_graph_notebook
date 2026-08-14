// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'node.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Node _$NodeFromJson(Map<String, dynamic> json) => Node(
  id: json['id'] as String,
  title: json['title'] as String,
  content: json['content'] as String?,
  references: (json['references'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, NodeReference.fromJson(e as Map<String, dynamic>)),
  ),
  size: const SizeConverter().fromJson(json['size'] as Map<String, dynamic>),
  viewMode: $enumDecode(_$NodeViewModeEnumMap, json['viewMode']),
  color: json['color'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  metadata: json['metadata'] as Map<String, dynamic>,
);

Map<String, dynamic> _$NodeToJson(Node instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'content': instance.content,
  'references': instance.references,
  'size': const SizeConverter().toJson(instance.size),
  'viewMode': _$NodeViewModeEnumMap[instance.viewMode]!,
  'color': instance.color,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'metadata': instance.metadata,
};

const _$NodeViewModeEnumMap = {
  NodeViewMode.titleOnly: 'titleOnly',
  NodeViewMode.titleWithPreview: 'titleWithPreview',
  NodeViewMode.fullContent: 'fullContent',
  NodeViewMode.compact: 'compact',
};
