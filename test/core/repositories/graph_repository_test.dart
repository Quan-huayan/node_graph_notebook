import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/models/graph.dart';
import 'package:node_graph_notebook/core/repositories/exceptions.dart';
import 'package:node_graph_notebook/core/repositories/graph_repository.dart';
import 'package:path/path.dart' as path;

void main() {
  group('FileSystemGraphRepository', () {
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

    group('init', () {
      test('should create directory if it does not exist', () async {
        final newDir = Directory.systemTemp.createTempSync('test_new_graphs_').path;
        final newRepo = FileSystemGraphRepository(graphsDir: newDir);

        await newRepo.init();

        expect(Directory(newDir).existsSync(), true);

        await Directory(newDir).delete(recursive: true);
      });
    });

    group('save', () {
      test('should save a graph successfully', () async {
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

      test('should update existing graph', () async {
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

      test('should create directory if it does not exist when saving', () async {
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

    group('load', () {
      test('should load a graph successfully', () async {
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

      test('should return null if graph does not exist', () async {
        final loaded = await repository.load('non_existent');
        expect(loaded, isNull);
      });

      test('should return null for empty file', () async {
        final file = File(path.join(testDir, 'empty_graph.json'));
        await file.writeAsString('');

        final loaded = await repository.load('empty_graph');
        expect(loaded, isNull);
      });

      test('should return null for whitespace-only file', () async {
        final file = File(path.join(testDir, 'whitespace_graph.json'));
        await file.writeAsString('   \n   \t   ');

        final loaded = await repository.load('whitespace_graph');
        expect(loaded, isNull);
      });

      test('should throw RepositoryException for corrupted file', () async {
        final file = File(path.join(testDir, 'corrupted_graph.json'));
        await file.writeAsString('invalid json {{{');

        expect(() async => repository.load('corrupted_graph'), throwsA(isA<RepositoryException>()));
      });
    });

    group('delete', () {
      test('should delete a graph successfully', () async {
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

      test('should not throw error when deleting non-existent graph', () async {
        await repository.delete('non_existent');
      });

      test('should clear current graph if deleted graph is current', () async {
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

    group('getAll', () {
      test('should return empty list when no graphs exist', () async {
        final graphs = await repository.getAll();
        expect(graphs, isEmpty);
      });

      test('should return all graphs', () async {
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

      test('should skip current.json file', () async {
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

      test('should handle corrupted files gracefully', () async {
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

      test('should create directory if it does not exist', () async {
        final newDir = Directory.systemTemp.createTempSync('test_getall_dir_').path;
        final newRepo = FileSystemGraphRepository(graphsDir: path.join(newDir, 'graphs'));

        final graphs = await newRepo.getAll();
        expect(graphs, isEmpty);
        expect(Directory(path.join(newDir, 'graphs')).existsSync(), true);

        await Directory(newDir).delete(recursive: true);
      });
    });

    group('getCurrent', () {
      test('should return null when no current graph is set', () async {
        final current = await repository.getCurrent();
        expect(current, isNull);
      });

      test('should return current graph', () async {
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

      test('should return first graph as default if no current is set', () async {
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

      test('should clear current graph if it is deleted', () async {
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

      test('should handle corrupted current.json gracefully', () async {
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

    group('setCurrent', () {
      test('should set current graph successfully', () async {
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

      test('should create current.json file', () async {
        await repository.setCurrent('graph_1');

        final currentFile = File(path.join(testDir, 'current.json'));
        expect(currentFile.existsSync(), true);
      });
    });

    group('export', () {
      test('should export graph to file successfully', () async {
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

      test('should throw RepositoryException if graph does not exist', () async {
        final exportPath = path.join(Directory.systemTemp.path, 'exported_graph.json');

        expect(() async => repository.export('non_existent', exportPath), throwsA(isA<RepositoryException>()));
      });
    });

    group('import', () {
      test('should import graph from file successfully', () async {
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

      test('should throw RepositoryException if file does not exist', () async {
        final importPath = path.join(Directory.systemTemp.path, 'non_existent.json');

        expect(() async => repository.import(importPath), throwsA(isA<RepositoryException>()));
      });

      test('should throw RepositoryException for corrupted file', () async {
        final importPath = path.join(Directory.systemTemp.path, 'corrupted_${DateTime.now().millisecondsSinceEpoch}.json');
        final importFile = File(importPath);
        await importFile.writeAsString('invalid json {{{');

        expect(() async => repository.import(importPath), throwsA(isA<RepositoryException>()));

        try {
          await importFile.delete();
        } catch (_) {}
      });
    });

    group('createDefaultGraph', () {
      test('should create a default graph', () async {
        final defaultGraph = await repository.createDefaultGraph();

        expect(defaultGraph, isNotNull);
        expect(defaultGraph.name, 'My First Graph');
        expect(defaultGraph.nodeIds, isEmpty);
        expect(defaultGraph.nodePositions, isEmpty);
      });

      test('should set default graph as current', () async {
        final defaultGraph = await repository.createDefaultGraph();

        final current = await repository.getCurrent();
        expect(current, isNotNull);
        expect(current!.id, defaultGraph.id);
      });

      test('should save default graph to storage', () async {
        final defaultGraph = await repository.createDefaultGraph();

        final loaded = await repository.load(defaultGraph.id);
        expect(loaded, isNotNull);
        expect(loaded!.id, defaultGraph.id);
      });
    });

    group('integration tests', () {
      test('should handle complete workflow', () async {
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