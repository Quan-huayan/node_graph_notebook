/// 拖拽环防护测试（M7.2：运行时卡死修复——拖进自己 = 自引用环拒绝；
/// 环图 isDescendant 有 visited 剪枝不无限递归）。
library;

import 'package:appframe/appframe.dart'; // StoredNode。
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_folder/node_folder.dart';

void main() {
  group('isDescendant（环防护）', () {
    test('拖进自己 = 逻辑环（拒绝）', () {
      final graph = InMemoryGraphTest();
      graph.save(TestNodeFolder('f1'));
      // f1 无子级：isDescendant(f1, f1) 也必须为 true（自引用环）。
      expect(isDescendant(graph, 'f1', 'f1'), isTrue);
    });

    test('环图（f1↔f2）visited 剪枝终止，不无限递归', () {
      final graph = InMemoryGraphTest()
        ..save(TestNodeFolder('f1'))
        ..save(TestNodeFolder('f2'))
        ..save(TestNodeContain('c1', parent: 'f1', child: 'f2'))
        ..save(TestNodeContain('c2', parent: 'f2', child: 'f1'));
      // 环图上检查任意目标：终止且不抛（异常数据兜底）。
      expect(isDescendant(graph, 'f1', 'root'), isFalse);
      expect(isDescendant(graph, 'f1', 'f2'), isTrue); // f1 的后代含 f2。
    });

    test('正常后代链', () {
      final graph = InMemoryGraphTest()
        ..save(TestNodeFolder('f1'))
        ..save(TestNodeFolder('f2'))
        ..save(TestNodeContain('c1', parent: 'f1', child: 'f2'));
      expect(isDescendant(graph, 'f1', 'f2'), isTrue);
      expect(isDescendant(graph, 'f2', 'f1'), isFalse);
    });
  });

  test('MoveNodesHandler：childId == containerId → CycleError', () async {
    final graph = InMemoryGraphTest()..save(TestNodeFolder('f1'));
    final handler = MoveNodesHandler(graphProvider: () => graph);
    await expectLater(
      handler.handle(const MoveNodesCommand(containerId: 'f1', childId: 'f1')),
      throwsA(isA<CycleError>()),
    );
  });
}

/// 测试图（内存）。
class InMemoryGraphTest implements Graph {
  final Map<String, Node> _nodes = <String, Node>{};

  @override
  void save(Node node) => _nodes[node.id] = node;

  @override
  Node? get(String id) => _nodes[id];

  @override
  List<Node> getMany(List<String> ids) => [
    for (final id in ids)
      if (_nodes[id] != null) _nodes[id]!,
  ];

  @override
  List<Node> getAll() => _nodes.values.toList();

  @override
  bool delete(String id) => _nodes.remove(id) != null;

  @override
  List<Node> getByMetadata(String key, dynamic value) =>
      _nodes.values.where((n) => n.metadata[key] == value).toList();
}

Node TestNodeFolder(String id) => StoredNode(
  id: id,
  title: id,
  metadata: const <String, dynamic>{'kind': 'folder'},
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

Node TestNodeContain(
  String id, {
  required String parent,
  required String child,
}) => StoredNode(
  id: id,
  title: id,
  references: <String, String>{'parent': parent, 'child': child},
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);
