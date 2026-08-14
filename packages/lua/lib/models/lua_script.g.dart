// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lua_script.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LuaScript _$LuaScriptFromJson(Map<String, dynamic> json) => LuaScript(
  id: json['id'] as String,
  name: json['name'] as String,
  content: json['content'] as String,
  enabled: json['enabled'] as bool,
  description: json['description'] as String?,
  author: json['author'] as String?,
  version: json['version'] as String?,
  lastExecutedAt: json['lastExecutedAt'] == null
      ? null
      : DateTime.parse(json['lastExecutedAt'] as String),
  executionCount: (json['executionCount'] as num?)?.toInt() ?? 0,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$LuaScriptToJson(LuaScript instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'content': instance.content,
  'enabled': instance.enabled,
  'description': instance.description,
  'author': instance.author,
  'version': instance.version,
  'lastExecutedAt': instance.lastExecutedAt?.toIso8601String(),
  'executionCount': instance.executionCount,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
