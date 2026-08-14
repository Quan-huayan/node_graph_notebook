// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_preset_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchPreset _$SearchPresetFromJson(Map<String, dynamic> json) => SearchPreset(
  id: json['id'] as String,
  name: json['name'] as String,
  titleQuery: json['titleQuery'] as String?,
  contentQuery: json['contentQuery'] as String?,
  tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  lastUsed: json['lastUsed'] == null
      ? null
      : DateTime.parse(json['lastUsed'] as String),
);

Map<String, dynamic> _$SearchPresetToJson(SearchPreset instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'titleQuery': instance.titleQuery,
      'contentQuery': instance.contentQuery,
      'tags': instance.tags,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastUsed': instance.lastUsed?.toIso8601String(),
    };
