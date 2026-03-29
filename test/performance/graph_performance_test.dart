import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/graph/adjacency_list.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:path/path.dart' as path;

/// 图性能基准测试
///
/// 测试核心图操作的性能表现
void main() {
  group('Graph Performance Benchmarks', () {
    late String testDir;
    late FileSystemNodeRepository repository;
    late AdjacencyList adjacencyList;

    setUp(() async {
      testDir = Directory.systemTemp.createTempSync('perf_test_').path;
      repository = FileSystemNodeRepository(nodesDir: path.join(testDir, 'nodes'));
      await repository.init();
      adjacencyList = repository.adjacencyList!;
    });

    tearDown(() async {
      final dir = Directory(testDir);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    });

    group('邻接表性能测试', () {
      test('Adjacency List - O(1) neighbor lookup performance', () {
        // 创建大图
        const nodeCount = 1000;
        for (var i = 0; i < nodeCount; i++) {
          adjacencyList.addEdge('node_$i', 'target_${i % 100}');
        }

        final stopwatch = Stopwatch()..start();

        // 执行大量邻居查询
        const queryCount = 10000;
        for (var i = 0; i < queryCount; i++) {
          adjacencyList.getOutgoingNeighbors('node_${i % nodeCount}');
        }

        stopwatch.stop();

        final avgTimeMicroseconds = stopwatch.elapsedMicroseconds / queryCount;

        debugPrint('Adjacency List Neighbor Lookup Performance:');
        debugPrint('  Total queries: $queryCount');
        debugPrint('  Total time: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  Average per query: ${avgTimeMicroseconds.toStringAsFixed(2)}μs');

        // O(1) 查找应该非常快 (< 10μs)
        expect(avgTimeMicroseconds, lessThan(10));
      });

      test('Adjacency List - O(1) edge existence check performance', () {
        // 创建密集图
        const nodeCount = 100;
        for (var i = 0; i < nodeCount; i++) {
          for (var j = 0; j < nodeCount; j++) {
            if (i != j) {
              adjacencyList.addEdge('node_$i', 'node_$j');
            }
          }
        }

        final stopwatch = Stopwatch()..start();

        // 执行大量边存在性检查
        const checkCount = 10000;
        final random = Random(42);
        for (var i = 0; i < checkCount; i++) {
          final from = 'node_${random.nextInt(nodeCount)}';
          final to = 'node_${random.nextInt(nodeCount)}';
          adjacencyList.hasEdge(from, to);
        }

        stopwatch.stop();

        final avgTimeMicroseconds = stopwatch.elapsedMicroseconds / checkCount;

        debugPrint('Adjacency List Edge Check Performance:');
        debugPrint('  Total checks: $checkCount');
        debugPrint('  Total time: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  Average per check: ${avgTimeMicroseconds.toStringAsFixed(2)}μs');

        expect(avgTimeMicroseconds, lessThan(5));
      });

      test('Adjacency List - Add/Remove edge performance', () {
        const operationCount = 10000;
        final random = Random(42);

        // 添加边性能测试
        var stopwatch = Stopwatch()..start();
        for (var i = 0; i < operationCount; i++) {
          adjacencyList.addEdge('source_$i', 'target_${random.nextInt(100)}');
        }
        stopwatch.stop();

        final addTimePerOp = stopwatch.elapsedMicroseconds / operationCount;

        debugPrint('Adjacency List Add Edge Performance:');
        debugPrint('  Total operations: $operationCount');
        debugPrint('  Total time: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  Average per add: ${addTimePerOp.toStringAsFixed(2)}μs');

        // 删除边性能测试
        stopwatch = Stopwatch()..start();
        for (var i = 0; i < operationCount; i++) {
          adjacencyList.removeEdge('source_$i', 'target_${random.nextInt(100)}');
        }
        stopwatch.stop();

        final removeTimePerOp = stopwatch.elapsedMicroseconds / operationCount;

        debugPrint('Adjacency List Remove Edge Performance:');
        debugPrint('  Total operations: $operationCount');
        debugPrint('  Total time: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  Average per remove: ${removeTimePerOp.toStringAsFixed(2)}μs');

        expect(addTimePerOp, lessThan(50));
        expect(removeTimePerOp, lessThan(50));
      });
    });

    group('存储库性能测试', () {
      test('Repository - Batch save performance', () async {
        const batchSize = 100;
        final nodes = List.generate(batchSize, (i) => Node(
          id: 'node_$i',
          title: 'Node $i',
          content: 'Content for node $i with some additional text',
          references: const {},
          position: Offset(i * 10.0, i * 10.0),
          size: const Size(300, 400),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {'tag': 'test'},
        ));

        final stopwatch = Stopwatch()..start();
        await repository.saveAll(nodes);
        stopwatch.stop();

        final timePerNode = stopwatch.elapsedMilliseconds / batchSize;

        debugPrint('Repository Batch Save Performance:');
        debugPrint('  Total nodes: $batchSize');
        debugPrint('  Total time: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  Average per node: ${timePerNode.toStringAsFixed(2)}ms');

        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });

      test('Repository - Query all nodes performance', () async {
        // 先创建一些节点
        const nodeCount = 100;
        for (var i = 0; i < nodeCount; i++) {
          await repository.save(Node(
            id: 'node_$i',
            title: 'Node $i',
            content: 'Content $i',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(100, 100),
            viewMode: NodeViewMode.titleOnly,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ));
        }

        final stopwatch = Stopwatch()..start();
        final nodes = await repository.queryAll();
        stopwatch.stop();

        final timePerNode = stopwatch.elapsedMicroseconds / nodeCount;

        debugPrint('Repository Query All Performance:');
        debugPrint('  Total nodes: $nodeCount');
        debugPrint('  Total time: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  Average per node: ${timePerNode.toStringAsFixed(2)}μs');

        expect(nodes.length, nodeCount);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      test('Repository - Search performance', () async {
        // 创建测试数据
        const nodeCount = 100;
        for (var i = 0; i < nodeCount; i++) {
          await repository.save(Node(
            id: 'node_$i',
            title: 'Test Node $i',
            content: 'This is content for node $i with searchable keywords',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(100, 100),
            viewMode: NodeViewMode.titleOnly,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {'tags': ['test', 'search']},
          ));
        }

        final stopwatch = Stopwatch()..start();
        final results = await repository.search(title: 'Test');
        stopwatch.stop();

        debugPrint('Repository Search Performance:');
        debugPrint('  Total nodes: $nodeCount');
        debugPrint('  Results found: ${results.length}');
        debugPrint('  Total time: ${stopwatch.elapsedMilliseconds}ms');

        expect(results.length, nodeCount);
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      });

      test('Repository - Load single node performance', () async {
        // 创建节点
        const nodeCount = 50;
        for (var i = 0; i < nodeCount; i++) {
          await repository.save(Node(
            id: 'node_$i',
            title: 'Node $i',
            content: 'Content $i',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(100, 100),
            viewMode: NodeViewMode.titleOnly,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ));
        }

        const loadCount = 100;
        final stopwatch = Stopwatch()..start();

        for (var i = 0; i < loadCount; i++) {
          await repository.load('node_${i % nodeCount}');
        }

        stopwatch.stop();

        final avgTimeMicroseconds = stopwatch.elapsedMicroseconds / loadCount;

        debugPrint('Repository Load Single Node Performance:');
        debugPrint('  Total loads: $loadCount');
        debugPrint('  Total time: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  Average per load: ${avgTimeMicroseconds.toStringAsFixed(2)}μs');

        expect(avgTimeMicroseconds, lessThan(1000));
      });
    });

    group('大规模图性能测试', () {
      test('Large graph - 1000 nodes with connections', () async {
        const nodeCount = 1000;
        final stopwatch = Stopwatch()..start();

        // 创建节点
        for (var i = 0; i < nodeCount; i++) {
          await repository.save(Node(
            id: 'node_$i',
            title: 'Node $i',
            content: 'Content $i',
            references: const {},
            position: Offset(i * 10.0, i * 10.0),
            size: const Size(100, 100),
            viewMode: NodeViewMode.titleOnly,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ));
        }

        final createTime = stopwatch.elapsedMilliseconds;
        stopwatch.reset();

        // 创建连接（每个节点连接到5个随机节点）
        final random = Random(42);
        for (var i = 0; i < nodeCount; i++) {
          for (var j = 0; j < 5; j++) {
            final target = random.nextInt(nodeCount);
            if (target != i) {
              adjacencyList.addEdge('node_$i', 'node_$target');
            }
          }
        }

        final connectTime = stopwatch.elapsedMilliseconds;
        stopwatch.reset();

        // 查询所有节点
        final nodes = await repository.queryAll();

        final queryTime = stopwatch.elapsedMilliseconds;

        debugPrint('Large Graph Performance (1000 nodes):');
        debugPrint('  Create time: ${createTime}ms');
        debugPrint('  Connect time: ${connectTime}ms');
        debugPrint('  Query all time: ${queryTime}ms');
        debugPrint('  Total edges: ${adjacencyList.edgeCount}');

        expect(nodes.length, nodeCount);
        expect(adjacencyList.edgeCount, greaterThan(0));
      });

      test('Dense graph - 100 nodes fully connected', () {
        const nodeCount = 100;
        final stopwatch = Stopwatch()..start();

        // 创建完全连接图
        for (var i = 0; i < nodeCount; i++) {
          for (var j = 0; j < nodeCount; j++) {
            if (i != j) {
              adjacencyList.addEdge('node_$i', 'node_$j');
            }
          }
        }

        stopwatch.stop();

        final expectedEdges = nodeCount * (nodeCount - 1);

        debugPrint('Dense Graph Performance:');
        debugPrint('  Nodes: $nodeCount');
        debugPrint('  Edges: $expectedEdges');
        debugPrint('  Build time: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  Time per edge: ${(stopwatch.elapsedMicroseconds / expectedEdges).toStringAsFixed(2)}μs');

        expect(adjacencyList.edgeCount, expectedEdges);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      test('Graph traversal performance', () {
        // 创建链式图: 0 -> 1 -> 2 -> ... -> 999
        const nodeCount = 1000;
        for (var i = 0; i < nodeCount - 1; i++) {
          adjacencyList.addEdge('node_$i', 'node_${i + 1}');
        }

        final stopwatch = Stopwatch()..start();

        // 遍历整个链
        var current = 'node_0';
        var visited = 0;
        while (visited < nodeCount - 1) {
          final neighbors = adjacencyList.getOutgoingNeighbors(current);
          if (neighbors.isEmpty) break;
          current = neighbors.first;
          visited++;
        }

        stopwatch.stop();

        debugPrint('Graph Traversal Performance:');
        debugPrint('  Nodes visited: $visited');
        debugPrint('  Total time: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  Time per node: ${(stopwatch.elapsedMicroseconds / visited).toStringAsFixed(2)}μs');

        expect(visited, nodeCount - 1);
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    group('内存使用测试', () {
      test('Adjacency list memory efficiency', () {
        const nodeCount = 10000;
        const edgesPerNode = 5;

        // 创建图
        final random = Random(42);
        for (var i = 0; i < nodeCount; i++) {
          for (var j = 0; j < edgesPerNode; j++) {
            final target = random.nextInt(nodeCount);
            adjacencyList.addEdge('node_$i', 'node_$target');
          }
        }

        final stats = adjacencyList.stats;

        debugPrint('Adjacency List Memory Stats:');
        debugPrint('  Nodes: ${stats.nodeCount}');
        debugPrint('  Edges: ${stats.edgeCount}');
        debugPrint('  Avg out degree: ${stats.avgOutDegree.toStringAsFixed(2)}');
        debugPrint('  Max out degree: ${stats.maxOutDegree}');

        // 验证边数
        expect(stats.edgeCount, lessThanOrEqualTo(nodeCount * edgesPerNode));
      });
    });

    group('序列化性能测试', () {
      test('Adjacency list save/load performance', () async {
        // 创建大图
        const nodeCount = 1000;
        final random = Random(42);
        for (var i = 0; i < nodeCount; i++) {
          for (var j = 0; j < 5; j++) {
            adjacencyList.addEdge('node_$i', 'node_${random.nextInt(nodeCount)}');
          }
        }

        // 测试保存性能
        var stopwatch = Stopwatch()..start();
        await adjacencyList.save();
        stopwatch.stop();

        final saveTime = stopwatch.elapsedMilliseconds;

        // 测试加载性能
        final newList = AdjacencyList(storageDir: testDir);
        stopwatch = Stopwatch()..start();
        await newList.init();
        stopwatch.stop();

        final loadTime = stopwatch.elapsedMilliseconds;

        debugPrint('Adjacency List Serialization Performance:');
        debugPrint('  Nodes: $nodeCount');
        debugPrint('  Edges: ${adjacencyList.edgeCount}');
        debugPrint('  Save time: ${saveTime}ms');
        debugPrint('  Load time: ${loadTime}ms');

        // 加载后验证数据
        expect(newList.isLoaded, true);
        expect(saveTime, lessThan(1000));
        expect(loadTime, lessThan(1000));
      });
    });
  });
}
