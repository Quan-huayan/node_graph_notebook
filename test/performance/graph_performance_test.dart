import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/graph/adjacency_list.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:path/path.dart' as path;

/// 图性能基准测试
///
/// 测试核心图操作的性能表现
void main() {
  group('图性能基准测试', () {
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
      test('邻接表 - O(1) 邻居查询性能', () {
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

        debugPrint('邻接表邻居查询性能:');
        debugPrint('  总查询次数: $queryCount');
        debugPrint('  总耗时: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  平均每次查询: ${avgTimeMicroseconds.toStringAsFixed(2)}μs');

        // O(1) 查找应该非常快 (< 10μs)
        expect(avgTimeMicroseconds, lessThan(10));
      });

      test('邻接表 - O(1) 边存在性检查性能', () {
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

        debugPrint('邻接表边检查性能:');
        debugPrint('  总检查次数: $checkCount');
        debugPrint('  总耗时: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  平均每次检查: ${avgTimeMicroseconds.toStringAsFixed(2)}μs');

        expect(avgTimeMicroseconds, lessThan(5));
      });

      test('邻接表 - 添加/删除边性能', () {
        const operationCount = 10000;
        final random = Random(42);

        // 添加边性能测试
        var stopwatch = Stopwatch()..start();
        for (var i = 0; i < operationCount; i++) {
          adjacencyList.addEdge('source_$i', 'target_${random.nextInt(100)}');
        }
        stopwatch.stop();

        final addTimePerOp = stopwatch.elapsedMicroseconds / operationCount;

        debugPrint('邻接表添加边性能:');
        debugPrint('  总操作次数: $operationCount');
        debugPrint('  总耗时: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  平均每次添加: ${addTimePerOp.toStringAsFixed(2)}μs');

        // 删除边性能测试
        stopwatch = Stopwatch()..start();
        for (var i = 0; i < operationCount; i++) {
          adjacencyList.removeEdge('source_$i', 'target_${random.nextInt(100)}');
        }
        stopwatch.stop();

        final removeTimePerOp = stopwatch.elapsedMicroseconds / operationCount;

        debugPrint('邻接表删除边性能:');
        debugPrint('  总操作次数: $operationCount');
        debugPrint('  总耗时: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  平均每次删除: ${removeTimePerOp.toStringAsFixed(2)}μs');

        expect(addTimePerOp, lessThan(50));
        expect(removeTimePerOp, lessThan(50));
      });
    });

    group('存储库性能测试', () {
      test('存储库 - 批量保存性能', () async {
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

        debugPrint('存储库批量保存性能:');
        debugPrint('  总节点数: $batchSize');
        debugPrint('  总耗时: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  平均每节点: ${timePerNode.toStringAsFixed(2)}ms');

        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });

      test('存储库 - 查询所有节点性能', () async {
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

        debugPrint('存储库查询全部性能:');
        debugPrint('  总节点数: $nodeCount');
        debugPrint('  总耗时: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  平均每节点: ${timePerNode.toStringAsFixed(2)}μs');

        expect(nodes.length, nodeCount);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      test('存储库 - 搜索性能', () async {
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

        debugPrint('存储库搜索性能:');
        debugPrint('  总节点数: $nodeCount');
        debugPrint('  搜索结果: ${results.length}');
        debugPrint('  总耗时: ${stopwatch.elapsedMilliseconds}ms');

        expect(results.length, nodeCount);
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      });

      test('存储库 - 加载单个节点性能', () async {
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

        debugPrint('存储库加载单个节点性能:');
        debugPrint('  总加载次数: $loadCount');
        debugPrint('  总耗时: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  平均每次加载: ${avgTimeMicroseconds.toStringAsFixed(2)}μs');

        expect(avgTimeMicroseconds, lessThan(1000));
      });
    });

    group('大规模图性能测试', () {
      test('大图 - 1000个带连接的节点', () async {
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

        debugPrint('大图性能 (1000个节点):');
        debugPrint('  创建耗时: ${createTime}ms');
        debugPrint('  连接耗时: ${connectTime}ms');
        debugPrint('  查询全部耗时: ${queryTime}ms');
        debugPrint('  总边数: ${adjacencyList.edgeCount}');

        expect(nodes.length, nodeCount);
        expect(adjacencyList.edgeCount, greaterThan(0));
      });

      test('密集图 - 100个完全连接的节点', () {
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

        const expectedEdges = nodeCount * (nodeCount - 1);

        debugPrint('密集图性能:');
        debugPrint('  节点数: $nodeCount');
        debugPrint('  边数: $expectedEdges');
        debugPrint('  构建耗时: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  每条边耗时: ${(stopwatch.elapsedMicroseconds / expectedEdges).toStringAsFixed(2)}μs');

        expect(adjacencyList.edgeCount, expectedEdges);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      test('图遍历性能', () {
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

        debugPrint('图遍历性能:');
        debugPrint('  访问节点数: $visited');
        debugPrint('  总耗时: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('  每节点耗时: ${(stopwatch.elapsedMicroseconds / visited).toStringAsFixed(2)}μs');

        expect(visited, nodeCount - 1);
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    group('内存使用测试', () {
      test('邻接表内存效率', () {
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

        debugPrint('邻接表内存统计:');
        debugPrint('  节点数: ${stats.nodeCount}');
        debugPrint('  边数: ${stats.edgeCount}');
        debugPrint('  平均出度: ${stats.avgOutDegree.toStringAsFixed(2)}');
        debugPrint('  最大出度: ${stats.maxOutDegree}');

        // 验证边数
        expect(stats.edgeCount, lessThanOrEqualTo(nodeCount * edgesPerNode));
      });
    });

    group('序列化性能测试', () {
      test('邻接表保存/加载性能', () async {
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

        debugPrint('邻接表序列化性能:');
        debugPrint('  节点数: $nodeCount');
        debugPrint('  边数: ${adjacencyList.edgeCount}');
        debugPrint('  保存耗时: ${saveTime}ms');
        debugPrint('  加载耗时: ${loadTime}ms');

        // 加载后验证数据
        expect(newList.isLoaded, true);
        expect(saveTime, lessThan(1000));
        expect(loadTime, lessThan(1000));
      });
    });
  });
}
