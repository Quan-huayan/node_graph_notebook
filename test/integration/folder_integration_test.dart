import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/plugins/graph/service/node_service.dart';
import 'package:path/path.dart' as path;

/// 文件夹集成测试
///
/// 测试文件夹功能的节点状态持久化，包括：
/// - 文件夹节点的创建、更新、删除
/// - 文件夹与节点的引用关系持久化
/// - 文件夹层级结构的持久化
/// - 元数据索引的同步更新
void main() {
  group('文件夹集成测试 - 节点状态持久化', () {
    late FileSystemNodeRepository nodeRepository;
    late NodeServiceImpl nodeService;
    late String testDir;

    setUp(() async {
      testDir = path.join(
        Directory.systemTemp.path,
        'folder_integration_test_${DateTime.now().millisecondsSinceEpoch}',
      );
      await Directory(testDir).create(recursive: true);

      nodeRepository = FileSystemNodeRepository(
        nodesDir: testDir,
        useAdjacencyList: false,
      );
      await nodeRepository.init();

      nodeService = NodeServiceImpl(nodeRepository);
    });

    tearDown(() async {
      // 延迟一下确保文件句柄释放
      await Future.delayed(const Duration(milliseconds: 100));

      final dir = Directory(testDir);
      if (dir.existsSync()) {
        try {
          await dir.delete(recursive: true);
        } catch (e) {
          // 忽略删除错误
        }
      }
    });

    group('文件夹节点创建和持久化', () {
      test('应该创建并持久化带有正确元数据的文件夹节点', () async {
        final folderNode = await nodeService.createNode(
          title: 'Test Folder',
          content: 'A test folder for organizing notes',
          metadata: {'isFolder': true},
        );

        expect(folderNode.id, isNotEmpty);
        expect(folderNode.title, 'Test Folder');
        expect(folderNode.isFolder, true);
        expect(folderNode.metadata['isFolder'], true);

        final loadedNode = await nodeRepository.load(folderNode.id);
        expect(loadedNode, isNotNull);
        expect(loadedNode!.id, folderNode.id);
        expect(loadedNode.title, 'Test Folder');
        expect(loadedNode.isFolder, true);
        expect(loadedNode.metadata['isFolder'], true);
      });

      test('应该将文件夹节点持久化到文件系统', () async {
        final folderNode = await nodeService.createNode(
          title: 'Persisted Folder',
          metadata: {'isFolder': true},
        );

        final filePath = nodeRepository.getNodeFilePath(folderNode.id);
        final file = File(filePath);

        expect(file.existsSync(), true);

        final content = await file.readAsString();
        expect(content, contains('id: ${folderNode.id}'));
        expect(content, contains('title: "Persisted Folder"'));
        expect(content, contains('isFolder: true'));
      });

      test('应该加载文件夹节点并保留所有属性', () async {
        final originalFolder = await nodeService.createNode(
          title: 'Complete Folder',
          content: 'Folder content',
          position: const Offset(150, 250),
          size: const Size(300, 400),
          color: '#FF5722',
          metadata: {
            'isFolder': true,
            'customKey': 'customValue',
            'tags': ['important', 'work'],
          },
        );

        final loadedFolder = await nodeRepository.load(originalFolder.id);

        expect(loadedFolder, isNotNull);
        expect(loadedFolder!.id, originalFolder.id);
        expect(loadedFolder.title, 'Complete Folder');
        expect(loadedFolder.content, 'Folder content');
        expect(loadedFolder.position.dx, 150);
        expect(loadedFolder.position.dy, 250);
        expect(loadedFolder.size.width, 300);
        expect(loadedFolder.size.height, 400);
        expect(loadedFolder.color, '#FF5722');
        expect(loadedFolder.metadata['isFolder'], true);
        expect(loadedFolder.metadata['customKey'], 'customValue');
      });
    });

    group('文件夹-节点关系持久化', () {
      test('应该持久化添加节点到文件夹时的引用关系', () async {
        final folder = await nodeService.createNode(
          title: 'Parent Folder',
          metadata: {'isFolder': true},
        );

        final childNode = await nodeService.createNode(
          title: 'Child Node',
          content: 'Content of child node',
        );

        await nodeService.connectNodes(
          fromNodeId: folder.id,
          toNodeId: childNode.id,
          properties: {'type': 'contains'},
        );

        final loadedFolder = await nodeRepository.load(folder.id);
        expect(loadedFolder, isNotNull);
        expect(loadedFolder!.references.containsKey(childNode.id), true);
        expect(loadedFolder.references[childNode.id]!.type, 'contains');
      });

      test('应该持久化文件夹中的多个子节点', () async {
        final folder = await nodeService.createNode(
          title: 'Multi-Child Folder',
          metadata: {'isFolder': true},
        );

        final children = <Node>[];
        for (var i = 0; i < 5; i++) {
          final child = await nodeService.createNode(
            title: 'Child Node $i',
          );
          children.add(child);
          await nodeService.connectNodes(
            fromNodeId: folder.id,
            toNodeId: child.id,
            properties: {'type': 'contains'},
          );
        }

        final loadedFolder = await nodeRepository.load(folder.id);
        expect(loadedFolder, isNotNull);
        expect(loadedFolder!.references.length, 5);

        for (final child in children) {
          expect(loadedFolder.references.containsKey(child.id), true);
        }
      });

      test('应该持久化从文件夹移除节点时的引用删除', () async {
        final folder = await nodeService.createNode(
          title: 'Removal Test Folder',
          metadata: {'isFolder': true},
        );

        final childNode = await nodeService.createNode(
          title: 'Node to Remove',
        );

        await nodeService.connectNodes(
          fromNodeId: folder.id,
          toNodeId: childNode.id,
          properties: {'type': 'contains'},
        );

        var loadedFolder = await nodeRepository.load(folder.id);
        expect(loadedFolder!.references.containsKey(childNode.id), true);

        await nodeService.disconnectNodes(
          fromNodeId: folder.id,
          toNodeId: childNode.id,
        );

        loadedFolder = await nodeRepository.load(folder.id);
        expect(loadedFolder!.references.containsKey(childNode.id), false);
      });

      test('应该保留重新加载后的引用属性', () async {
        final folder = await nodeService.createNode(
          title: 'Properties Folder',
          metadata: {'isFolder': true},
        );

        final childNode = await nodeService.createNode(
          title: 'Child with Properties',
        );

        await nodeService.connectNodes(
          fromNodeId: folder.id,
          toNodeId: childNode.id,
          properties: {
            'type': 'contains',
            'order': 1,
            'pinned': true,
            'customProperty': 'value',
          },
        );

        final loadedFolder = await nodeRepository.load(folder.id);
        final reference = loadedFolder!.references[childNode.id];

        expect(reference, isNotNull);
        expect(reference!.type, 'contains');
        expect(reference.properties['order'], 1);
        expect(reference.properties['pinned'], true);
        expect(reference.properties['customProperty'], 'value');
      });
    });

    group('文件夹状态加载', () {
      test('应该从仓库加载所有文件夹', () async {
        for (var i = 0; i < 3; i++) {
          await nodeService.createNode(
            title: 'Folder $i',
            metadata: {'isFolder': true},
          );
        }

        await nodeService.createNode(
          title: 'Regular Node',
        );

        final allNodes = await nodeRepository.queryAll();
        final folders = allNodes.where((n) => n.isFolder).toList();

        expect(folders.length, 3);
        expect(folders.every((f) => f.title.startsWith('Folder')), true);
      });

      test('应该正确识别文件夹和非文件夹节点', () async {
        final folder = await nodeService.createNode(
          title: 'Real Folder',
          metadata: {'isFolder': true},
        );

        final regularNode = await nodeService.createNode(
          title: 'Regular Node',
        );

        final loadedFolder = await nodeRepository.load(folder.id);
        final loadedRegular = await nodeRepository.load(regularNode.id);

        expect(loadedFolder!.isFolder, true);
        expect(loadedRegular!.isFolder, false);
      });

      test('应该正确处理空文件夹', () async {
        final emptyFolder = await nodeService.createNode(
          title: 'Empty Folder',
          metadata: {'isFolder': true},
        );

        final loadedFolder = await nodeRepository.load(emptyFolder.id);
        expect(loadedFolder, isNotNull);
        expect(loadedFolder!.references.isEmpty, true);
      });
    });

    group('节点在文件夹间移动', () {
      test('应该持久化节点从一个文件夹移动到另一个', () async {
        final folder1 = await nodeService.createNode(
          title: 'Source Folder',
          metadata: {'isFolder': true},
        );

        final folder2 = await nodeService.createNode(
          title: 'Target Folder',
          metadata: {'isFolder': true},
        );

        final node = await nodeService.createNode(
          title: 'Moving Node',
        );

        await nodeService.connectNodes(
          fromNodeId: folder1.id,
          toNodeId: node.id,
          properties: {'type': 'contains'},
        );

        var loadedFolder1 = await nodeRepository.load(folder1.id);
        expect(loadedFolder1!.references.containsKey(node.id), true);

        await nodeService.disconnectNodes(
          fromNodeId: folder1.id,
          toNodeId: node.id,
        );
        await nodeService.connectNodes(
          fromNodeId: folder2.id,
          toNodeId: node.id,
          properties: {'type': 'contains'},
        );

        loadedFolder1 = await nodeRepository.load(folder1.id);
        final loadedFolder2 = await nodeRepository.load(folder2.id);

        expect(loadedFolder1!.references.containsKey(node.id), false);
        expect(loadedFolder2!.references.containsKey(node.id), true);
      });

      test('应该处理节点同时存在于多个文件夹', () async {
        final folder1 = await nodeService.createNode(
          title: 'Folder 1',
          metadata: {'isFolder': true},
        );

        final folder2 = await nodeService.createNode(
          title: 'Folder 2',
          metadata: {'isFolder': true},
        );

        final node = await nodeService.createNode(
          title: 'Shared Node',
        );

        await nodeService.connectNodes(
          fromNodeId: folder1.id,
          toNodeId: node.id,
          properties: {'type': 'references'},
        );
        await nodeService.connectNodes(
          fromNodeId: folder2.id,
          toNodeId: node.id,
          properties: {'type': 'references'},
        );

        final loadedFolder1 = await nodeRepository.load(folder1.id);
        final loadedFolder2 = await nodeRepository.load(folder2.id);

        expect(loadedFolder1!.references.containsKey(node.id), true);
        expect(loadedFolder2!.references.containsKey(node.id), true);
      });
    });

    group('文件夹层级持久化', () {
      test('应该持久化嵌套文件夹结构', () async {
        final rootFolder = await nodeService.createNode(
          title: 'Root Folder',
          metadata: {'isFolder': true},
        );

        final subFolder = await nodeService.createNode(
          title: 'Sub Folder',
          metadata: {'isFolder': true},
        );

        final leafNode = await nodeService.createNode(
          title: 'Leaf Node',
        );

        await nodeService.connectNodes(
          fromNodeId: rootFolder.id,
          toNodeId: subFolder.id,
          properties: {'type': 'contains'},
        );

        await nodeService.connectNodes(
          fromNodeId: subFolder.id,
          toNodeId: leafNode.id,
          properties: {'type': 'contains'},
        );

        final loadedRoot = await nodeRepository.load(rootFolder.id);
        final loadedSub = await nodeRepository.load(subFolder.id);

        expect(loadedRoot!.references.containsKey(subFolder.id), true);
        expect(loadedSub!.references.containsKey(leafNode.id), true);
      });

      test('应该持久化深层文件夹层级', () async {
        final folders = <Node>[];
        const depth = 5;

        for (var i = 0; i < depth; i++) {
          final folder = await nodeService.createNode(
            title: 'Level $i Folder',
            metadata: {'isFolder': true},
          );
          folders.add(folder);

          if (i > 0) {
            await nodeService.connectNodes(
              fromNodeId: folders[i - 1].id,
              toNodeId: folder.id,
              properties: {'type': 'contains'},
            );
          }
        }

        for (var i = 0; i < depth - 1; i++) {
          final loadedFolder = await nodeRepository.load(folders[i].id);
          expect(loadedFolder!.references.containsKey(folders[i + 1].id), true);
        }
      });

      test('应该正确计算文件夹层级中的节点深度', () async {
        final rootFolder = await nodeService.createNode(
          title: 'Root',
          metadata: {'isFolder': true},
        );

        final subFolder = await nodeService.createNode(
          title: 'Sub',
          metadata: {'isFolder': true},
        );

        final leafNode = await nodeService.createNode(
          title: 'Leaf',
        );

        await nodeService.connectNodes(
          fromNodeId: rootFolder.id,
          toNodeId: subFolder.id,
          properties: {'type': 'contains'},
        );
        await nodeService.connectNodes(
          fromNodeId: subFolder.id,
          toNodeId: leafNode.id,
          properties: {'type': 'contains'},
        );

        final allNodes = await nodeRepository.queryAll();
        final depths = await nodeService.calculateNodeDepths(allNodes);

        expect(depths[rootFolder.id], 0);
        expect(depths[subFolder.id], 1);
        expect(depths[leafNode.id], 2);
      });
    });

    group('文件夹节点更新持久化', () {
      test('应该持久化文件夹标题更新', () async {
        final folder = await nodeService.createNode(
          title: 'Original Title',
          metadata: {'isFolder': true},
        );

        await nodeService.updateNode(
          folder.id,
          title: 'Updated Title',
        );

        final loadedFolder = await nodeRepository.load(folder.id);
        expect(loadedFolder!.title, 'Updated Title');
        expect(loadedFolder.isFolder, true);
      });

      test('应该持久化文件夹元数据更新', () async {
        final folder = await nodeService.createNode(
          title: 'Metadata Test Folder',
          metadata: {'isFolder': true, 'initialKey': 'initialValue'},
        );

        await nodeService.updateNode(
          folder.id,
          metadata: {
            'isFolder': true,
            'newKey': 'newValue',
            'tags': ['updated'],
          },
        );

        final loadedFolder = await nodeRepository.load(folder.id);
        expect(loadedFolder!.metadata['isFolder'], true);
        expect(loadedFolder.metadata['newKey'], 'newValue');
      });

      test('应该持久化文件夹内容更新', () async {
        final folder = await nodeService.createNode(
          title: 'Content Folder',
          content: 'Initial content',
          metadata: {'isFolder': true},
        );

        await nodeService.updateNode(
          folder.id,
          content: 'Updated content with more details',
        );

        final loadedFolder = await nodeRepository.load(folder.id);
        expect(loadedFolder!.content, 'Updated content with more details');
      });
    });

    group('文件夹删除和清理', () {
      test('应该删除文件夹并保留子节点', () async {
        final folder = await nodeService.createNode(
          title: 'Folder to Delete',
          metadata: {'isFolder': true},
        );

        final childNode = await nodeService.createNode(
          title: 'Orphaned Child',
        );

        await nodeService.connectNodes(
          fromNodeId: folder.id,
          toNodeId: childNode.id,
          properties: {'type': 'contains'},
        );

        await nodeService.deleteNode(folder.id);

        final deletedFolder = await nodeRepository.load(folder.id);
        expect(deletedFolder, isNull);

        final survivingChild = await nodeRepository.load(childNode.id);
        expect(survivingChild, isNotNull);
        expect(survivingChild!.title, 'Orphaned Child');
      });

      test('应该处理包含多个子节点的文件夹删除', () async {
        final folder = await nodeService.createNode(
          title: 'Multi-Child Folder',
          metadata: {'isFolder': true},
        );

        final children = <String>[];
        for (var i = 0; i < 3; i++) {
          final child = await nodeService.createNode(
            title: 'Child $i',
          );
          children.add(child.id);
          await nodeService.connectNodes(
            fromNodeId: folder.id,
            toNodeId: child.id,
            properties: {'type': 'contains'},
          );
        }

        await nodeService.deleteNode(folder.id);

        for (final childId in children) {
          final child = await nodeRepository.load(childId);
          expect(child, isNotNull);
        }
      });
    });

    group('边缘情况和错误处理', () {
      test('应该优雅地处理文件夹自引用', () async {
        final folder = await nodeService.createNode(
          title: 'Self-Referencing Folder',
          metadata: {'isFolder': true},
        );

        await nodeService.connectNodes(
          fromNodeId: folder.id,
          toNodeId: folder.id,
          properties: {'type': 'contains'},
        );

        final loadedFolder = await nodeRepository.load(folder.id);
        expect(loadedFolder!.references.containsKey(folder.id), true);
        expect(loadedFolder.references[folder.id]!.type, 'contains');
      });

      test('应该处理加载不存在的文件夹', () async {
        final nonExistentFolder = await nodeRepository.load('non-existent-id');
        expect(nonExistentFolder, isNull);
      });

      test('应该处理标题包含特殊字符的文件夹', () async {
        final specialTitle = 'Folder: "Test" & <Special> / \\ Characters';
        final folder = await nodeService.createNode(
          title: specialTitle,
          metadata: {'isFolder': true},
        );

        final loadedFolder = await nodeRepository.load(folder.id);
        expect(loadedFolder!.title, specialTitle);
      });

      test('应该处理标题包含Unicode字符的文件夹', () async {
        final unicodeTitle = '文件夹 📁 文書フォルダ';
        final folder = await nodeService.createNode(
          title: unicodeTitle,
          metadata: {'isFolder': true},
        );

        final loadedFolder = await nodeRepository.load(folder.id);
        expect(loadedFolder!.title, unicodeTitle);
      });

      test('应该正确处理顺序文件夹操作', () async {
        final folder = await nodeService.createNode(
          title: 'Sequential Test Folder',
          metadata: {'isFolder': true},
        );

        for (var i = 0; i < 10; i++) {
          final child = await nodeService.createNode(title: 'Sequential Child $i');
          await nodeService.connectNodes(
            fromNodeId: folder.id,
            toNodeId: child.id,
            properties: {'type': 'contains'},
          );
        }

        final loadedFolder = await nodeRepository.load(folder.id);
        expect(loadedFolder!.references.length, 10);
      });

      test('应该处理批量文件夹操作', () async {
        final folder = await nodeService.createNode(
          title: 'Batch Test Folder',
          metadata: {'isFolder': true},
        );

        final children = <Node>[];
        for (var i = 0; i < 5; i++) {
          children.add(await nodeService.createNode(title: 'Batch Child $i'));
        }

        var currentFolder = folder;
        for (final child in children) {
          final newReferences = Map<String, NodeReference>.from(currentFolder.references);
          newReferences[child.id] = NodeReference(nodeId: child.id, properties: {'type': 'contains'});
          currentFolder = await nodeService.updateNode(
            folder.id,
            references: newReferences,
          );
        }

        final loadedFolder = await nodeRepository.load(folder.id);
        expect(loadedFolder!.references.length, 5);
      });
    });

    group('元数据索引持久化', () {
      test('应该在创建文件夹时更新元数据索引', () async {
        final folder = await nodeService.createNode(
          title: 'Indexed Folder',
          metadata: {'isFolder': true},
        );

        final index = await nodeRepository.getMetadataIndex();
        final folderMetadata = index.nodes.firstWhere(
          (n) => n.id == folder.id,
          orElse: () => throw Exception('Folder not found in index'),
        );

        expect(folderMetadata.id, folder.id);
        expect(folderMetadata.title, 'Indexed Folder');
      });

      test('应该在更新文件夹时更新元数据索引', () async {
        final folder = await nodeService.createNode(
          title: 'Original Title',
          metadata: {'isFolder': true},
        );

        await nodeService.updateNode(folder.id, title: 'Updated Title');

        final index = await nodeRepository.getMetadataIndex();
        final folderMetadata = index.nodes.firstWhere(
          (n) => n.id == folder.id,
        );

        expect(folderMetadata.title, 'Updated Title');
      });

      test('应该从文件系统删除文件夹文件', () async {
        final folder = await nodeService.createNode(
          title: 'Folder to Delete',
          metadata: {'isFolder': true},
        );

        final filePath = nodeRepository.getNodeFilePath(folder.id);
        expect(File(filePath).existsSync(), true);

        await nodeService.deleteNode(folder.id);

        expect(File(filePath).existsSync(), false);
        final loadedFolder = await nodeRepository.load(folder.id);
        expect(loadedFolder, isNull);
      });

      test('应该处理文件夹删除后的索引清理', () async {
        final folder = await nodeService.createNode(
          title: 'Folder for Index Test',
          metadata: {'isFolder': true},
        );

        var index = await nodeRepository.getMetadataIndex();
        expect(index.nodes.any((n) => n.id == folder.id), true);

        await nodeService.deleteNode(folder.id);

        final allNodes = await nodeRepository.queryAll();
        expect(allNodes.any((n) => n.id == folder.id), false);
      });
    });
  });
}
