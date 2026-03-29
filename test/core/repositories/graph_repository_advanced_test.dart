import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/graph.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/models/node_reference.dart';
import 'package:node_graph_notebook/core/repositories/exceptions.dart';
import 'package:node_graph_notebook/core/repositories/graph_repository.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:path/path.dart' as path;

void main() {
  group('FileSystemGraphRepository Advanced Tests - 文件系统图谱仓库高级测试', () {
    late FileSystemGraphRepository repository;
    late String testDir;

    setUp(() async {
      testDir = Directory.systemTemp.createTempSync('test_graphs_advanced_').path;
      repository = FileSystemGraphRepository(graphsDir: testDir);
      await repository.init();
    });

    tearDown(() async {
      final dir = Directory(testDir);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    });

    group('concurrent operations - 并发操作', () {
      test('应该处理对同一图谱的并发保存', () async {
        final graph = Graph(
          id: 'concurrent_graph',
          name: 'Original',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);

        final futures = List.generate(5, (i) async {
          final updatedGraph = graph.copyWith(
            name: 'Update $i',
            nodeIds: ['node_$i'],
            updatedAt: DateTime.now(),
          );
          await repository.save(updatedGraph);
        });

        await Future.wait(futures);

        final loaded = await repository.load('concurrent_graph');
        expect(loaded, isNotNull);
        expect(loaded!.id, 'concurrent_graph');
      });

      test('应该处理对不同图谱的并发保存', () async {
        final graphs = List.generate(10, (i) => Graph(
          id: 'graph_$i',
          name: 'Graph $i',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        await Future.wait(graphs.map((g) => repository.save(g)));

        final allGraphs = await repository.getAll();
        expect(allGraphs.length, 10);
      });

      test('应该处理并发当前图谱更新', () async {
        final graphs = List.generate(3, (i) => Graph(
          id: 'current_graph_$i',
          name: 'Graph $i',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        for (final g in graphs) {
          await repository.save(g);
        }

        await Future.wait([
          repository.setCurrent('current_graph_0'),
          repository.setCurrent('current_graph_1'),
          repository.setCurrent('current_graph_2'),
        ]);

        final current = await repository.getCurrent();
        expect(current, isNotNull);
        expect(
          ['current_graph_0', 'current_graph_1', 'current_graph_2'].contains(current!.id),
          true,
        );
      });
    });

    group('data recovery scenarios - 数据恢复场景', () {
      test('应该从损坏的current.json中恢复', () async {
        final graph = Graph(
          id: 'recovery_graph',
          name: 'Recovery Test',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);
        await repository.setCurrent('recovery_graph');

        final currentFile = File(path.join(testDir, 'current.json'));
        await currentFile.writeAsString('corrupted {{{ json');

        final current = await repository.getCurrent();
        expect(current, isNotNull);
        expect(current!.id, 'recovery_graph');
      });

      test('应该优雅地处理缺少current.json的情况', () async {
        final graph1 = Graph(
          id: 'graph_1',
          name: 'Graph 1',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final graph2 = Graph(
          id: 'graph_2',
          name: 'Graph 2',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph1);
        await repository.save(graph2);

        final current = await repository.getCurrent();
        expect(current, isNotNull);
        expect(['graph_1', 'graph_2'].contains(current!.id), true);
      });

      test('应该处理当前图谱文件被删除的情况', () async {
        final graph = Graph(
          id: 'deleted_graph',
          name: 'Deleted Graph',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);
        await repository.setCurrent('deleted_graph');

        final graphFile = File(path.join(testDir, 'deleted_graph.json'));
        await graphFile.delete();

        final current = await repository.getCurrent();
        expect(current, isNull);
      });

      test('应该处理部分写入的图谱文件', () async {
        final graph = Graph(
          id: 'partial_graph',
          name: 'Partial Graph',
          nodeIds: ['node_1'],
          nodePositions: {'node_1': const Offset(100, 200)},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);

        final graphFile = File(path.join(testDir, 'partial_graph.json'));
        await graphFile.writeAsString('{"id": "partial_graph", "name": "incomplete');

        expect(
          () async => repository.load('partial_graph'),
          throwsA(isA<RepositoryException>()),
        );
      });
    });

    group('import export scenarios - 导入导出场景', () {
      test('应该导入具有不同ID的图谱', () async {
        final originalGraph = Graph(
          id: 'original_id',
          name: 'Original Graph',
          nodeIds: ['node_1', 'node_2'],
          nodePositions: {
            'node_1': const Offset(100, 200),
            'node_2': const Offset(300, 400),
          },
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final importPath = path.join(testDir, 'import_test.json');
        final importFile = File(importPath);
        await importFile.writeAsString(jsonEncode(originalGraph.toJson()));

        final imported = await repository.import(importPath);

        expect(imported.id, isNot('original_id'));
        expect(imported.name, 'Original Graph');
        expect(imported.nodeIds, ['node_1', 'node_2']);

        final loaded = await repository.load(imported.id);
        expect(loaded, isNotNull);
      });

      test('应该导出并重新导入图谱保持数据完整性', () async {
        final graph = Graph(
          id: 'export_test',
          name: 'Export Test',
          nodeIds: ['node_1'],
          nodePositions: {'node_1': const Offset(100, 200)},
          viewConfig: GraphViewConfig.defaultConfig.copyWith(
            camera: const Camera(x: 50, y: 100, zoom: 1.5),
          ),
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        await repository.save(graph);

        final exportPath = path.join(testDir, 'exported.json');
        await repository.export('export_test', exportPath);

        final imported = await repository.import(exportPath);

        expect(imported.name, graph.name);
        expect(imported.nodeIds, graph.nodeIds);
        expect(imported.nodePositions['node_1']?.dx, 100);
        expect(imported.viewConfig.camera.zoom, 1.5);
        expect(imported.viewConfig.camera.x, 50.0);

        await File(exportPath).delete();
      });

      test('对于不存在的图谱导出应该抛出RepositoryException', () async {
        final exportPath = path.join(testDir, 'non_existent_export.json');

        expect(
          () async => repository.export('non_existent', exportPath),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('对于不存在的导入文件应该抛出RepositoryException', () async {
        expect(
          () async => repository.import('/non/existent/path.json'),
          throwsA(isA<RepositoryException>()),
        );
      });
    });

    group('view config handling - 视图配置处理', () {
      test('应该在保存和加载后保留视图配置', () async {
        final graph = Graph(
          id: 'view_config_graph',
          name: 'View Config Test',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig.copyWith(
            camera: const Camera(x: -100, y: 200, zoom: 2),
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);
        final loaded = await repository.load('view_config_graph');

        expect(loaded, isNotNull);
        expect(loaded!.viewConfig.camera.zoom, 2.0);
        expect(loaded.viewConfig.camera.x, -100.0);
        expect(loaded.viewConfig.camera.y, 200.0);
      });

      test('应该处理默认视图配置', () async {
        final graph = Graph(
          id: 'default_view_config',
          name: 'Default View Config',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);
        final loaded = await repository.load('default_view_config');

        expect(loaded, isNotNull);
        expect(loaded!.viewConfig.camera.zoom, GraphViewConfig.defaultConfig.camera.zoom);
      });
    });

    group('node positions handling - 节点位置处理', () {
      test('应该处理大量节点位置', () async {
        final nodePositions = <String, Offset>{};
        for (var i = 0; i < 1000; i++) {
          nodePositions['node_$i'] = Offset(i * 10.0, i * 20.0);
        }

        final graph = Graph(
          id: 'large_positions_graph',
          name: 'Large Positions',
          nodeIds: nodePositions.keys.toList(),
          nodePositions: nodePositions,
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);
        final loaded = await repository.load('large_positions_graph');

        expect(loaded, isNotNull);
        expect(loaded!.nodePositions.length, 1000);
        expect(loaded.nodePositions['node_500']?.dx, 5000.0);
      });

      test('应该处理负坐标位置', () async {
        final graph = Graph(
          id: 'negative_positions',
          name: 'Negative Positions',
          nodeIds: ['node_1', 'node_2'],
          nodePositions: {
            'node_1': const Offset(-100, -200),
            'node_2': const Offset(-500, -600),
          },
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);
        final loaded = await repository.load('negative_positions');

        expect(loaded, isNotNull);
        expect(loaded!.nodePositions['node_1']?.dx, -100);
        expect(loaded.nodePositions['node_2']?.dy, -600);
      });
    });
  });

  group('GraphRepository and NodeRepository Integration Tests - 图谱仓库和节点仓库集成测试', () {
    late FileSystemGraphRepository graphRepository;
    late FileSystemNodeRepository nodeRepository;
    late String testDir;

    setUp(() async {
      testDir = Directory.systemTemp.createTempSync('test_integration_').path;
      graphRepository = FileSystemGraphRepository(graphsDir: path.join(testDir, 'graphs'));
      nodeRepository = FileSystemNodeRepository(nodesDir: path.join(testDir, 'nodes'));
      await graphRepository.init();
      await nodeRepository.init();
    });

    tearDown(() async {
      final dir = Directory(testDir);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    });

    test('应该保持图谱nodeIds与实际节点之间的一致性', () async {
      final node1 = Node(
        id: 'integration_node_1',
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
        id: 'integration_node_2',
        title: 'Node 2',
        content: 'Content 2',
        references: {
          'integration_node_1': const NodeReference(
            nodeId: 'integration_node_1',
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

      await nodeRepository.save(node1);
      await nodeRepository.save(node2);

      final graph = Graph(
        id: 'integration_graph',
        name: 'Integration Graph',
        nodeIds: ['integration_node_1', 'integration_node_2'],
        nodePositions: {
          'integration_node_1': const Offset(100, 200),
          'integration_node_2': const Offset(300, 400),
        },
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await graphRepository.save(graph);

      final loadedGraph = await graphRepository.load('integration_graph');
      expect(loadedGraph, isNotNull);
      expect(loadedGraph!.nodeIds.length, 2);

      final loadedNodes = await nodeRepository.loadAll(loadedGraph.nodeIds);
      expect(loadedNodes.length, 2);
      expect(loadedNodes.any((n) => n.id == 'integration_node_1'), true);
      expect(loadedNodes.any((n) => n.id == 'integration_node_2'), true);
    });

    test('应该处理节点在图谱中被引用时的删除情况', () async {
      final node = Node(
        id: 'deletable_node',
        title: 'Deletable Node',
        content: 'Content',
        references: const {},
        position: const Offset(100, 200),
        size: const Size(300, 400),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      await nodeRepository.save(node);

      final graph = Graph(
        id: 'graph_with_deleted_node',
        name: 'Graph with Deleted Node',
        nodeIds: ['deletable_node'],
        nodePositions: {'deletable_node': const Offset(100, 200)},
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await graphRepository.save(graph);

      await nodeRepository.delete('deletable_node');

      final loadedGraph = await graphRepository.load('graph_with_deleted_node');
      expect(loadedGraph, isNotNull);
      expect(loadedGraph!.nodeIds, contains('deletable_node'));

      final loadedNodes = await nodeRepository.loadAll(loadedGraph.nodeIds);
      expect(loadedNodes, isEmpty);
    });

    test('应该处理节点具有交叉引用的图谱', () async {
      final node1 = Node(
        id: 'cross_ref_1',
        title: 'Node 1',
        content: 'Content 1',
        references: {
          'cross_ref_2': const NodeReference(
            nodeId: 'cross_ref_2',
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
        id: 'cross_ref_2',
        title: 'Node 2',
        content: 'Content 2',
        references: {
          'cross_ref_1': const NodeReference(
            nodeId: 'cross_ref_1',
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

      await nodeRepository.saveAll([node1, node2]);

      final graph = Graph(
        id: 'cross_ref_graph',
        name: 'Cross Reference Graph',
        nodeIds: ['cross_ref_1', 'cross_ref_2'],
        nodePositions: {
          'cross_ref_1': const Offset(100, 200),
          'cross_ref_2': const Offset(300, 400),
        },
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await graphRepository.save(graph);

      final loadedNodes = await nodeRepository.loadAll(['cross_ref_1', 'cross_ref_2']);
      expect(loadedNodes.length, 2);

      final node1Loaded = loadedNodes.firstWhere((n) => n.id == 'cross_ref_1');
      final node2Loaded = loadedNodes.firstWhere((n) => n.id == 'cross_ref_2');

      expect(node1Loaded.references['cross_ref_2'], isNotNull);
      expect(node2Loaded.references['cross_ref_1'], isNotNull);
    });

    test('应该处理完整工作流：创建节点、创建图谱、更新、删除', () async {
      final nodes = List.generate(5, (i) => Node(
        id: 'workflow_node_$i',
        title: 'Workflow Node $i',
        content: 'Content $i',
        references: const {},
        position: Offset(i * 100.0, i * 100.0),
        size: const Size(300, 400),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      ));

      await nodeRepository.saveAll(nodes);

      var graph = Graph(
        id: 'workflow_graph',
        name: 'Workflow Graph',
        nodeIds: nodes.map((n) => n.id).toList(),
        nodePositions: {for (var n in nodes) n.id: n.position},
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await graphRepository.save(graph);

      var loadedGraph = await graphRepository.load('workflow_graph');
      expect(loadedGraph!.nodeIds.length, 5);

      await nodeRepository.delete('workflow_node_0');
      graph = graph.copyWith(
        nodeIds: graph.nodeIds.where((id) => id != 'workflow_node_0').toList(),
      );
      await graphRepository.save(graph);

      loadedGraph = await graphRepository.load('workflow_graph');
      expect(loadedGraph!.nodeIds.length, 4);
      expect(loadedGraph.nodeIds.contains('workflow_node_0'), false);

      final remainingNodes = await nodeRepository.queryAll();
      expect(remainingNodes.length, 4);
    });
  });
}
