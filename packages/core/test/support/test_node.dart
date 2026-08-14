/// core 契约测试共享的 Node 实现。
library;

import 'package:core_data/core_data.dart';

class TestNode implements Node {
  TestNode({
    required this.id,
    required this.title,
    this.content,
    this.references = const {},
    this.metadata = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
       updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

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

  @override
  Node copyWith({
    String? title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) => TestNode(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    references: references ?? this.references,
    metadata: metadata ?? this.metadata,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
