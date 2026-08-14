/// AcyclicChecker 契约测试 ×3（architecture.md §9）：
/// 直接环 / 传递环 / 无环。
///
/// 对应 00 §2.3 环策略（v1 禁止环）与 02 §1.4：
/// 执行点在 Handler 落盘前，受影响子图增量 acyclicity，O(受影响区域)。
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_node.dart';

void main() {
  group('AcyclicChecker（00 §2.3）', () {
    test('直接环：新边 A→B 撞上已有边 B→A', () {
      final graph = _InMemoryGraph()
        ..save(TestNode(id: 'a', title: 'A', references: const {}))
        ..save(
          TestNode(id: 'b', title: 'B', references: const {'parent': 'a'}),
        );

      // 把 A 拖入 B 的后代（B 引用 A，再把 A 挂到 B 下）。
      final cycle = const AcyclicChecker().check(
        affectedRefs: const <String, Set<String>>{
          'a': <String>{'b'},
        },
        graph: graph,
      );

      expect(cycle, isNotNull);
      expect(cycle!.first, 'a');
      expect(cycle.last, 'a');
    });

    test('传递环：新边 A→B 撞上传递路径 B→…→A', () {
      final graph = _InMemoryGraph()
        ..save(TestNode(id: 'a', title: 'A'))
        ..save(TestNode(id: 'b', title: 'B'))
        ..save(TestNode(id: 'c', title: 'C', references: const {'parent': 'b'}))
        ..save(TestNode(id: 'd', title: 'D', references: const {'parent': 'c'}))
        ..save(
          TestNode(id: 'e', title: 'E', references: const {'parent': 'd'}),
        );

      // e 的后代链 d→c→b；把 b 拖入 e 的后代 → b→e→d→c→b 传递环。
      final cycle = const AcyclicChecker().check(
        affectedRefs: const <String, Set<String>>{
          'b': <String>{'e'},
        },
        graph: graph,
      );

      expect(cycle, isNotNull);
      expect(cycle!.first, 'b');
      expect(cycle.last, 'b');
    });

    test('无环：新边不形成环 → null', () {
      final graph = _InMemoryGraph()
        ..save(TestNode(id: 'a', title: 'A'))
        ..save(TestNode(id: 'b', title: 'B'))
        ..save(TestNode(id: 'c', title: 'C'));

      final cycle = const AcyclicChecker().check(
        affectedRefs: const <String, Set<String>>{
          'a': <String>{'b'},
        },
        graph: graph,
      );

      expect(cycle, isNull);
    });

    test('自引用：A→A 立即成环', () {
      final graph = _InMemoryGraph()..save(TestNode(id: 'a', title: 'A'));

      final cycle = const AcyclicChecker().check(
        affectedRefs: const <String, Set<String>>{
          'a': <String>{'a'},
        },
        graph: graph,
      );

      expect(cycle, isNotNull);
      expect(cycle, <String>['a', 'a']);
    });

    test('单节点多引用边同时变更（重排场景）', () {
      final graph = _InMemoryGraph()
        ..save(TestNode(id: 'a', title: 'A'))
        ..save(TestNode(id: 'b', title: 'B', references: const {'parent': 'a'}))
        ..save(TestNode(id: 'c', title: 'C'));

      // a 同时挂到 b 和 c 下：b→a 已有边 → 环。
      final cycle = const AcyclicChecker().check(
        affectedRefs: const <String, Set<String>>{
          'a': <String>{'b', 'c'},
        },
        graph: graph,
      );

      expect(cycle, isNotNull);
    });

    test('不相关节点不受影响（增量性：只看受影响子图）', () {
      final graph = _InMemoryGraph()
        ..save(TestNode(id: 'a', title: 'A'))
        ..save(TestNode(id: 'b', title: 'B'))
        ..save(
          TestNode(
            id: 'x',
            title: 'X',
            references: const {
              'parent': 'x', // 无关节点中的既有结构不被波及
            },
          ),
        );

      final cycle = const AcyclicChecker().check(
        affectedRefs: const <String, Set<String>>{
          'a': <String>{'b'},
        },
        graph: graph,
      );

      expect(cycle, isNull);
    });
  });
}

/// 测试夹具：内存图（契约测试用，非共享夹具——保持独立）。
class _InMemoryGraph implements Graph {
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
