import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/models/graph.dart';
import 'package:node_graph_notebook/core/repositories/exceptions.dart';
import 'package:node_graph_notebook/core/repositories/graph_repository.dart';
import 'package:path/path.dart' as path;

void main() {
  group('FileSystemGraphRepository - 文件系统图谱仓库', () {
    late FileSystemGraphRepository repository;
    late String testDir;

    setUp(() async {
      testDir = Directory.systemTemp.createTempSync('test_graphs_').path;
      repository = FileSystemGraphRepository(graphsDir: testDir);
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
        final newDir = Directory.systemTemp.createTempSync('test_new_graphs_').path;
        final newRepo = FileSystemGraphRepository(graphsDir: newDir);

        await newRepo.init();

        expect(Directory(newDir).existsSync(), true);

        await Directory(newDir).delete(recursive: true);
      });
    });

    group('save - 保存', () {
      test('应该成功保存图谱', () async {
        final graph = Graph(
          id: 'graph_1',
          name: 'Test Graph',
          nodeIds: ['node_1', 'node_2'],
          nodePositions: {
            'node_1': const Offset(100, 200),
            'node_2': const Offset(300, 400),
          },
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);

        final file = File(path.join(testDir, 'graph_1.json'));
        expect(file.existsSync(), true);
      });

      test('应该更新已存在的图谱', () async {
        final graph = Graph(
          id: 'graph_1',
          name: 'Test Graph',
          nodeIds: ['node_1'],
          nodePositions: {'node_1': const Offset(100, 200)},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);

        final updatedGraph = graph.copyWith(
          name: 'Updated Graph',
          nodeIds: ['node_1', 'node_2'],
          nodePositions: {
            'node_1': const Offset(100, 200),
            'node_2': const Offset(300, 400),
          },
        );

        await repository.save(updatedGraph);

        final loaded = await repository.load('graph_1');
        expect(loaded?.name, 'Updated Graph');
        expect(loaded?.nodeIds.length, 2);
      });

      test('保存时如果目录不存在应该创建目录', () async {
        final newDir = Directory.systemTemp.createTempSync('test_save_dir_').path;
        final newRepo = FileSystemGraphRepository(graphsDir: path.join(newDir, 'graphs'));

        final graph = Graph(
          id: 'graph_1',
          name: 'Test Graph',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await newRepo.save(graph);

        expect(Directory(path.join(newDir, 'graphs')).existsSync(), true);

        await Directory(newDir).delete(recursive: true);
      });
    });

    group('load - 加载', () {
      test('应该成功加载图谱', () async {
        final graph = Graph(
          id: 'graph_1',
          name: 'Test Graph',
          nodeIds: ['node_1', 'node_2'],
          nodePositions: {
            'node_1': const Offset(100, 200),
            'node_2': const Offset(300, 400),
          },
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);
        final loaded = await repository.load('graph_1');

        expect(loaded, isNotNull);
        expect(loaded!.id, 'graph_1');
        expect(loaded.name, 'Test Graph');
        expect(loaded.nodeIds, ['node_1', 'node_2']);
      });

      test('如果图谱不存在应该返回null', () async {
        final loaded = await repository.load('non_existent');
        expect(loaded, isNull);
      });

      test('对于空文件应该返回null', () async {
        final file = File(path.join(testDir, 'empty_graph.json'));
        await file.writeAsString('');

        final loaded = await repository.load('empty_graph');
        expect(loaded, isNull);
      });

      test('对于仅包含空白字符的文件应该返回null', () async {
        final file = File(path.join(testDir, 'whitespace_graph.json'));
        await file.writeAsString('   \n   \t   ');

        final loaded = await repository.load('whitespace_graph');
        expect(loaded, isNull);
      });

      test('对于损坏的文件应该抛出RepositoryException', () async {
        final file = File(path.join(testDir, 'corrupted_graph.json'));
        await file.writeAsString('invalid json {{{');

        expect(() async => repository.load('corrupted_graph'), throwsA(isA<RepositoryException>()));
      });
    });

    group('delete - 删除', () {
      test('应该成功删除图谱', () async {
        final graph = Graph(
          id: 'graph_1',
          name: 'Test Graph',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);
        await repository.delete('graph_1');

        final loaded = await repository.load('graph_1');
        expect(loaded, isNull);
      });

      test('删除不存在的图谱时不应该抛出错误', () async {
        await repository.delete('non_existent');
      });

      test('如果删除的是当前图谱应该清空当前图谱', () async {
        final graph = Graph(
          id: 'graph_1',
          name: 'Test Graph',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);
        await repository.setCurrent('graph_1');
        await repository.delete('graph_1');

        final current = await repository.getCurrent();
        expect(current, isNull);
      });
    });

    group('getAll - 获取全部', () {
      test('当没有图谱存在时应该返回空列表', () async {
        final graphs = await repository.getAll();
        expect(graphs, isEmpty);
      });

      test('应该返回所有图谱', () async {
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

        final graphs = await repository.getAll();
        expect(graphs.length, 2);
        expect(graphs.any((g) => g.id == 'graph_1'), true);
        expect(graphs.any((g) => g.id == 'graph_2'), true);
      });

      test('应该跳过current.json文件', () async {
        final graph = Graph(
          id: 'graph_1',
          name: 'Test Graph',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);
        await repository.setCurrent('graph_1');

        final graphs = await repository.getAll();
        expect(graphs.length, 1);
        expect(graphs[0].id, 'graph_1');
      });

      test('应该优雅地处理损坏的文件', () async {
        final validGraph = Graph(
          id: 'graph_1',
          name: 'Valid Graph',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(validGraph);

        final corruptedFile = File(path.join(testDir, 'corrupted.json'));
        await corruptedFile.writeAsString('invalid json');

        final graphs = await repository.getAll();
        expect(graphs.length, 1);
        expect(graphs[0].id, 'graph_1');
      });

      test('如果目录不存在应该创建目录', () async {
        final newDir = Directory.systemTemp.createTempSync('test_getall_dir_').path;
        final newRepo = FileSystemGraphRepository(graphsDir: path.join(newDir, 'graphs'));

        final graphs = await newRepo.getAll();
        expect(graphs, isEmpty);
        expect(Directory(path.join(newDir, 'graphs')).existsSync(), true);

        await Directory(newDir).delete(recursive: true);
      });
    });

    group('getCurrent - 获取当前图谱', () {
      test('当没有设置当前图谱时应该返回null', () async {
        final current = await repository.getCurrent();
        expect(current, isNull);
      });

      test('应该返回当前图谱', () async {
        final graph = Graph(
          id: 'graph_1',
          name: 'Test Graph',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);
        await repository.setCurrent('graph_1');

        final current = await repository.getCurrent();
        expect(current, isNotNull);
        expect(current!.id, 'graph_1');
      });

      test('如果没有设置当前图谱应该默认返回第一个图谱', () async {
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
        expect(current!.id, 'graph_1');
      });

      test('如果当前图谱被删除应该清空当前图谱', () async {
        final graph = Graph(
          id: 'graph_1',
          name: 'Test Graph',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);
        await repository.setCurrent('graph_1');
        await repository.delete('graph_1');

        final current = await repository.getCurrent();
        expect(current, isNull);
      });

      test('应该优雅地处理损坏的current.json', () async {
        final graph = Graph(
          id: 'graph_1',
          name: 'Test Graph',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);
        await repository.setCurrent('graph_1');

        final currentFile = File(path.join(testDir, 'current.json'));
        await currentFile.writeAsString('corrupted data');

        final current = await repository.getCurrent();
        expect(current, isNotNull);
      });
    });

    group('setCurrent - 设置当前图谱', () {
      test('应该成功设置当前图谱', () async {
        final graph = Graph(
          id: 'graph_1',
          name: 'Test Graph',
          nodeIds: [],
          nodePositions: {},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);
        await repository.setCurrent('graph_1');

        final current = await repository.getCurrent();
        expect(current, isNotNull);
        expect(current!.id, 'graph_1');
      });

      test('应该创建current.json文件', () async {
        await repository.setCurrent('graph_1');

        final currentFile = File(path.join(testDir, 'current.json'));
        expect(currentFile.existsSync(), true);
      });
    });

    group('export - 导出', () {
      test('应该成功导出图谱到文件', () async {
        final graph = Graph(
          id: 'graph_1',
          name: 'Test Graph',
          nodeIds: ['node_1'],
          nodePositions: {'node_1': const Offset(100, 200)},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.save(graph);

        final exportPath = path.join(Directory.systemTemp.path, 'exported_graph.json');
        await repository.export('graph_1', exportPath);

        final exportFile = File(exportPath);
        expect(exportFile.existsSync(), true);

        await exportFile.delete();
      });

      test('如果图谱不存在应该抛出RepositoryException', () async {
        final exportPath = path.join(Directory.systemTemp.path, 'exported_graph.json');

        expect(() async => repository.export('non_existent', exportPath), throwsA(isA<RepositoryException>()));
      });
    });

    group('import - 导入', () {
      test('应该成功从文件导入图谱', () async {
        final graph = Graph(
          id: 'graph_1',
          name: 'Test Graph',
          nodeIds: ['node_1'],
          nodePositions: {'node_1': const Offset(100, 200)},
          viewConfig: GraphViewConfig.defaultConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final importPath = path.join(Directory.systemTemp.path, 'import_graph.json');
        final importFile = File(importPath);
        await importFile.writeAsString(_encodeJson(graph.toJson()));

        final imported = await repository.import(importPath);

        expect(imported, isNotNull);
        expect(imported.name, 'Test Graph');
        expect(imported.id, isNot('graph_1'));

        await importFile.delete();
      });

      test('如果文件不存在应该抛出RepositoryException', () async {
        final importPath = path.join(Directory.systemTemp.path, 'non_existent.json');

        expect(() async => repository.import(importPath), throwsA(isA<RepositoryException>()));
      });

      test('对于损坏的文件应该抛出RepositoryException', () async {
        final importPath = path.join(Directory.systemTemp.path, 'corrupted_${DateTime.now().millisecondsSinceEpoch}.json');
        final importFile = File(importPath);
        await importFile.writeAsString('invalid json {{{');

        expect(() async => repository.import(importPath), throwsA(isA<RepositoryException>()));

        try {
          await importFile.delete();
        } catch (_) {}
      });
    });

    group('createDefaultGraph - 创建默认图谱', () {
      test('应该创建默认图谱', () async {
        final defaultGraph = await repository.createDefaultGraph();

        expect(defaultGraph, isNotNull);
        expect(defaultGraph.name, 'My First Graph');
        expect(defaultGraph.nodeIds, isEmpty);
        expect(defaultGraph.nodePositions, isEmpty);
      });

      test('应该将默认图谱设置为当前图谱', () async {
        final defaultGraph = await repository.createDefaultGraph();

        final current = await repository.getCurrent();
        expect(current, isNotNull);
        expect(current!.id, defaultGraph.id);
      });

      test('应该将默认图谱保存到存储', () async {
        final defaultGraph = await repository.createDefaultGraph();

        final loaded = await repository.load(defaultGraph.id);
        expect(loaded, isNotNull);
        expect(loaded!.id, defaultGraph.id);
      });
    });

    group('integration tests - 集成测试', () {
      test('应该处理完整的工作流', () async {
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

        final allGraphs = await repository.getAll();
        expect(allGraphs.length, 2);

        await repository.setCurrent('graph_1');
        var current = await repository.getCurrent();
        expect(current!.id, 'graph_1');

        await repository.setCurrent('graph_2');
        current = await repository.getCurrent();
        expect(current!.id, 'graph_2');

        await repository.delete('graph_1');
        final remainingGraphs = await repository.getAll();
        expect(remainingGraphs.length, 1);
        expect(remainingGraphs[0].id, 'graph_2');
      });
    });
  });
}

String _encodeJson(Map<String, dynamic> json) => jsonEncode(json);