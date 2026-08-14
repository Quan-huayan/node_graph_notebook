/// StoredNode —— FSTGraph 的可持久化 Node 实现。
///
/// sidecar 序列化单元（architecture.md §6.2）：结构 + 内联内容镜像。
/// content 双写：sidecar 为结构权威（含内容副本，损坏可恢复），
/// 内容文件为用户可编辑镜像（00 §3.2：数据目录是文件树）。
library;

import 'package:core_data/core_data.dart';

/// FSTGraph 的 Node 实现（不可变，含 JSON 往返）。
class StoredNode implements Node {
  /// 全字段构造（存储实现写入时间戳）。
  StoredNode({
    required this.id,
    required this.title,
    this.content,
    this.references = const {},
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从 sidecar JSON 反序列化。
  factory StoredNode.fromJson(Map<String, dynamic> json) {
    final references = <String, String>{
      for (final e
          in (json['references'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: e.value as String,
    };
    final metadata = json['metadata'] as Map<String, dynamic>? ?? const {};
    return StoredNode(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String?,
      references: references,
      metadata: metadata,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  final String id;

  @override
  final String title;

  @override
  final String? content;

  @override
  final Map<String, String> references;

  @override
  final Map<String, dynamic> metadata;

  @override
  final DateTime createdAt;

  @override
  final DateTime updatedAt;

  /// 序列化为 sidecar JSON（architecture.md §6.2 格式）。
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'content': content,
    'references': references,
    'metadata': metadata,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  Node copyWith({
    String? title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) => StoredNode(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    references: references ?? this.references,
    metadata: metadata ?? this.metadata,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
