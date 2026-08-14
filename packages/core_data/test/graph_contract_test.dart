/// Graph 契约测试 ×1（architecture.md §9）。
///
/// 验证 Graph 接口的全部约定行为（02 §1.5）：单点读、批量读、
/// 写（save 整体替换）、删（静默 no-op）、全量、metadata 查询。
/// 夹具 = InMemoryGraph（02 §2.1：测试/未来后端，无文件概念）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_graph.dart';

void main() {
  group('Graph 契约', () {
    late InMemoryGraph graph;

    setUp(() {
      graph = InMemoryGraph();
    });

    test('save → get 往返，get 不存在返回 null', () {
      final node = TestNode(id: 'a', title: '笔记 A');

      graph.save(node);

      expect(graph.get('a'), same(node));
      expect(graph.get('missing'), isNull);
    });

    test('save 整体替换（同 id 覆盖）', () {
      graph.save(TestNode(id: 'a', title: '旧标题'));
      graph.save(TestNode(id: 'a', title: '新标题', content: '正文'));

      final node = graph.get('a');
      expect(node, isNotNull);
      expect(node!.title, '新标题');
      expect(node.content, '正文');
    });

    test('getMany 批量读：缺失 id 静默跳过，不抛', () {
      graph
        ..save(TestNode(id: 'a', title: 'A'))
        ..save(TestNode(id: 'b', title: 'B'));

      final nodes = graph.getMany(<String>['a', 'b', 'missing']);

      expect(nodes.map((n) => n.id), <String>['a', 'b']);
    });

    test('getAll 全量遍历', () {
      graph
        ..save(TestNode(id: 'a', title: 'A'))
        ..save(TestNode(id: 'b', title: 'B'));

      expect(graph.getAll().map((n) => n.id).toSet(), <String>{'a', 'b'});
    });

    test('getByMetadata 键值查询（二级索引语义）', () {
      graph
        ..save(
          TestNode(
            id: 'a',
            title: 'A',
            metadata: const <String, dynamic>{'kind': 'note'},
          ),
        )
        ..save(
          TestNode(
            id: 'b',
            title: 'B',
            metadata: const <String, dynamic>{'kind': 'asset'},
          ),
        );

      final notes = graph.getByMetadata('kind', 'note');

      expect(notes.map((n) => n.id), <String>['a']);
    });

    test('delete 后 get 返回 null；删除不存在节点为静默 no-op', () {
      graph.save(TestNode(id: 'a', title: 'A'));

      graph.delete('a');
      graph.delete('missing'); // 不抛

      expect(graph.get('a'), isNull);
      expect(graph.getAll(), isEmpty);
    });
  });
}
