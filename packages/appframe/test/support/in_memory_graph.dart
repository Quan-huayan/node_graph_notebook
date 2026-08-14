/// 测试夹具：内存图 + Node（appframe 测试用）。
library;

import 'package:core_data/core_data.dart';

class InMemoryGraph implements Graph {
  final Map<String, Node> _nodes = <String, Node>{};

  @override
  Node? get(String id) => _nodes[id];

  @override
  List<Node> getMany(List<String> ids) =>
      ids.map((id) => _nodes[id]).whereType<Node>().toList();

  @override
  void save(Node node) {
    _nodes[node.id] = node;
  }

  @override
  void delete(String id) {
    _nodes.remove(id);
  }

  @override
  List<Node> getAll() => _nodes.values.toList();

  @override
  List<Node> getByMetadata(String key, dynamic value) =>
      _nodes.values.where((n) => n.metadata[key] == value).toList();
}

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
