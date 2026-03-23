import 'package:json_annotation/json_annotation.dart';

part 'lua_script.g.dart';

/// Lua脚本模型
///
/// 表示一个Lua脚本文件及其元数据
@JsonSerializable()
class LuaScript {
  /// 构造函数
  const LuaScript({
    required this.id,
    required this.name,
    required this.content,
    required this.enabled,
    this.description,
    this.author,
    this.version,
    this.lastExecutedAt,
    this.executionCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// 从JSON创建
  factory LuaScript.fromJson(Map<String, dynamic> json) =>
      _$LuaScriptFromJson(json);

  /// 脚本唯一标识符
  final String id;

  /// 脚本名称
  final String name;

  /// 脚本内容
  final String content;

  /// 是否启用
  final bool enabled;

  /// 脚本描述
  final String? description;

  /// 脚本作者
  final String? author;

  /// 脚本版本
  final String? version;

  /// 最后执行时间
  final DateTime? lastExecutedAt;

  /// 执行次数
  final int executionCount;

  /// 创建时间
  final DateTime? createdAt;

  /// 更新时间
  final DateTime? updatedAt;

  /// 转换为JSON
  Map<String, dynamic> toJson() => _$LuaScriptToJson(this);

  /// 复制并更新部分字段
  LuaScript copyWith({
    String? id,
    String? name,
    String? content,
    bool? enabled,
    String? description,
    String? author,
    String? version,
    DateTime? lastExecutedAt,
    int? executionCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LuaScript(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      enabled: enabled ?? this.enabled,
      description: description ?? this.description,
      author: author ?? this.author,
      version: version ?? this.version,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
      executionCount: executionCount ?? this.executionCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 创建执行记录（更新执行时间和次数）
  LuaScript withExecutionRecord() {
    return copyWith(
      lastExecutedAt: DateTime.now(),
      executionCount: executionCount + 1,
    );
  }

  @override
  String toString() {
    return 'LuaScript(id: $id, name: $name, enabled: $enabled, '
        'version: $version, executionCount: $executionCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LuaScript && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
