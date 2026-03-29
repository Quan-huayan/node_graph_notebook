import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/models/node_reference.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:path/path.dart' as path;

void main() {
  group('FileSystemNodeRepository - 文件系统节点仓库', () {
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

    group('init - 初始化', () {
      test('如果目录不存在应该创建目录', () async {
        final newDir = Directory.systemTemp.createTempSync('test_new_nodes_').path;
        final newRepo = FileSystemNodeRepository(nodesDir: newDir);

        await newRepo.init();

        expect(Directory(newDir).existsSync(), true);

        await Directory(newDir).delete(recursive: true);
      });
    });

    group('save - 保存', () {
      test('应该成功保存节点', () async {
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

      test('应该更新已存在的节点', () async {
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

      test('保存节点时应该更新元数据索引', () async {
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

    group('load - 加载', () {
      test('应该成功加载节点', () async {
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

      test('如果节点不存在应该返回null', () async {
        final loaded = await repository.load('non_existent');
        expect(loaded, isNull);
      });
    });

    group('delete - 删除', () {
      test('应该成功删除节点', () async {
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

      test('删除不存在的节点时不应该抛出错误', () async {
        expect(() async => repository.delete('non_existent'), returnsNormally);
      });
    });

    group('saveAll - 批量保存', () {
      test('应该成功保存多个节点', () async {
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

      test('应该为所有节点更新元数据索引', () async {
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

    group('loadAll - 批量加载', () {
      test('应该成功加载多个节点', () async {
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

      test('应该跳过不存在的节点', () async {
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

    group('queryAll - 查询全部', () {
      test('当没有节点存在时应该返回空列表', () async {
        final nodes = await repository.queryAll();
        expect(nodes, isEmpty);
      });

      test('应该返回所有节点', () async {
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

      test('应该优雅地处理损坏的文件', () async {
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

      test('如果目录不存在应该创建目录', () async {
        final newDir = Directory.systemTemp.createTempSync('test_queryall_dir_').path;
        final newRepo = FileSystemNodeRepository(nodesDir: path.join(newDir, 'nodes'));

        final nodes = await newRepo.queryAll();
        expect(nodes, isEmpty);
        expect(Directory(path.join(newDir, 'nodes')).existsSync(), true);

        await Directory(newDir).delete(recursive: true);
      });
    });

    group('search - 搜索', () {
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

      test('应该按标题搜索', () async {
        final results = await repository.search(title: 'Python');
        expect(results.length, 1);
        expect(results[0].title, 'Python Programming');
      });

      test('应该按内容搜索', () async {
        final results = await repository.search(content: 'Flutter');
        expect(results.length, 1);
        expect(results[0].title, 'Dart Language');
      });

      test('应该按标题或内容搜索', () async {
        final results = await repository.search(title: 'Python', content: 'Flutter');
        expect(results.length, 2);
      });

      test('应该按标签搜索', () async {
        final results = await repository.search(tags: ['programming']);
        expect(results.length, 2);
      });

      test('应该按多个标签搜索', () async {
        final results = await repository.search(tags: ['programming', 'dart']);
        expect(results.length, 2);
      });

      test('应该按日期范围搜索', () async {
        final results = await repository.search(
          startDate: DateTime(2024, 1, 15),
          endDate: DateTime(2024, 2, 15),
        );
        expect(results.length, 1);
        expect(results[0].title, 'Dart Language');
      });

      test('应该组合多个搜索条件', () async {
        final results = await repository.search(
          title: 'Python',
          tags: ['programming'],
        );
        expect(results.length, 1);
        expect(results[0].title, 'Python Programming');
      });

      test('当没有提供搜索条件时应该返回所有节点', () async {
        final results = await repository.search();
        expect(results.length, 3);
      });

      test('应该不区分大小写', () async {
        final results1 = await repository.search(title: 'python');
        final results2 = await repository.search(title: 'PYTHON');
        expect(results1.length, 1);
        expect(results2.length, 1);
      });
    });

    group('getNodeFilePath - 获取节点文件路径', () {
      test('应该返回正确的文件路径', () {
        final filePath = repository.getNodeFilePath('node_1');
        expect(filePath, path.join(testDir, 'node_1.md'));
      });
    });

    group('getMetadataIndex - 获取元数据索引', () {
      test('当没有节点存在时应该返回空索引', () async {
        final index = await repository.getMetadataIndex();
        expect(index.nodes, isEmpty);
      });

      test('应该返回包含所有节点的索引', () async {
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

      test('对于损坏的索引文件应该返回空索引', () async {
        final indexFile = File(path.join(testDir, 'index.json'));
        await indexFile.writeAsString('corrupted data');

        final index = await repository.getMetadataIndex();
        expect(index.nodes, isEmpty);
      });
    });

    group('updateIndex - 更新索引', () {
      test('应该更新节点的元数据索引', () async {
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

      test('应该在索引中替换已存在的节点', () async {
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

    group('markdown parsing - Markdown解析', () {
      test('应该解析带有frontmatter和内容的节点', () async {
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

      test('应该解析带有引用的节点', () async {
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

      test('应该解析带有元数据的节点', () async {
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

      test('应该解析内容中包含h1标题的节点', () async {
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

      test('应该解析带有颜色的节点', () async {
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

    group('markdown generation - Markdown生成', () {
      test('应该为节点生成有效的Markdown', () async {
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

      test('应该生成带有引用的Markdown', () async {
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

      test('应该生成带有元数据的Markdown', () async {
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

      test('应该生成带有颜色的Markdown', () async {
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

    group('integration tests - 集成测试', () {
      test('应该处理完整的工作流', () async {
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