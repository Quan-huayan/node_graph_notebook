/// WindowedUIManager 契约测试（architecture.md §5.1 物化 / §5.2 失效广播 /
/// §5.4 降级）。
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_graph.dart';
import 'support/recording.dart';

/// 全部节点命中的归属集。
ConceptRegistry _registry(Iterable<Concept> concepts) =>
    StaticConceptRegistry(concepts: concepts);

WindowedUIManager _manager({
  required InMemoryGraph graph,
  required ConceptRegistry concepts,
  required ViewportQuery query,
  TestRenderContext? renderRoot,
}) {
  final index = HookIndex();
  final window = WindowManagerImpl();
  return WindowedUIManager(
    graph: graph,
    concepts: concepts,
    index: index,
    window: window,
    materializer: MaterializerImpl(
      graph: graph,
      concepts: concepts,
      window: window,
      index: index,
      renderRoot: renderRoot ?? TestRenderContext(),
    ),
    query: query,
  );
}

void main() {
  group('§5.1 视口物化', () {
    test('视口变化 → 视口内未物化节点物化（索引/窗口登记 + render）', () {
      final graph = InMemoryGraph()
        ..save(TestNode(id: 'a', title: 'A'))
        ..save(TestNode(id: 'b', title: 'B'));
      final concept = RecordingConcept(
        id: 'note',
        matchNodeIds: const {'a', 'b'},
      );
      final manager = _manager(
        graph: graph,
        concepts: _registry(<Concept>[concept]),
        query: FixedViewportQuery(const <String>['a', 'b']),
      );

      manager.onViewportChanged(
        const ValueRect(x: 0, y: 0, width: 100, height: 100),
      );

      expect(concept.created.map((c) => c.nodeId).toSet(), <String>{'a', 'b'});
      expect(concept.created.every((c) => c.hook.rendered), isTrue);
      expect(manager.window.isMaterialized('a'), isTrue);
      expect(manager.window.isMaterialized('b'), isTrue);
    });

    test('已物化节点跳过（不重复物化）', () {
      final graph = InMemoryGraph()..save(TestNode(id: 'a', title: 'A'));
      final concept = RecordingConcept(id: 'note', matchNodeIds: const {'a'});
      final manager = _manager(
        graph: graph,
        concepts: _registry(<Concept>[concept]),
        query: FixedViewportQuery(const <String>['a']),
      );

      manager.onViewportChanged(
        const ValueRect(x: 0, y: 0, width: 10, height: 10),
      );
      manager.onViewportChanged(
        const ValueRect(x: 0, y: 0, width: 10, height: 10),
      );

      expect(concept.created, hasLength(1));
    });

    test('materializeRoot 物化根容器（kind 追溯链）', () {
      final graph = InMemoryGraph()
        ..save(
          TestNode(id: 'root', title: '根', references: const {'child': 'a'}),
        )
        ..save(TestNode(id: 'a', title: 'A'));
      final concept = RecordingConcept(
        id: 'folder',
        matchNodeIds: const {'root', 'a'},
      );
      final manager = _manager(
        graph: graph,
        concepts: _registry(<Concept>[concept]),
        query: FixedViewportQuery(const <String>[]),
      );

      final rootHook = manager.materializeRoot('root', kind: 'graph');

      expect(rootHook, isNotNull);
      // 子 Hook 递归物化（00 推论 3：references 推导重建）。
      expect(concept.created.map((c) => c.nodeId).toSet(), <String>{
        'root',
        'a',
      });
      expect(manager.window.kindOf('a@graph'), 'graph');
    });
  });

  group('§5.2 失效广播', () {
    test('data 变更 → 只通知已物化 Hook（reload + dirty），未物化无成本', () {
      final graph = InMemoryGraph()
        ..save(TestNode(id: 'a', title: 'A'))
        ..save(TestNode(id: 'b', title: 'B'));
      final concept = RecordingConcept(id: 'note', matchNodeIds: const {'a'});
      final manager = _manager(
        graph: graph,
        concepts: _registry(<Concept>[concept]),
        query: FixedViewportQuery(const <String>['a']),
      );
      manager.onViewportChanged(
        const ValueRect(x: 0, y: 0, width: 10, height: 10),
      );

      manager.onWriteResult(
        const _Result(affected: <String>{'a', 'b'}, kind: ChangeKind.data),
      );

      final hookA = concept.created.single.hook;
      expect(hookA.reloadCount, 1);
      expect(hookA.dirty, isTrue);
      // b 未物化：lookup 为空，无 Hook 被通知（02 §3.4：无渲染成本）。
      expect(concept.created, hasLength(1));
    });

    test('structure 变更 → 受影响节点 Hook 回收（树重挂）', () {
      final graph = InMemoryGraph()..save(TestNode(id: 'a', title: 'A'));
      final concept = RecordingConcept(id: 'note', matchNodeIds: const {'a'});
      final manager = _manager(
        graph: graph,
        concepts: _registry(<Concept>[concept]),
        query: FixedViewportQuery(const <String>['a']),
      );
      manager.onViewportChanged(
        const ValueRect(x: 0, y: 0, width: 10, height: 10),
      );

      manager.onWriteResult(
        const _Result(affected: <String>{'a'}, kind: ChangeKind.structure),
      );

      expect(manager.window.isMaterialized('a'), isFalse);
    });

    test('ui 变更 → 无失效动作（外观直写）', () {
      final graph = InMemoryGraph()..save(TestNode(id: 'a', title: 'A'));
      final concept = RecordingConcept(id: 'note', matchNodeIds: const {'a'});
      final manager = _manager(
        graph: graph,
        concepts: _registry(<Concept>[concept]),
        query: FixedViewportQuery(const <String>['a']),
      );
      manager.onViewportChanged(
        const ValueRect(x: 0, y: 0, width: 10, height: 10),
      );

      manager.onWriteResult(
        const _Result(affected: <String>{'a'}, kind: ChangeKind.ui),
      );

      expect(concept.created.single.hook.reloadCount, 0);
      expect(concept.created.single.hook.dirty, isFalse);
    });
  });

  group('§5.4 降级渲染', () {
    test('onConceptsChanged → 已物化 Hook 回收后重新物化（不空洞）', () {
      final graph = InMemoryGraph()..save(TestNode(id: 'a', title: 'A'));
      final note = RecordingConcept(id: 'note', matchNodeIds: const {'a'});
      final manager = _manager(
        graph: graph,
        concepts: _registry(<Concept>[note]),
        query: FixedViewportQuery(const <String>['a']),
      );
      manager.onViewportChanged(
        const ValueRect(x: 0, y: 0, width: 10, height: 10),
      );
      final before = note.created.length; // 物化 1 个 Hook。

      manager.onConceptsChanged();

      // 重新物化：新 Hook 实例（Concept 变化后 findFor 重新判定）。
      expect(note.created.length, before + 1);
      expect(manager.window.isMaterialized('a'), isTrue);
    });

    test('无匹配 Concept 时 findFor 永不返回 null（兜底保证）', () {
      final graph = InMemoryGraph()..save(TestNode(id: 'a', title: 'A'));
      final manager = _manager(
        graph: graph,
        concepts: _registry(const <Concept>[]),
        query: FixedViewportQuery(const <String>['a']),
      );

      final hook = manager.materialize('a', null, 'graph');

      expect(hook, isNotNull);
      expect(
        manager.concepts.findFor(graph.get('a')!),
        same(manager.concepts.fallback),
      );
    });
  });

  group('M7.1 hookFor / materializeIfAbsent（呈现层渲染宿主）', () {
    test('hookFor：已物化返回实例；未物化/无 kind 匹配返回 null', () {
      final graph = InMemoryGraph()..save(TestNode(id: 'a', title: 'A'));
      final concept = RecordingConcept(id: 'note', matchNodeIds: const {'a'});
      final manager = _manager(
        graph: graph,
        concepts: _registry(<Concept>[concept]),
        query: FixedViewportQuery(const <String>[]),
      );
      manager.materialize('a', null, 'sidebar');

      expect(
        manager.hookFor('a', 'sidebar'),
        same(concept.created.single.hook),
      );
      expect(manager.hookFor('a', 'graph'), isNull); // kind 不匹配。
      expect(manager.hookFor('missing', 'sidebar'), isNull); // 未物化。
    });

    test('hookFor：同节点多容器多 kind 区分（sidebar 行 + graph 卡片）', () {
      final graph = InMemoryGraph()..save(TestNode(id: 'a', title: 'A'));
      final concept = RecordingConcept(id: 'note', matchNodeIds: const {'a'});
      final manager = _manager(
        graph: graph,
        concepts: _registry(<Concept>[concept]),
        query: FixedViewportQuery(const <String>[]),
      );
      manager.materialize('a', null, 'sidebar');
      manager.materialize('a', null, 'graph');

      expect(concept.created, hasLength(2));
      expect(manager.hookFor('a', 'sidebar')!.hookId, 'a@sidebar');
      expect(manager.hookFor('a', 'graph')!.hookId, 'a@graph');
    });

    test('materializeIfAbsent：已物化幂等；kind 不同按需新物化', () {
      final graph = InMemoryGraph()
        ..save(
          TestNode(id: 'root', title: '根', references: const {'child': 'a'}),
        )
        ..save(TestNode(id: 'a', title: 'A'));
      final concept = RecordingConcept(
        id: 'folder',
        matchNodeIds: const {'root', 'a'},
      );
      final manager = _manager(
        graph: graph,
        concepts: _registry(<Concept>[concept]),
        query: FixedViewportQuery(const <String>[]),
      );
      manager.materializeRoot('root', kind: 'sidebar'); // root + a 递归物化。

      final before = concept.created.length;
      manager.materializeIfAbsent('a', 'sidebar'); // 已物化 → no-op。
      expect(concept.created.length, before);
      manager.materializeIfAbsent('a', 'graph'); // kind 不同 → 新物化。
      expect(concept.created.length, before + 1);
      expect(manager.hookFor('a', 'graph'), isNotNull);
    });

    test('recycle：回收后 hookFor 为 null；非物化回收静默 no-op', () {
      final graph = InMemoryGraph()..save(TestNode(id: 'a', title: 'A'));
      final concept = RecordingConcept(id: 'note', matchNodeIds: const {'a'});
      final manager = _manager(
        graph: graph,
        concepts: _registry(<Concept>[concept]),
        query: FixedViewportQuery(const <String>[]),
      );
      manager.materialize('a', null, 'graph');

      manager.recycle('a@graph');

      expect(manager.hookFor('a', 'graph'), isNull);
      expect(manager.window.isMaterialized('a'), isFalse);
      expect(() => manager.recycle('a@graph'), returnsNormally); // 静默 no-op。
    });
  });

  group('M7.1 失效事件（呈现层定向重建）', () {
    test('data 写 → 事件载荷（changeKind + 受影响节点）', () {
      final graph = InMemoryGraph()..save(TestNode(id: 'a', title: 'A'));
      final concept = RecordingConcept(id: 'note', matchNodeIds: const {'a'});
      final manager = _manager(
        graph: graph,
        concepts: _registry(<Concept>[concept]),
        query: FixedViewportQuery(const <String>[]),
      );
      final events = <InvalidationEvent>[];
      manager.addListener(events.add);

      manager.onWriteResult(
        const _Result(affected: <String>{'a', 'b'}, kind: ChangeKind.data),
      );

      expect(events, hasLength(1));
      expect(events.single.changeKind, ChangeKind.data);
      expect(events.single.nodeIds, <String>{'a', 'b'});
    });

    test('structure 写 → 树重挂 + 事件（载荷 changeKind=structure）', () {
      final graph = InMemoryGraph()..save(TestNode(id: 'a', title: 'A'));
      final concept = RecordingConcept(id: 'note', matchNodeIds: const {'a'});
      final manager = _manager(
        graph: graph,
        concepts: _registry(<Concept>[concept]),
        query: FixedViewportQuery(const <String>['a']),
      );
      manager.onViewportChanged(
        const ValueRect(x: 0, y: 0, width: 10, height: 10),
      );
      final events = <InvalidationEvent>[];
      manager.addListener(events.add);

      manager.onWriteResult(
        const _Result(affected: <String>{'a'}, kind: ChangeKind.structure),
      );

      expect(events, hasLength(1));
      expect(events.single.changeKind, ChangeKind.structure);
      expect(events.single.nodeIds, <String>{'a'});
      // 树重挂仍生效（回收 → hookFor 为空 → 呈现层重新物化）。
      expect(manager.hookFor('a', 'graph'), isNull);
    });

    test('ui 写 → 不发事件（外观直写，无数据失效）', () {
      final graph = InMemoryGraph()..save(TestNode(id: 'a', title: 'A'));
      final concept = RecordingConcept(id: 'note', matchNodeIds: const {'a'});
      final manager = _manager(
        graph: graph,
        concepts: _registry(<Concept>[concept]),
        query: FixedViewportQuery(const <String>[]),
      );
      final events = <InvalidationEvent>[];
      manager.addListener(events.add);

      manager.onWriteResult(
        const _Result(affected: <String>{'a'}, kind: ChangeKind.ui),
      );

      expect(events, isEmpty);
    });

    test('removeListener 后不再收到事件', () {
      final graph = InMemoryGraph()..save(TestNode(id: 'a', title: 'A'));
      final concept = RecordingConcept(id: 'note', matchNodeIds: const {'a'});
      final manager = _manager(
        graph: graph,
        concepts: _registry(<Concept>[concept]),
        query: FixedViewportQuery(const <String>[]),
      );
      final events = <InvalidationEvent>[];
      manager.addListener(events.add);
      manager.removeListener(events.add);

      manager.onWriteResult(
        const _Result(affected: <String>{'a'}, kind: ChangeKind.data),
      );

      expect(events, isEmpty);
    });
  });
}

class _Result implements WriteResult {
  const _Result({required this.affected, required this.kind});

  final Set<String> affected;
  final ChangeKind kind;

  @override
  Set<String> get affectedNodeIds => affected;

  @override
  ChangeKind get changeKind => kind;

  @override
  Command? get inverse => null;
}
