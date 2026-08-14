import 'dart:ui';

import 'package:json_annotation/json_annotation.dart';

import 'converters.dart';
import 'enums.dart';
import 'node_reference.dart';

part 'node.g.dart';

/// 统一节点模型
/// 所有元素（内容、关系、概念）都使用统一的 Node 模型，
/// 通过 metadata Map 实现类型扩展和语义增强
///
/// ## 设计理念
///
/// Node 是**核心数据模型**，采用组合模式而非继承模式：
/// - 通过 `metadata` Map 存储扩展属性（类型、图标、颜色等）
/// - 通过 `references` Map 存储节点间的关系
/// - 位置信息由 UILayoutService 通过 NodeAttachment 管理
/// - 渲染逻辑由 NodeTemplate 和渲染策略系统提供
///
/// ## 节点类型扩展
///
/// 节点类型通过 metadata 组合模式实现，而非继承：
///
/// ```dart
/// // 创建文件夹节点
/// final folderNode = Node(
///   id: 'folder-1',
///   title: 'My Folder',
///   content: null,
///   references: {},
///   size: Size(200, 80),
///   viewMode: NodeViewMode.compact,
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
///   metadata: {
///     'isFolder': true,
///     'icon': 'folder',
///   },
/// );
///
/// // 创建自定义类型节点
/// final customNode = Node(
///   id: 'custom-1',
///   title: 'Custom Node',
///   content: 'Custom content',
///   references: {},
///   size: Size(200, 100),
///   viewMode: NodeViewMode.compact,
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
///   metadata: {
///     'nodeType': 'custom',
///     'plugin.myPlugin.customField': 'value',
///   },
/// );
/// ```
@JsonSerializable()
class Node {
  /// 创建一个统一节点模型
  ///
  /// [id] - 唯一标识符
  /// [title] - 节点标题
  /// [content] - Markdown 内容（可选）
  /// [references] - 涉及的节点映射（key: 节点ID, value: 引用关系）
  /// [size] - 节点尺寸
  /// [viewMode] - 显示模式
  /// [color] - 颜色
  /// [createdAt] - 创建时间
  /// [updatedAt] - 更新时间
  /// [metadata] - 元数据
  ///
  /// 注意：位置信息由 UILayoutService 通过 NodeAttachment 管理，不存储在 Node 中。
  const Node({
    required this.id,
    required this.title,
    this.content,
    required this.references,
    required this.size,
    required this.viewMode,
    this.color,
    required this.createdAt,
    required this.updatedAt,
    required this.metadata,
  });

  /// 从JSON创建
  factory Node.fromJson(Map<String, dynamic> json) => _$NodeFromJson(json);

  /// 唯一标识符
  final String id;

  /// 节点标题
  final String title;

  /// Markdown 内容（可选）
  final String? content;

  /// 涉及的节点映射（key: 节点ID, value: 引用关系）
  final Map<String, NodeReference> references;

  /// 节点尺寸
  @SizeConverter()
  final Size size;

  /// 显示模式
  final NodeViewMode viewMode;

  /// 颜色
  final String? color;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 元数据
  final Map<String, dynamic> metadata;

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    final json = _$NodeToJson(this);
    // Serialize NodeReference objects in the references map
    json['references'] = references.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    return json;
  }

  /// 便捷方法：是否是文件夹
  bool get isFolder =>
      metadata['isFolder'] == true ||
      (metadata['isFolder'] is bool && metadata['isFolder'] as bool);

  /// 获取所有引用的节点ID
  List<String> get referencedNodeIds => references.keys.toList();

  /// 获取特定类型的引用
  List<NodeReference> getReferencesByType(String type) => references.values.where((r) => r.type == type).toList();

  /// 复制并更新部分字段
  Node copyWith({
    String? id,
    String? title,
    String? content,
    Map<String, NodeReference>? references,
    Size? size,
    NodeViewMode? viewMode,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) => Node(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      references: references ?? this.references,
      size: size ?? this.size,
      viewMode: viewMode ?? this.viewMode,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );

  /// 添加引用
  ///
  /// [nodeId] - 引用的节点ID
  /// [reference] - 引用关系
  Node addReference(String nodeId, NodeReference reference) {
    final newReferences = Map<String, NodeReference>.from(references);
    newReferences[nodeId] = reference;
    return copyWith(references: newReferences);
  }

  /// 移除引用
  ///
  /// [nodeId] - 要移除的引用节点ID
  Node removeReference(String nodeId) {
    final newReferences = Map<String, NodeReference>.from(references)
    ..remove(nodeId);
    return copyWith(references: newReferences);
  }

  /// 更新时间戳
  Node updateTimestamp() => copyWith(updatedAt: DateTime.now());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Node &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          content == other.content &&
          _mapEquals(references, other.references) &&
          size == other.size &&
          viewMode == other.viewMode &&
          color == other.color &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          _mapEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    content,
    size,
    viewMode,
    color,
    createdAt,
    updatedAt,
    _mapHashCode(metadata),
    _mapHashCode(references),
  );

  @override
  String toString() =>
      'Node(id: $id, title: $title, refs: ${references.length})';

  /// 辅助方法：比较两个 Map 是否相等
  bool _mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  /// 辅助方法：计算 Map 的稳定 hashCode
  int _mapHashCode<K, V>(Map<K, V> map) => Object.hashAllUnordered(
      map.entries.map((e) => Object.hash(e.key, e.value)),
    );
}
