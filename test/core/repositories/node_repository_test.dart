import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:path/path.dart' as path;
import '../../test_helpers.dart';

// 生成 Mock 类（需要在运行 flutter pub run build_runner build 后）
// 这里使用简单的 Mock 实现
class MockDirectory extends Mock implements Directory {}

class MockFile extends Mock implements File {}

void main() {
  group('FileSystemNodeRepository', () {
    late FileSystemNodeRepository repository;
    late String testNodesDir;

    setUp(() {
      // 使用临时目录进行测试
      testNodesDir = 'test_nodes_${DateTime.now().millisecondsSinceEpoch}';
      repository = FileSystemNodeRepository(nodesDir: testNodesDir);
    });

    tearDown(() async {
      // 清理测试目录
      final dir = Directory(testNodesDir);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    });

    group('Initialization', () {
      test('should create nodes directory if it does not exist', () async {
        await repository.init();

        final dir = Directory(testNodesDir);
        expect(dir.existsSync(), true);
      });

      test('should create write test file during initialization', () async {
        await repository.init();

        final testFile = File('$testNodesDir/.write_test');
        expect(testFile.existsSync(), false); // Should be deleted after test
      });

      test('should handle existing directory', () async {
        await repository.init();

        // 第二次初始化不应该抛出错误
        await repository.init();

        final dir = Directory(testNodesDir);
        expect(dir.existsSync(), true);
      });
    });

    group('save and load', () {
      test('should save and load a node', () async {
        await repository.init();

        final node = NodeTestHelpers.test(
          id: 'test-node-1',
          title: 'Test Node',
          content: 'Test content',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        await repository.save(node);
        final loadedNode = await repository.load('test-node-1');

        expect(loadedNode, isNotNull);
        expect(loadedNode!.id, node.id);
        expect(loadedNode.title, node.title);
        expect(loadedNode.content, node.content);
        expect(loadedNode.position, node.position);
        expect(loadedNode.size, node.size);
      });

      test('should save node with references', () async {
        await repository.init();

        final node = NodeTestHelpers.test(
          id: 'test-node-2',
          title: 'Node with References',
          content: 'Content',
          references: const {
            'ref-1': NodeReference(
              nodeId: 'ref-1',
              type: ReferenceType.relatesTo,
              role: 'related',
            ),
            'ref-2': NodeReference(
              nodeId: 'ref-2',
              type: ReferenceType.contains,
            ),
          },
          position: const Offset(0, 0),
          size: const Size(100, 100),
          viewMode: NodeViewMode.titleOnly,
        );

        await repository.save(node);
        final loadedNode = await repository.load('test-node-2');

        expect(loadedNode?.references.length, 2);
        expect(loadedNode?.references['ref-1']?.type, ReferenceType.relatesTo);
        expect(loadedNode?.references['ref-2']?.type, ReferenceType.contains);
      });

      test('should return null for non-existent node', () async {
        await repository.init();

        final loadedNode = await repository.load('non-existent');

        expect(loadedNode, null);
      });

      test('should save node with metadata', () async {
        await repository.init();

        final node = NodeTestHelpers.test(
          id: 'test-node-3',
          title: 'Node with Metadata',
          content: 'Content',
          metadata: {
            'isFolder': true,
            'tags': ['important', 'test'],
            'customField': 'custom value',
          },
        );

        await repository.save(node);
        final loadedNode = await repository.load('test-node-3');

        expect(loadedNode?.metadata['isFolder'], true);
        expect(loadedNode?.metadata['tags'], ['important', 'test']);
        expect(loadedNode?.metadata['customField'], 'custom value');
      });

      test('should update existing node', () async {
        await repository.init();

        final originalNode = NodeTestHelpers.test(
          id: 'test-node-4',
          title: 'Original Title',
          content: 'Original content',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        await repository.save(originalNode);

        final updatedNode = originalNode.copyWith(
          title: 'Updated Title',
          content: 'Updated content',
          position: const Offset(200, 200),
        );

        await repository.save(updatedNode);
        final loadedNode = await repository.load('test-node-4');

        expect(loadedNode?.title, 'Updated Title');
        expect(loadedNode?.content, 'Updated content');
        expect(loadedNode?.position, const Offset(200, 200));
        expect(loadedNode?.createdAt, originalNode.createdAt); // Should preserve created date
      });
    });

    group('delete', () {
      test('should delete a node', () async {
        await repository.init();

        final node = NodeTestHelpers.test(
          id: 'test-node-delete',
          title: 'To be deleted',
          content: 'Content',
        );

        await repository.save(node);
        expect(await repository.load('test-node-delete'), isNotNull);

        await repository.delete('test-node-delete');
        expect(await repository.load('test-node-delete'), null);
      });

      test('should handle deleting non-existent node', () async {
        await repository.init();

        // Should not throw
        await repository.delete('non-existent');
      });
    });

    group('saveAll and loadAll', () {
      test('should save multiple nodes', () async {
        await repository.init();

        final nodes = [
          NodeTestHelpers.test(id: 'node-1', title: 'Node 1', content: 'Content 1', position: const Offset(0, 0)),
          NodeTestHelpers.test(id: 'node-2', title: 'Node 2', content: 'Content 2', position: const Offset(100, 100)),
          NodeTestHelpers.test(id: 'node-3', title: 'Node 3', content: 'Content 3', position: const Offset(200, 200)),
        ];

        await repository.saveAll(nodes);

        for (final node in nodes) {
          final loaded = await repository.load(node.id);
          expect(loaded, isNotNull);
          expect(loaded?.title, node.title);
        }
      });

      test('should load multiple nodes by IDs', () async {
        await repository.init();

        final node1 = NodeTestHelpers.test(
          id: 'load-1',
          title: 'Load Test 1',
          content: 'Content',
        );

        final node2 = NodeTestHelpers.test(
          id: 'load-2',
          title: 'Load Test 2',
          content: 'Content',
        );

        await repository.save(node1);
        await repository.save(node2);

        final loadedNodes = await repository.loadAll(['load-1', 'load-2', 'non-existent']);

        expect(loadedNodes.length, 2); // Only 2 exist
        expect(loadedNodes.map((n) => n.id).toSet(), {'load-1', 'load-2'});
      });
    });

    group('queryAll', () {
      test('should return empty list when no nodes exist', () async {
        await repository.init();

        final nodes = await repository.queryAll();

        expect(nodes, isEmpty);
      });

      test('should return all nodes', () async {
        await repository.init();

        final nodes = [
          NodeTestHelpers.test(id: 'query-1', title: 'Query Test 1'),
          NodeTestHelpers.test(id: 'query-2', title: 'Query Test 2'),
        ];

        for (final node in nodes) {
          await repository.save(node);
        }

        final queriedNodes = await repository.queryAll();

        expect(queriedNodes.length, 2);
        expect(queriedNodes.map((n) => n.id).toSet(), {'query-1', 'query-2'});
      });
    });

    group('search', () {
      test('should search nodes by title', () async {
        await repository.init();

        final nodes = [
          NodeTestHelpers.test(id: 'search-1', title: 'Apple Banana'),
          NodeTestHelpers.test(id: 'search-2', title: 'Strawberry'),
          NodeTestHelpers.test(id: 'search-3', title: 'Blueberry'),
        ];

        for (final node in nodes) {
          await repository.save(node);
        }

        final results = await repository.search(title: 'Berry');

        // "Berry" appears in "Strawberry" and "Blueberry"
        expect(results.length, 2);
        expect(results.map((n) => n.id).toSet(), {'search-2', 'search-3'});
      });

      test('should search nodes by content', () async {
        await repository.init();

        final node1 = NodeTestHelpers.test(
          id: 'content-1',
          title: 'Title',
          content: 'This contains important keyword',
        );

        final node2 = NodeTestHelpers.test(
          id: 'content-2',
          title: 'Title',
          content: 'Different content',
        );

        await repository.save(node1);
        await repository.save(node2);

        final results = await repository.search(content: 'keyword');

        expect(results.length, 1);
        expect(results[0].id, 'content-1');
      });

      test('should search nodes by tags', () async {
        await repository.init();

        final node1 = NodeTestHelpers.test(
          id: 'tag-1',
          title: 'Title',
          metadata: {'tags': ['important', 'work']},
        );

        final node2 = NodeTestHelpers.test(
          id: 'tag-2',
          title: 'Title',
          metadata: {'tags': ['personal']},
        );

        await repository.save(node1);
        await repository.save(node2);

        final results = await repository.search(tags: ['important']);

        expect(results.length, 1);
        expect(results[0].id, 'tag-1');
      });

      test('should search nodes by date range', () async {
        await repository.init();

        final node1 = NodeTestHelpers.test(
          id: 'date-1',
          title: 'Title',
          createdAt: DateTime(2024, 1, 15),
          updatedAt: DateTime(2024, 1, 15),
        );

        final node2 = NodeTestHelpers.test(
          id: 'date-2',
          title: 'Title',
          createdAt: DateTime(2024, 2, 15),
          updatedAt: DateTime(2024, 2, 15),
        );

        await repository.save(node1);
        await repository.save(node2);

        final results = await repository.search(
          startDate: DateTime(2024, 2, 1),
          endDate: DateTime(2024, 2, 28),
        );

        expect(results.length, 1);
        expect(results[0].id, 'date-2');
      });

      test('should be case-insensitive when searching', () async {
        await repository.init();

        final node = NodeTestHelpers.test(
          id: 'case-test',
          title: 'UPPERCASE TITLE',
          content: 'lowercase content',
        );

        await repository.save(node);

        final titleResults = await repository.search(title: 'uppercase');
        final contentResults = await repository.search(content: 'LOWERCASE');

        expect(titleResults.length, 1);
        expect(contentResults.length, 1);
      });
    });

    group('getNodeFilePath', () {
      test('should generate correct file path', () {
        repository = FileSystemNodeRepository(nodesDir: 'custom/nodes/dir');

        final filePath = repository.getNodeFilePath('test-node-id');

        // Check that the path contains the expected components
        // The exact separator may vary by platform
        expect(filePath, contains('test-node-id.md'));
        expect(filePath, endsWith('test-node-id.md'));

        // Verify the path structure is correct
        // Normalize both paths for comparison
        final normalized = path.normalize(filePath);
        final parts = path.split(normalized);
        expect(parts, contains('test-node-id.md'));
      });
    });
  });
}
