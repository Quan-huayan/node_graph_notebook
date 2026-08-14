/// 兜底 Concept（00 不变量 4.3-3）：内置通用 schema，渲染为普通笔记。
///
/// 永不空洞、永不崩溃——任何无 schema 命中的 Node 都由此兜底呈现。
/// findFor 的"无命中 → 兜底"由 ConceptRegistry 注入本类保证（02 §1.3）。
library;

import 'package:core_data/core_data.dart';

/// 兜底 Concept 的固定 id（全序平局规则下兜底永不参与竞争——
/// 它只在全部 validate() 无命中时被返回）。
const String fallbackConceptId = 'core:fallback';

/// 兜底 Concept：接受一切 Node（validate 恒真），渲染为普通笔记。
class FallbackConcept extends Concept {
  /// 无状态兜底（可全局共享）。
  const FallbackConcept();

  @override
  String get id => fallbackConceptId;

  @override
  String get name => 'Fallback';

  @override
  String get description => '内置通用 schema：无匹配 Concept 时渲染为普通笔记';

  @override
  Set<String> get slots => const {};

  @override
  Set<String> get requiredSlots => const {};

  @override
  Map<String, MetadataField> get metadataSchema => const {};

  @override
  Set<String> get requiredMetadataKeys => const {};

  @override
  ContentRequirement get contentRequirement => ContentRequirement.optional;

  /// 恒真——兜底接受一切 Node（00 不变量 4.3-3）。
  @override
  bool validate(Node node) => true;

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) => FallbackNode(
    id: id,
    title: title,
    content: content,
    references: references ?? const {},
    metadata: metadata ?? const {},
  );

  @override
  Hook createHook(Node instance, HookContext context) => FallbackHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
  );
}

/// 兜底 Node 实现（普通笔记：无结构约束、内容可选）。
class FallbackNode extends Node {
  /// 普通笔记实例；时间戳缺省为纪元起点（真实时间由存储写入）。
  FallbackNode({
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
  }) => FallbackNode(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    references: references ?? this.references,
    metadata: metadata ?? this.metadata,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

/// 兜底 Hook：普通笔记视图面（M1 占位实现——真正渲染归 M3 呈现层）。
class FallbackHook extends Hook {
  /// 占位视图面；hookId 由物化者传入（同一 Node 多容器不碰撞）。
  const FallbackHook({required this.nodeId, required this.hookId});

  @override
  final String nodeId;

  @override
  final String hookId;

  @override
  Map<String, Hook> get references => const {};

  /// M3 呈现层实现：渲染为普通笔记。
  @override
  void render(RenderContext context) {}
}
