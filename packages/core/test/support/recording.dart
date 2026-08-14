/// 契约测试夹具：可记录的 Concept / Hook / RenderContext / ViewportQuery。
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

/// 按 nodeId 集合命中的测试 Concept（记录 createHook 调用）。
class RecordingConcept extends Concept {
  RecordingConcept({
    required this.id,
    this.matchNodeIds = const {},
    this.contentRequirement = ContentRequirement.optional,
  });

  final String id;
  final Set<String> matchNodeIds;
  final ContentRequirement contentRequirement;

  final List<_RecordedCreate> created = <_RecordedCreate>[];

  @override
  String get name => id;

  @override
  String get description => '测试 Concept $id';

  @override
  Set<String> get slots => const {};

  @override
  Set<String> get requiredSlots => const {};

  @override
  Map<String, MetadataField> get metadataSchema => const {};

  @override
  Set<String> get requiredMetadataKeys => const {};

  @override
  bool validate(Node node) => matchNodeIds.contains(node.id);

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('契约测试不创建实例');
  }

  @override
  Hook createHook(Node instance, HookContext context) {
    final hook = RecordingHook(nodeId: instance.id, kind: context.kind);
    created.add(_RecordedCreate(instance.id, context.kind, hook));
    return hook;
  }
}

class _RecordedCreate {
  const _RecordedCreate(this.nodeId, this.kind, this.hook);

  final String nodeId;
  final String kind;
  final RecordingHook hook;
}

/// 记录 render/reload/markDirty 调用的测试 Hook。
class RecordingHook extends Hook {
  RecordingHook({required this.nodeId, required this.kind});

  @override
  final String nodeId;

  final String kind;

  bool rendered = false;
  int reloadCount = 0;
  bool dirty = false;
  int renderCount = 0;

  @override
  String get hookId => '$nodeId@$kind';

  @override
  Map<String, Hook> get references => const {};

  @override
  void render(RenderContext context) {
    rendered = true;
    renderCount++;
  }

  @override
  void reloadMetadata() {
    reloadCount++;
  }

  @override
  void markDirty() {
    dirty = true;
  }
}

/// 固定 id 集合的视口查询（契约测试用）。
class FixedViewportQuery implements ViewportQuery {
  FixedViewportQuery(this.ids);

  final Iterable<String> ids;

  @override
  Iterable<String> queryNodes(ValueRect viewport) => ids;
}

/// 记录 render 触达的测试 RenderContext。
class TestRenderContext implements RenderContext {
  final List<Hook> rendered = <Hook>[];

  @override
  RenderContext createChildContext(Hook childHook) {
    final child = TestRenderContext();
    rendered.add(childHook);
    return child;
  }
}
