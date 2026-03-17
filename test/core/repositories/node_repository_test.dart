import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/models/node_reference.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:path/path.dart' as path;

void main() {
  group('FileSystemNodeRepository', () {
    late FileSystemNodeRepository repository;
    late String testDir;

    setUp(() async {
      testDir = Directory.systemTemp.createTempSync('test_nodes_').path;
      repository = FileSystemNodeRepository(nodesDir: testDir);
      await repository.init();
    });

    tearDown(() async {
      final dir = Directory(testDir);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    });

    group('init', () {
      test('should create directory if it does not exist', () async {
        final newDir = Directory.systemTemp.createTempSync('test_new_nodes_').path;
        final newRepo = FileSystemNodeRepository(nodesDir: newDir);

        await newRepo.init();

        expect(Directory(newDir).existsSync(), true);

        await Directory(newDir).delete(recursive: true);
      });
    });

    group('save', () {
      test('should save a node successfully', () async {
        final node = Node(
          id: 'node_1',
          title: 'Test Node',
          content: 'Test content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node);

        final file = File(path.join(testDir, 'node_1.md'));
        expect(file.existsSync(), true);
      });

      test('should update existing node', () async {
        final node = Node(
          id: 'node_1',
          title: 'Test Node',
          content: 'Test content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node);

        final updatedNode = node.copyWith(
          title: 'Updated Node',
          content: 'Updated content',
        );

        await repository.save(updatedNode);

        final loaded = await repository.load('node_1');
        expect(loaded?.title, 'Updated Node');
        expect(loaded?.content, 'Updated content');
      });

      test('should update metadata index when saving node', () async {
        final node = Node(
          id: 'node_1',
          title: 'Test Node',
          content: 'Test content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node);

        final index = await repository.getMetadataIndex();
        expect(index.nodes.length, 1);
        expect(index.nodes[0].id, 'node_1');
      });
    });

    group('load', () {
      test('should load a node successfully', () async {
        final node = Node(
          id: 'node_1',
          title: 'Test Node',
          content: 'Test content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node);
        final loaded = await repository.load('node_1');

        expect(loaded, isNotNull);
        expect(loaded!.id, 'node_1');
        expect(loaded.title, 'Test Node');
        expect(loaded.content, 'Test content');
      });

      test('should return null if node does not exist', () async {
        final loaded = await repository.load('non_existent');
        expect(loaded, isNull);
      });
    });

    group('delete', () {
      test('should delete a node successfully', () async {
        final node = Node(
          id: 'node_1',
          title: 'Test Node',
          content: 'Test content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node);
        await repository.delete('node_1');

        final loaded = await repository.load('node_1');
        expect(loaded, isNull);
      });

      test('should not throw error when deleting non-existent node', () async {
        expect(() async => repository.delete('non_existent'), returnsNormally);
      });
    });

    group('saveAll', () {
      test('should save multiple nodes successfully', () async {
        final nodes = [
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content 1',
            references: const {},
            position: const Offset(100, 200),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
          Node(
            id: 'node_2',
            title: 'Node 2',
            content: 'Content 2',
            references: const {},
            position: const Offset(300, 400),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        await repository.saveAll(nodes);

        final loaded1 = await repository.load('node_1');
        final loaded2 = await repository.load('node_2');

        expect(loaded1, isNotNull);
        expect(loaded2, isNotNull);
      });

      test('should update metadata index for all nodes', () async {
        final nodes = [
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content 1',
            references: const {},
            position: const Offset(100, 200),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
          Node(
            id: 'node_2',
            title: 'Node 2',
            content: 'Content 2',
            references: const {},
            position: const Offset(300, 400),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        await repository.saveAll(nodes);

        final index = await repository.getMetadataIndex();
        expect(index.nodes.length, 2);
      });
    });

    group('loadAll', () {
      test('should load multiple nodes successfully', () async {
        final nodes = [
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content 1',
            references: const {},
            position: const Offset(100, 200),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
          Node(
            id: 'node_2',
            title: 'Node 2',
            content: 'Content 2',
            references: const {},
            position: const Offset(300, 400),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        await repository.saveAll(nodes);

        final loaded = await repository.loadAll(['node_1', 'node_2']);

        expect(loaded.length, 2);
        expect(loaded.any((n) => n.id == 'node_1'), true);
        expect(loaded.any((n) => n.id == 'node_2'), true);
      });

      test('should skip non-existent nodes', () async {
        final node = Node(
          id: 'node_1',
          title: 'Node 1',
          content: 'Content 1',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node);

        final loaded = await repository.loadAll(['node_1', 'non_existent']);

        expect(loaded.length, 1);
        expect(loaded[0].id, 'node_1');
      });
    });

    group('queryAll', () {
      test('should return empty list when no nodes exist', () async {
        final nodes = await repository.queryAll();
        expect(nodes, isEmpty);
      });

      test('should return all nodes', () async {
        final nodes = [
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content 1',
            references: const {},
            position: const Offset(100, 200),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
          Node(
            id: 'node_2',
            title: 'Node 2',
            content: 'Content 2',
            references: const {},
            position: const Offset(300, 400),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        await repository.saveAll(nodes);

        final queried = await repository.queryAll();
        expect(queried.length, 2);
      });

      test('should handle corrupted files gracefully', () async {
        final validNode = Node(
          id: 'node_1',
          title: 'Valid Node',
          content: 'Valid content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(validNode);

        final corruptedFile = File(path.join(testDir, 'corrupted.md'));
        await corruptedFile.writeAsString('invalid markdown {{{');

        final queried = await repository.queryAll();
        expect(queried.length, greaterThanOrEqualTo(1));
        expect(queried.any((n) => n.id == 'node_1'), true);
      });

      test('should create directory if it does not exist', () async {
        final newDir = Directory.systemTemp.createTempSync('test_queryall_dir_').path;
        final newRepo = FileSystemNodeRepository(nodesDir: path.join(newDir, 'nodes'));

        final nodes = await newRepo.queryAll();
        expect(nodes, isEmpty);
        expect(Directory(path.join(newDir, 'nodes')).existsSync(), true);

        await Directory(newDir).delete(recursive: true);
      });
    });

    group('search', () {
      setUp(() async {
        final nodes = [
          Node(
            id: 'node_1',
            title: 'Python Programming',
            content: 'Learn Python basics and advanced concepts',
            references: const {},
            position: const Offset(100, 200),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime.now(),
            metadata: {'tags': ['programming', 'python']},
          ),
          Node(
            id: 'node_2',
            title: 'Dart Language',
            content: 'Dart is a programming language for Flutter',
            references: const {},
            position: const Offset(300, 400),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime(2024, 2, 1),
            updatedAt: DateTime.now(),
            metadata: {'tags': ['programming', 'dart']},
          ),
          Node(
            id: 'node_3',
            title: 'Machine Learning',
            content: 'Introduction to ML algorithms',
            references: const {},
            position: const Offset(500, 600),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime(2024, 3, 1),
            updatedAt: DateTime.now(),
            metadata: {'tags': ['ml', 'ai']},
          ),
        ];

        await repository.saveAll(nodes);
      });

      test('should search by title', () async {
        final results = await repository.search(title: 'Python');
        expect(results.length, 1);
        expect(results[0].title, 'Python Programming');
      });

      test('should search by content', () async {
        final results = await repository.search(content: 'Flutter');
        expect(results.length, 1);
        expect(results[0].title, 'Dart Language');
      });

      test('should search by title OR content', () async {
        final results = await repository.search(title: 'Python', content: 'Flutter');
        expect(results.length, 2);
      });

      test('should search by tags', () async {
        final results = await repository.search(tags: ['programming']);
        expect(results.length, 2);
      });

      test('should search by multiple tags', () async {
        final results = await repository.search(tags: ['programming', 'dart']);
        expect(results.length, 2);
      });

      test('should search by date range', () async {
        final results = await repository.search(
          startDate: DateTime(2024, 1, 15),
          endDate: DateTime(2024, 2, 15),
        );
        expect(results.length, 1);
        expect(results[0].title, 'Dart Language');
      });

      test('should combine multiple search criteria', () async {
        final results = await repository.search(
          title: 'Python',
          tags: ['programming'],
        );
        expect(results.length, 1);
        expect(results[0].title, 'Python Programming');
      });

      test('should return all nodes when no criteria provided', () async {
        final results = await repository.search();
        expect(results.length, 3);
      });

      test('should be case insensitive', () async {
        final results1 = await repository.search(title: 'python');
        final results2 = await repository.search(title: 'PYTHON');
        expect(results1.length, 1);
        expect(results2.length, 1);
      });
    });

    group('getNodeFilePath', () {
      test('should return correct file path', () {
        final filePath = repository.getNodeFilePath('node_1');
        expect(filePath, path.join(testDir, 'node_1.md'));
      });
    });

    group('getMetadataIndex', () {
      test('should return empty index when no nodes exist', () async {
        final index = await repository.getMetadataIndex();
        expect(index.nodes, isEmpty);
      });

      test('should return index with all nodes', () async {
        final nodes = [
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content 1',
            references: const {},
            position: const Offset(100, 200),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
          Node(
            id: 'node_2',
            title: 'Node 2',
            content: 'Content 2',
            references: const {},
            position: const Offset(300, 400),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        await repository.saveAll(nodes);

        final index = await repository.getMetadataIndex();
        expect(index.nodes.length, 2);
        expect(index.nodes.any((n) => n.id == 'node_1'), true);
        expect(index.nodes.any((n) => n.id == 'node_2'), true);
      });

      test('should return empty index for corrupted index file', () async {
        final indexFile = File(path.join(testDir, 'index.json'));
        await indexFile.writeAsString('corrupted data');

        final index = await repository.getMetadataIndex();
        expect(index.nodes, isEmpty);
      });
    });

    group('updateIndex', () {
      test('should update metadata index for node', () async {
        final node = Node(
          id: 'node_1',
          title: 'Test Node',
          content: 'Test content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.updateIndex(node);

        final index = await repository.getMetadataIndex();
        expect(index.nodes.length, 1);
        expect(index.nodes[0].id, 'node_1');
        expect(index.nodes[0].title, 'Test Node');
      });

      test('should replace existing node in index', () async {
        final node = Node(
          id: 'node_1',
          title: 'Test Node',
          content: 'Test content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.updateIndex(node);

        final updatedNode = node.copyWith(title: 'Updated Node');
        await repository.updateIndex(updatedNode);

        final index = await repository.getMetadataIndex();
        expect(index.nodes.length, 1);
        expect(index.nodes[0].title, 'Updated Node');
      });
    });

    group('markdown parsing', () {
      test('should parse node with frontmatter and content', () async {
        const markdown = '''
---
id: node_1
title: "Test Node"
created_at: 2024-01-01T00:00:00.000Z
updated_at: 2024-01-01T00:00:00.000Z
position:
  dx: 100.0
  dy: 200.0
size:
  width: 300.0
  height: 400.0
---
Test content''';

        final file = File(path.join(testDir, 'node_1.md'));
        await file.writeAsString(markdown);

        final node = await repository.load('node_1');
        expect(node, isNotNull);
        expect(node!.title, 'Test Node');
        expect(node.content, 'Test content');
        expect(node.position, const Offset(100, 200));
        expect(node.size, const Size(300, 400));
      });

      test('should parse node with references', () async {
        const markdown = '''
---
id: node_1
title: "Test Node"
created_at: 2024-01-01T00:00:00.000Z
updated_at: 2024-01-01T00:00:00.000Z
position:
  dx: 100.0
  dy: 200.0
size:
  width: 300.0
  height: 400.0
references:
  node_2:
    type: relatesTo
  node_3:
    type: dependsOn
    role: "dependency"
---
Test content''';

        final file = File(path.join(testDir, 'node_1.md'));
        await file.writeAsString(markdown);

        final node = await repository.load('node_1');
        expect(node, isNotNull);
        expect(node!.references.length, 2);
        expect(node.references['node_2']?.type, 'relatesTo');
        expect(node.references['node_3']?.type, 'dependsOn');
        expect(node.references['node_3']?.role, 'dependency');
      });

      test('should parse node with metadata', () async {
        const markdown = '''
---
id: node_1
title: "Test Node"
created_at: 2024-01-01T00:00:00.000Z
updated_at: 2024-01-01T00:00:00.000Z
position:
  dx: 100.0
  dy: 200.0
size:
  width: 300.0
  height: 400.0
metadata:
  tags:
    - tag1
    - tag2
  priority: high
---
Test content''';

        final file = File(path.join(testDir, 'node_1.md'));
        await file.writeAsString(markdown);

        final node = await repository.load('node_1');
        expect(node, isNotNull);
        expect(node!.metadata['tags'], ['tag1', 'tag2']);
        expect(node.metadata['priority'], 'high');
      });

      test('should parse node with h1 title in content', () async {
        const markdown = '''
---
id: node_1
title: "Original Title"
created_at: 2024-01-01T00:00:00.000Z
updated_at: 2024-01-01T00:00:00.000Z
position:
  dx: 100.0
  dy: 200.0
size:
  width: 300.0
  height: 400.0
---
# Content Title

This is actual content.''';

        final file = File(path.join(testDir, 'node_1.md'));
        await file.writeAsString(markdown);

        final node = await repository.load('node_1');
        expect(node, isNotNull);
        expect(node!.title, 'Content Title');
        expect(node.content, 'This is actual content.');
      });

      test('should parse node with color', () async {
        const markdown = '''
---
id: node_1
title: "Test Node"
created_at: 2024-01-01T00:00:00.000Z
updated_at: 2024-01-01T00:00:00.000Z
position:
  dx: 100.0
  dy: 200.0
size:
  width: 300.0
  height: 400.0
color: "#FF0000"
---
Test content''';

        final file = File(path.join(testDir, 'node_1.md'));
        await file.writeAsString(markdown);

        final node = await repository.load('node_1');
        expect(node, isNotNull);
        expect(node!.color, '#FF0000');
      });
    });

    group('markdown generation', () {
      test('should generate valid markdown for node', () async {
        final node = Node(
          id: 'node_1',
          title: 'Test Node',
          content: 'Test content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          metadata: const {},
        );

        await repository.save(node);

        final file = File(path.join(testDir, 'node_1.md'));
        final content = await file.readAsString();

        expect(content, contains('---'));
        expect(content, contains('id: node_1'));
        expect(content, contains('title: "Test Node"'));
        expect(content, contains('Test content'));
      });

      test('should generate markdown with references', () async {
        final node = Node(
          id: 'node_1',
          title: 'Test Node',
          content: 'Test content',
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          references: {
            'node_2': const NodeReference(
              nodeId: 'node_2',
              properties: {'type': 'relatesTo'},
            ),
            'node_3': const NodeReference(
              nodeId: 'node_3',
              properties: {
                'type': 'dependsOn',
                'role': 'dependency',
              },
            ),
          },
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          metadata: const {},
        );

        await repository.save(node);

        final file = File(path.join(testDir, 'node_1.md'));
        final content = await file.readAsString();

        expect(content, contains('references:'));
        expect(content, contains('node_2:'));
        expect(content, contains('type: relatesTo'));
        expect(content, contains('node_3:'));
        expect(content, contains('type: dependsOn'));
        expect(content, contains('role: "dependency"'));
      });

      test('should generate markdown with metadata', () async {
        final node = Node(
          id: 'node_1',
          title: 'Test Node',
          content: 'Test content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          metadata: {
            'tags': ['tag1', 'tag2'],
            'priority': 'high',
          },
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        await repository.save(node);

        final file = File(path.join(testDir, 'node_1.md'));
        final content = await file.readAsString();

        expect(content, contains('metadata:'));
        expect(content, contains('tags:'));
      });

      test('should generate markdown with color', () async {
        final node = Node(
          id: 'node_1',
          title: 'Test Node',
          content: 'Test content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          color: '#FF0000',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          metadata: const {},
        );

        await repository.save(node);

        final file = File(path.join(testDir, 'node_1.md'));
        final content = await file.readAsString();

        expect(content, contains('color: "#FF0000"'));
      });
    });

    group('integration tests', () {
      test('should handle complete workflow', () async {
        final nodes = [
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content 1',
            references: const {},
            position: const Offset(100, 200),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
          Node(
            id: 'node_2',
            title: 'Node 2',
            content: 'Content 2',
            references: const {},
            position: const Offset(300, 400),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        await repository.saveAll(nodes);

        final allNodes = await repository.queryAll();
        expect(allNodes.length, greaterThanOrEqualTo(2));

        final searchResults = await repository.search(title: 'Node 1');
        expect(searchResults.length, greaterThanOrEqualTo(1));

        await repository.delete('node_1');
        final remainingNodes = await repository.queryAll();
        expect(remainingNodes.length, greaterThanOrEqualTo(1));
        expect(remainingNodes.any((n) => n.id == 'node_2'), true);

        final index = await repository.getMetadataIndex();
        expect(index.nodes.length, greaterThanOrEqualTo(1));
        expect(index.nodes.any((n) => n.id == 'node_2'), true);
      });
    });
  });
}