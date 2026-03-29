import 'dart:ui';

import 'package:json_annotation/json_annotation.dart';

import '../ui_layout/node_attachment.dart' show NodeAttachment;
import '../ui_layout/ui_layout_service.dart' show UILayoutService;
import 'converters.dart';
import 'enums.dart';
import 'node_reference.dart';
import 'node_rendering.dart';

part 'node.g.dart';

/// 统一节点模型
/// 所有元素（内容、关系、概念）都继承自统一的 Node 模型
///
/// ## Design Philosophy (Phase 4 Refactoring)
///
/// Nodes are **autonomous components** that:
/// - Don't store position (managed by UILayoutService)
/// - Provide dual rendering (Flutter Widget + Flame Component)
/// - Maintain state independent of location
/// - Can be attached to any Hook in the layout tree
///
/// ## Positioning
///
/// **DEPRECATED**: The `position` field is deprecated and will be removed in Phase 6.
/// Positions are now managed by [UILayoutService] via [NodeAttachment].
///
/// Use `UILayoutService.attachNode()` to position Nodes:
/// ```dart
/// await layoutService.attachNode(
///   nodeId: node.id,
///   hookId: 'sidebar',
///   position: LocalPosition.absolute(10, 20),
/// );
/// ```
///
/// ## Rendering
///
/// Nodes support dual rendering via [NodeRendering] mixin:
/// - `buildFlutterWidget()` - Render in Flutter context (Sidebar, Toolbar)
/// - `buildFlameComponent()` - Render in Flame context (Graph)
///
/// Mix in [NodeRendering] to add custom rendering:
/// ```dart
/// class MyNode extends Node with NodeRendering {
///   @override
///   Widget buildFlutterWidget(BuildContext context) { ... }
///
///   @override
///   Component buildFlameComponent(GraphWorld world) { ... }
/// }
/// ```
@JsonSerializable()
class Node {
  /// 创建一个统一节点模型
  ///
  /// [id] - 唯一标识符
  /// [title] - 节点标题
  /// [content] - Markdown 内容（可选）
  /// [references] - 涉及的节点映射（key: 节点ID, value: 引用关系）
  /// [position] - 位置坐标
  /// [size] - 节点尺寸
  /// [viewMode] - 显示模式
  /// [color] - 颜色
  /// [createdAt] - 创建时间
  /// [updatedAt] - 更新时间
  /// [metadata] - 元数据
  const Node({
    required this.id,
    required this.title,
    this.content,
    required this.references,
    required this.position,
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

  /// 位置坐标
  ///
  /// **DEPRECATED**: This field is deprecated and will be removed in Phase 6.
  /// Positions are now managed by UILayoutService via NodeAttachment.
  ///
  /// Migration Guide:
  /// ```dart
  /// // OLD (deprecated):
  /// final node = Node(position: Offset(100, 200), ...);
  ///
  /// // NEW (correct):
  /// await layoutService.attachNode(
  ///   nodeId: node.id,
  ///   hookId: 'graph',
  ///   position: LocalPosition.absolute(100, 200),
  /// );
  /// ```
  @Deprecated(
    'Position is now managed by UILayoutService via NodeAttachment. '
    'This field will be removed in Phase 6. '
    'Use layoutService.attachNode() to position Nodes.',
  )
  @OffsetConverter()
  final Offset position;

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
    Offset? position,
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
      position: position ?? this.position,
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
          position == other.position &&
          size == other.size &&
          viewMode == other.viewMode &&
          color == other.color &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          _mapEquals(metadata, other.metadata);

  @override
  int get hashCode => id.hashCode;

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
}
