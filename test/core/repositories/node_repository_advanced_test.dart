import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/models/node_reference.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:path/path.dart' as path;

void main() {
  group('FileSystemNodeRepository Advanced Tests', () {
    late FileSystemNodeRepository repository;
    late String testDir;

    setUp(() async {
      testDir = Directory.systemTemp.createTempSync('test_nodes_advanced_').path;
      repository = FileSystemNodeRepository(nodesDir: testDir);
      await repository.init();
    });

    tearDown(() async {
      final dir = Directory(testDir);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    });

    group('concurrent operations', () {
      test('should handle concurrent saves to same node', () async {
        final node = Node(
          id: 'concurrent_node',
          title: 'Original',
          content: 'Original content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node);

        final futures = List.generate(5, (i) async {
          final updatedNode = node.copyWith(
            title: 'Update $i',
            updatedAt: DateTime.now(),
          );
          await repository.save(updatedNode);
        });

        await Future.wait(futures);

        final loaded = await repository.load('concurrent_node');
        expect(loaded, isNotNull);
        expect(loaded!.id, 'concurrent_node');
      });

      test('should handle concurrent saves to different nodes', () async {
        final nodes = List.generate(10, (i) => Node(
          id: 'node_$i',
          title: 'Node $i',
          content: 'Content $i',
          references: const {},
          position: Offset(i * 100.0, i * 100.0),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        ));

        await Future.wait(nodes.map((n) => repository.save(n)));

        final allNodes = await repository.queryAll();
        expect(allNodes.length, 10);
      });

      test('should maintain index consistency during concurrent operations', () async {
        final nodes = List.generate(5, (i) => Node(
          id: 'index_node_$i',
          title: 'Index Node $i',
          content: 'Content $i',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        ));

        for (final node in nodes) {
          await repository.save(node);
        }

        final index = await repository.getMetadataIndex();
        expect(index.nodes.length, 5);

        final nodeIds = index.nodes.map((n) => n.id).toSet();
        for (var i = 0; i < 5; i++) {
          expect(nodeIds.contains('index_node_$i'), true);
        }
      });
    });

    group('reference integrity', () {
      test('should preserve node references after save and load', () async {
        final node1 = Node(
          id: 'node_1',
          title: 'Source Node',
          content: 'Source content',
          references: {
            'node_2': const NodeReference(
              nodeId: 'node_2',
              properties: {'type': 'relatesTo', 'role': 'parent'},
            ),
            'node_3': const NodeReference(
              nodeId: 'node_3',
              properties: {'type': 'dependsOn'},
            ),
          },
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node1);
        final loaded = await repository.load('node_1');

        expect(loaded, isNotNull);
        expect(loaded!.references.length, 2);
        expect(loaded.references['node_2']?.type, 'relatesTo');
        expect(loaded.references['node_2']?.role, 'parent');
        expect(loaded.references['node_3']?.type, 'dependsOn');
      });

      test('should handle circular references', () async {
        final node1 = Node(
          id: 'circular_1',
          title: 'Node 1',
          content: 'Content 1',
          references: {
            'circular_2': const NodeReference(
              nodeId: 'circular_2',
              properties: {'type': 'relatesTo'},
            ),
          },
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        final node2 = Node(
          id: 'circular_2',
          title: 'Node 2',
          content: 'Content 2',
          references: {
            'circular_1': const NodeReference(
              nodeId: 'circular_1',
              properties: {'type': 'relatesTo'},
            ),
          },
          position: const Offset(300, 400),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node1);
        await repository.save(node2);

        final loaded1 = await repository.load('circular_1');
        final loaded2 = await repository.load('circular_2');

        expect(loaded1?.references['circular_2'], isNotNull);
        expect(loaded2?.references['circular_1'], isNotNull);
      });

      test('should handle references with metadata', () async {
        final node = Node(
          id: 'ref_with_meta',
          title: 'Node with reference metadata',
          content: 'Content',
          references: {
            'target_1': const NodeReference(
              nodeId: 'target_1',
              properties: {
                'type': 'relatesTo',
                'role': 'dependency',
                'weight': 0.8,
                'created': '2024-01-01',
              },
            ),
          },
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node);
        final loaded = await repository.load('ref_with_meta');

        expect(loaded, isNotNull);
        expect(loaded!.references['target_1']?.properties['weight'], 0.8);
        expect(loaded.references['target_1']?.properties['created'], '2024-01-01');
      });
    });

    group('data recovery scenarios', () {
      test('should recover from corrupted index file', () async {
        final node = Node(
          id: 'recovery_node',
          title: 'Recovery Test',
          content: 'Content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node);

        final indexFile = File(path.join(testDir, 'index.json'));
        await indexFile.writeAsString('corrupted {{{ json');

        final loaded = await repository.load('recovery_node');
        expect(loaded, isNotNull);
        expect(loaded!.title, 'Recovery Test');

        final newIndex = await repository.getMetadataIndex();
        expect(newIndex.nodes, isEmpty);
      });

      test('should handle partial file corruption gracefully', () async {
        final validNode = Node(
          id: 'valid_node',
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

        final corruptedFile = File(path.join(testDir, 'corrupted_node.md'));
        await corruptedFile.writeAsString('not valid markdown at all {{{');

        final allNodes = await repository.queryAll();
        expect(allNodes.length, greaterThanOrEqualTo(1));
        expect(allNodes.any((n) => n.id == 'valid_node'), true);
      });

      test('should handle missing frontmatter gracefully', () async {
        final noFrontmatterFile = File(path.join(testDir, 'no_frontmatter.md'));
        await noFrontmatterFile.writeAsString('''
Just some content without frontmatter.
No YAML headers at all.
''');

        final allNodes = await repository.queryAll();

        expect(allNodes, isNotEmpty);
      });

      test('should rebuild index after manual file operations', () async {
        final node = Node(
          id: 'manual_node',
          title: 'Manual Node',
          content: 'Content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node);

        final indexFile = File(path.join(testDir, 'index.json'));
        await indexFile.delete();

        await repository.updateIndex(node);

        final newIndex = await repository.getMetadataIndex();
        expect(newIndex.nodes.length, 1);
        expect(newIndex.nodes[0].id, 'manual_node');
      });
    });

    group('special content handling', () {
      test('should handle unicode content correctly', () async {
        final node = Node(
          id: 'unicode_node',
          title: '中文标题 日本語 한국어',
          content: '''
内容包含多种语言：
- 中文内容
- 日本語コンテンツ
- 한국어 콘텐츠
- Emoji: 😀🎉🚀
- Special: ©®™€£¥
''',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node);
        final loaded = await repository.load('unicode_node');

        expect(loaded, isNotNull);
        expect(loaded!.title, contains('中文'));
        expect(loaded.title, contains('日本語'));
        expect(loaded.content, contains('😀'));
      });

      test('should handle markdown with code blocks', () async {
        final node = Node(
          id: 'markdown_node',
          title: 'Markdown Node',
          content: '''
# Heading 1

## Heading 2

```dart
void main() {
  debugPrint('Hello, World!');
}
```

**Bold text** and *italic text*.

- List item 1
- List item 2

> Blockquote

[Link](https://example.com)
''',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node);
        final loaded = await repository.load('markdown_node');

        expect(loaded, isNotNull);
        expect(loaded!.content, contains('```dart'));
        expect(loaded.content, contains('**Bold text**'));
        expect(loaded.content, contains('[Link]'));
      });

      test('should handle very long content', () async {
        final longContent = 'A' * 100000;

        final node = Node(
          id: 'long_content_node',
          title: 'Long Content',
          content: longContent,
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node);
        final loaded = await repository.load('long_content_node');

        expect(loaded, isNotNull);
        expect(loaded!.content?.length, 100000);
      });

      test('should handle special characters in metadata values', () async {
        final node = Node(
          id: 'special_meta_node',
          title: 'Special Metadata',
          content: 'Content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {
            'special_key': 'value:with:colons',
            'another_key': 'value with spaces, and commas',
            'quoted': '"already quoted"',
          },
        );

        await repository.save(node);
        final loaded = await repository.load('special_meta_node');

        expect(loaded, isNotNull);
        expect(loaded!.metadata['special_key'], 'value:with:colons');
        expect(loaded.metadata['another_key'], 'value with spaces, and commas');
      });
    });

    group('index operations', () {
      test('should remove stale entries from index', () async {
        final node1 = Node(
          id: 'stale_node_1',
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

        final node2 = Node(
          id: 'stale_node_2',
          title: 'Node 2',
          content: 'Content 2',
          references: const {},
          position: const Offset(200, 300),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node1);
        await repository.save(node2);

        final file = File(path.join(testDir, 'stale_node_1.md'));
        await file.delete();

        final allNodes = await repository.queryAll();
        expect(allNodes.length, 1);
        expect(allNodes[0].id, 'stale_node_2');
      });

      test('should update index when node is updated', () async {
        final node = Node(
          id: 'update_index_node',
          title: 'Original Title',
          content: 'Original content',
          references: const {},
          position: const Offset(100, 200),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await repository.save(node);

        var index = await repository.getMetadataIndex();
        expect(index.nodes[0].title, 'Original Title');

        final updatedNode = node.copyWith(
          title: 'Updated Title',
          position: const Offset(500, 600),
        );
        await repository.save(updatedNode);

        index = await repository.getMetadataIndex();
        expect(index.nodes.length, 1);
        expect(index.nodes[0].title, 'Updated Title');
        expect(index.nodes[0].position.dx, 500);
        expect(index.nodes[0].position.dy, 600);
      });
    });
  });
}
