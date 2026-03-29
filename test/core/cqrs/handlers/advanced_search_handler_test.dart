import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/cqrs/handlers/advanced_search_handler.dart';
import 'package:node_graph_notebook/core/cqrs/queries/advanced_search_query.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';

import 'advanced_search_handler_test.mocks.dart';

@GenerateMocks([NodeRepository])
void main() {
  group('AdvancedSearchQueryHandler', () {
    late AdvancedSearchQueryHandler handler;
    late MockNodeRepository mockRepository;

    setUp(() {
      mockRepository = MockNodeRepository();
      handler = AdvancedSearchQueryHandler(mockRepository);
    });

    Node createTestNode({
      required String id,
      required String title,
      String content = '',
      Map<String, dynamic> metadata = const {},
    }) => Node(
        id: id,
        title: title,
        content: content,
        references: {},
        position: Offset.zero,
        size: const Size(100, 100),
        viewMode: NodeViewMode.titleOnly,
        color: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: metadata,
      );

    test('应该按标题过滤节点', () async {
      // 准备测试数据
      final nodes = [
        createTestNode(id: '1', title: 'Test Node 1', content: 'Content 1'),
        createTestNode(id: '2', title: 'Another Node', content: 'Content 2'),
        createTestNode(id: '3', title: 'Test Node 3', content: 'Content 3'),
      ];

      when(mockRepository.queryAll()).thenAnswer((_) async => nodes);

      // 执行查询
      const query = AdvancedSearchQuery(titleQuery: 'Test');
      final result = await handler.handle(query);

      // 验证结果
      expect(result.isSuccess, true);
      expect(result.data?.length, 2);
      expect(result.data?[0].id, '1');
      expect(result.data?[1].id, '3');
    });

    test('应该按内容过滤节点', () async {
      final nodes = [
        createTestNode(
          id: '1',
          title: 'Node 1',
          content: 'Important content here',
        ),
        createTestNode(
          id: '2',
          title: 'Node 2',
          content: 'Regular content',
        ),
      ];

      when(mockRepository.queryAll()).thenAnswer((_) async => nodes);

      const query = AdvancedSearchQuery(contentQuery: 'Important');
      final result = await handler.handle(query);

      expect(result.isSuccess, true);
      expect(result.data?.length, 1);
      expect(result.data?[0].id, '1');
    });

    test('应该按搜索文本在标题或内容中过滤节点', () async {
      final nodes = [
        createTestNode(
          id: '1',
          title: 'Search Keyword',
          content: 'Content',
        ),
        createTestNode(
          id: '2',
          title: 'Another',
          content: 'search keyword in content',
        ),
        createTestNode(
          id: '3',
          title: 'No Match',
          content: 'No match here',
        ),
      ];

      when(mockRepository.queryAll()).thenAnswer((_) async => nodes);

      const query = AdvancedSearchQuery(searchText: 'search keyword');
      final result = await handler.handle(query);

      expect(result.isSuccess, true);
      expect(result.data?.length, 2);
    });

    test('应该按标签过滤节点', () async {
      final nodes = [
        createTestNode(
          id: '1',
          title: 'Node 1',
          metadata: {'tags': ['important', 'work']},
        ),
        createTestNode(
          id: '2',
          title: 'Node 2',
          metadata: {'tags': ['personal']},
        ),
        createTestNode(
          id: '3',
          title: 'Node 3',
          metadata: {'tags': ['important', 'personal']},
        ),
      ];

      when(mockRepository.queryAll()).thenAnswer((_) async => nodes);

      const query = AdvancedSearchQuery(tags: ['important']);
      final result = await handler.handle(query);

      expect(result.isSuccess, true);
      expect(result.data?.length, 2);
    });

    test('应该按多个标签过滤节点（AND逻辑）', () async {
      final nodes = [
        createTestNode(
          id: '1',
          title: 'Node 1',
          metadata: {'tags': ['important', 'work']},
        ),
        createTestNode(
          id: '2',
          title: 'Node 2',
          metadata: {'tags': ['important']},
        ),
      ];

      when(mockRepository.queryAll()).thenAnswer((_) async => nodes);

      const query = AdvancedSearchQuery(tags: ['important', 'work']);
      final result = await handler.handle(query);

      expect(result.isSuccess, true);
      expect(result.data?.length, 1);
      expect(result.data?[0].id, '1');
    });

    test('应该按文件夹状态过滤节点', () async {
      final nodes = [
        createTestNode(id: '1', title: 'Folder 1', metadata: {'isFolder': true}),
        createTestNode(id: '2', title: 'Node 2', metadata: {'isFolder': false}),
      ];

      when(mockRepository.queryAll()).thenAnswer((_) async => nodes);

      const query = AdvancedSearchQuery(isFolder: true);
      final result = await handler.handle(query);

      expect(result.isSuccess, true);
      expect(result.data?.length, 1);
      expect(result.data?[0].isFolder, true);
    });

    test('应该按创建日期范围过滤节点', () async {
      final now = DateTime.now();
      final nodes = [
        Node(
          id: '1',
          title: 'Node 1',
          content: 'Content',
          references: {},
          position: Offset.zero,
          size: const Size(100, 100),
          viewMode: NodeViewMode.titleOnly,
          createdAt: now.subtract(const Duration(days: 10)),
          updatedAt: now,
          metadata: {},
        ),
        Node(
          id: '2',
          title: 'Node 2',
          content: 'Content',
          references: {},
          position: Offset.zero,
          size: const Size(100, 100),
          viewMode: NodeViewMode.titleOnly,
          createdAt: now.subtract(const Duration(days: 2)),
          updatedAt: now,
          metadata: {},
        ),
        Node(
          id: '3',
          title: 'Node 3',
          content: 'Content',
          references: {},
          position: Offset.zero,
          size: const Size(100, 100),
          viewMode: NodeViewMode.titleOnly,
          createdAt: now.subtract(const Duration(days: 5)),
          updatedAt: now,
          metadata: {},
        ),
      ];

      when(mockRepository.queryAll()).thenAnswer((_) async => nodes);

      final query = AdvancedSearchQuery(
        createdAfter: now.subtract(const Duration(days: 7)),
      );
      final result = await handler.handle(query);

      expect(result.isSuccess, true);
      expect(result.data?.length, 2);
    });

    test('应该对结果应用限制', () async {
      final nodes = List.generate(
        20,
        (i) => createTestNode(
          id: '$i',
          title: 'Node $i',
        ),
      );

      when(mockRepository.queryAll()).thenAnswer((_) async => nodes);

      const query = AdvancedSearchQuery(limit: 5);
      final result = await handler.handle(query);

      expect(result.isSuccess, true);
      expect(result.data?.length, 5);
    });

    test('应该处理空结果', () async {
      final nodes = [
        createTestNode(id: '1', title: 'Node 1'),
      ];

      when(mockRepository.queryAll()).thenAnswer((_) async => nodes);

      const query = AdvancedSearchQuery(titleQuery: 'NonExistent');
      final result = await handler.handle(query);

      expect(result.isSuccess, true);
      expect(result.data?.isEmpty, true);
    });

    test('应该处理仓库错误', () async {
      when(mockRepository.queryAll()).thenThrow(Exception('Database error'));

      const query = AdvancedSearchQuery(titleQuery: 'Test');
      final result = await handler.handle(query);

      expect(result.isSuccess, false);
      expect(result.error, contains('Failed to perform advanced search'));
    });

    test('应该处理多个组合过滤器', () async {
      final nodes = [
        createTestNode(
          id: '1',
          title: 'Important Task',
          content: 'Work content',
          metadata: {'tags': ['work', 'urgent']},
        ),
        createTestNode(
          id: '2',
          title: 'Important Task',
          content: 'Personal content',
          metadata: {'tags': ['personal']},
        ),
      ];

      when(mockRepository.queryAll()).thenAnswer((_) async => nodes);

      const query = AdvancedSearchQuery(
        titleQuery: 'Important',
        tags: ['work'],
      );
      final result = await handler.handle(query);

      expect(result.isSuccess, true);
      expect(result.data?.length, 1);
      expect(result.data?[0].id, '1');
    });
  });
}
