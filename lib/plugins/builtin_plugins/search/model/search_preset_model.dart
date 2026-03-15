import 'package:json_annotation/json_annotation.dart';

part 'search_preset_model.g.dart';

/// 搜索预设模型
@JsonSerializable()
class SearchPreset {
  const SearchPreset({
    required this.id,
    required this.name,
    this.titleQuery,
    this.contentQuery,
    this.tags,
    required this.createdAt,
    this.lastUsed,
  });

  /// 从JSON创建
  factory SearchPreset.fromJson(Map<String, dynamic> json) =>
      _$SearchPresetFromJson(json);

  /// 唯一标识符
  final String id;

  /// 预设名称
  final String name;

  /// 标题查询
  final String? titleQuery;

  /// 内容查询
  final String? contentQuery;

  /// 标签列表
  final List<String>? tags;

  /// 创建时间
  final DateTime createdAt;

  /// 最后使用时间
  final DateTime? lastUsed;

  /// 转换为JSON
  Map<String, dynamic> toJson() => _$SearchPresetToJson(this);

  /// 复制并更新部分字段
  SearchPreset copyWith({
    String? id,
    String? name,
    String? titleQuery,
    String? contentQuery,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return SearchPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      titleQuery: titleQuery ?? this.titleQuery,
      contentQuery: contentQuery ?? this.contentQuery,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchPreset &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SearchPreset(id: $id, name: $name)';
}
