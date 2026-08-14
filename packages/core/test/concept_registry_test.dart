/// ConceptRegistry.findFor 优先序契约测试 ×3（architecture.md §9）：
/// 特异性 / 平局（注册序）/ 兜底（永不空洞）。
///
/// 对应 02 §1.3 匹配优先序与 00 不变量 4.3：全序优先序 + 纯结构匹配
/// ⇒ 结构确定性与插件加载顺序无关、与 UIStateStore 无关。
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// 可配置测试 Concept：按 nodeId 集合决定 validate 命中。
class _TestConcept extends Concept {
  _TestConcept({
    required this.id,
    this.requiredSlots = const {},
    this.metadataSchema = const {},
    this.matchNodeIds = const {},
  });

  @override
  final String id;

  @override
  String get name => id;

  @override
  String get description => '测试 Concept $id';

  @override
  final Set<String> requiredSlots;

  @override
  Set<String> get requiredMetadataKeys => const {};

  @override
  final Map<String, MetadataField> metadataSchema;

  final Set<String> matchNodeIds;

  @override
  Set<String> get slots => requiredSlots;

  @override
  ContentRequirement get contentRequirement => ContentRequirement.optional;

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
    throw UnimplementedError('契约测试不创建 Hook');
  }
}

Node _node(String id) => _TestNode(id: id);

class _TestNode implements Node {
  const _TestNode({required this.id});

  @override
  final String id;

  @override
  String get title => '节点 $id';

  @override
  String? get content => null;

  @override
  Map<String, String> get references => const {};

  @override
  Map<String, dynamic> get metadata => const {};

  @override
  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Node copyWith({
    String? title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) => this;
}

void main() {
  group('findFor 匹配优先序（02 §1.3）', () {
    test('特异性：required 约束多者胜', () {
      final generic = _TestConcept(
        id: 'generic',
        requiredSlots: const {},
        matchNodeIds: const {'n1'},
      );
      final specific = _TestConcept(
        id: 'specific',
        requiredSlots: const {'folder', 'parent'},
        matchNodeIds: const {'n1'},
      );
      final registry = StaticConceptRegistry(
        concepts: <Concept>[generic, specific],
      );

      expect(registry.findFor(_node('n1')).id, 'specific');
    });

    test('平局：注册序先注册者胜', () {
      final first = _TestConcept(
        id: 'first',
        requiredSlots: const {'a'},
        matchNodeIds: const {'n1'},
      );
      final second = _TestConcept(
        id: 'second',
        requiredSlots: const {'b'},
        matchNodeIds: const {'n1'},
      );
      final registry = StaticConceptRegistry(
        concepts: <Concept>[first, second],
      );

      expect(registry.findFor(_node('n1')).id, 'first');
    });

    test('无命中 → 兜底 Concept，永不空洞', () {
      final registry = StaticConceptRegistry(
        concepts: <Concept>[
          _TestConcept(id: 'strict', matchNodeIds: const <String>{}),
        ],
      );

      expect(registry.findFor(_node('unknown')), same(registry.fallback));
      expect(registry.findFor(_node('unknown')).id, fallbackConceptId);
    });

    test('显式注入兜底生效', () {
      final customFallback = _TestConcept(id: 'custom-fallback');
      final registry = StaticConceptRegistry(
        concepts: <Concept>[],
        fallback: customFallback,
      );

      expect(registry.findFor(_node('any')), same(customFallback));
    });

    test('findByMetadata 返回声明了该键的 Concept（注册序）', () {
      final withKey = _TestConcept(
        id: 'withKey',
        matchNodeIds: const {'n1'},
        metadataSchema: const <String, MetadataField>{
          'tags': MetadataField(name: 'tags', type: MetadataType.list),
        },
      );
      final withoutKey = _TestConcept(id: 'withoutKey');

      final registry = StaticConceptRegistry(
        concepts: <Concept>[withKey, withoutKey],
      );

      expect(registry.findByMetadata('tags', null).map((c) => c.id), <String>[
        'withKey',
      ]);
    });
  });
}
