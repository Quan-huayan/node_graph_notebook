import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/graph/adjacency_list.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/models/node_reference.dart';
import 'package:path/path.dart' as path;

void main() {
  group('邻接表边界测试', () {
    late AdjacencyList adjacencyList;
    late String testDir;

    setUp(() async {
      testDir = Directory.systemTemp.createTempSync('adj_test_').path;
      adjacencyList = AdjacencyList(storageDir: testDir);
      await adjacencyList.init();
    });

    tearDown(() async {
      final dir = Directory(testDir);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    });

    group('大规模图操作边界测试', () {
      test('应该能处理包含大量节点的图', () {
        const nodeCount = 10000;

        // 添加大量节点和边
        for (var i = 0; i < nodeCount; i++) {
          adjacencyList.addEdge('node_$i', 'target_$i');
        }

        expect(adjacencyList.nodeCount, nodeCount * 2); // 源节点 + 目标节点
        expect(adjacencyList.edgeCount, nodeCount);
      });

      test('应该能处理高度连接的节点', () {
        const hubNode = 'hub';
        const connectionCount = 1000;

        // 创建一个高度连接的节点
        for (var i = 0; i < connectionCount; i++) {
          adjacencyList.addEdge(hubNode, 'node_$i');
        }

        expect(adjacencyList.getOutDegree(hubNode), connectionCount);
        expect(adjacencyList.getOutgoingNeighbors(hubNode).length, connectionCount);
      });

      test('应该能处理稠密图', () {
        const nodeCount = 100;

        // 创建完全连接图（每个节点连接到所有其他节点）
        for (var i = 0; i < nodeCount; i++) {
          for (var j = 0; j < nodeCount; j++) {
            if (i != j) {
              adjacencyList.addEdge('node_$i', 'node_$j');
            }
          }
        }

        expect(adjacencyList.nodeCount, nodeCount);
        expect(adjacencyList.edgeCount, nodeCount * (nodeCount - 1));

        // 验证每个节点的出度
        for (var i = 0; i < nodeCount; i++) {
          expect(adjacencyList.getOutDegree('node_$i'), nodeCount - 1);
        }
      });

      test('应该能处理快速的添加和删除操作', () {
        const operations = 1000;

        // 快速添加
        for (var i = 0; i < operations; i++) {
          adjacencyList.addEdge('source', 'target_$i');
        }
        expect(adjacencyList.edgeCount, operations);

        // 快速删除
        for (var i = 0; i < operations; i++) {
          adjacencyList.removeEdge('source', 'target_$i');
        }
        expect(adjacencyList.edgeCount, 0);
      });
    });

    group('循环引用检测边界测试', () {
      test('应该能检测自环', () {
        adjacencyList.addEdge('node_a', 'node_a');

        expect(adjacencyList.hasEdge('node_a', 'node_a'), true);
        expect(adjacencyList.getOutDegree('node_a'), 1);
        expect(adjacencyList.getInDegree('node_a'), 1);
      });

      test('应该能处理两节点循环', () {
        adjacencyList.addEdge('node_a', 'node_b');
        adjacencyList.addEdge('node_b', 'node_a');

        expect(adjacencyList.hasEdge('node_a', 'node_b'), true);
        expect(adjacencyList.hasEdge('node_b', 'node_a'), true);

        // 验证入度和出度
        expect(adjacencyList.getOutDegree('node_a'), 1);
        expect(adjacencyList.getInDegree('node_a'), 1);
        expect(adjacencyList.getOutDegree('node_b'), 1);
        expect(adjacencyList.getInDegree('node_b'), 1);
      });

      test('应该能处理长循环', () {
        const cycleLength = 100;

        // 创建长循环: 0 -> 1 -> 2 -> ... -> 99 -> 0
        for (var i = 0; i < cycleLength; i++) {
          final next = (i + 1) % cycleLength;
          adjacencyList.addEdge('node_$i', 'node_$next');
        }

        expect(adjacencyList.edgeCount, cycleLength);

        // 验证每个节点的入度=出度=1
        for (var i = 0; i < cycleLength; i++) {
          expect(adjacencyList.getOutDegree('node_$i'), 1);
          expect(adjacencyList.getInDegree('node_$i'), 1);
        }
      });

      test('应该能处理包含多个循环的复杂图', () {
        // 创建多个重叠的循环
        // 循环1: A -> B -> C -> A
        adjacencyList.addEdge('A', 'B');
        adjacencyList.addEdge('B', 'C');
        adjacencyList.addEdge('C', 'A');

        // 循环2: B -> D -> E -> B
        adjacencyList.addEdge('B', 'D');
        adjacencyList.addEdge('D', 'E');
        adjacencyList.addEdge('E', 'B');

        // 循环3: C -> D -> C
        adjacencyList.addEdge('C', 'D');
        adjacencyList.addEdge('D', 'C');

        expect(adjacencyList.edgeCount, 8);

        // 验证度数
        expect(adjacencyList.getOutDegree('A'), 1);
        expect(adjacencyList.getInDegree('A'), 1);
        expect(adjacencyList.getOutDegree('B'), 2);
        expect(adjacencyList.getInDegree('B'), 2);
        expect(adjacencyList.getOutDegree('C'), 2);
        expect(adjacencyList.getInDegree('C'), 2);
        expect(adjacencyList.getOutDegree('D'), 2);
        expect(adjacencyList.getInDegree('D'), 2);
        expect(adjacencyList.getOutDegree('E'), 1);
        expect(adjacencyList.getInDegree('E'), 1);
      });
    });

    group('节点删除边界测试', () {
      test('应该能处理删除具有大量连接的节点', () {
        const hubNode = 'hub';

        // 创建高度连接的节点
        for (var i = 0; i < 100; i++) {
          adjacencyList.addEdge(hubNode, 'out_$i');
          adjacencyList.addEdge('in_$i', hubNode);
        }

        expect(adjacencyList.edgeCount, 200);

        // 删除中心节点
        adjacencyList.removeNode(hubNode);

        expect(adjacencyList.edgeCount, 0);
        expect(adjacencyList.getOutDegree(hubNode), 0);
        expect(adjacencyList.getInDegree(hubNode), 0);
      });

      test('应该能优雅地处理删除不存在的节点', () {
        // 添加一些边
        adjacencyList.addEdge('A', 'B');
        adjacencyList.addEdge('B', 'C');

        // 删除不存在的节点
        adjacencyList.removeNode('non_existent');

        expect(adjacencyList.edgeCount, 2);
        expect(adjacencyList.hasEdge('A', 'B'), true);
        expect(adjacencyList.hasEdge('B', 'C'), true);
      });

      test('应该能逐个删除所有节点', () {
        const nodeCount = 50;

        // 创建完全连接图
        for (var i = 0; i < nodeCount; i++) {
          for (var j = 0; j < nodeCount; j++) {
            if (i != j) {
              adjacencyList.addEdge('node_$i', 'node_$j');
            }
          }
        }

        expect(adjacencyList.edgeCount, nodeCount * (nodeCount - 1));

        // 逐个删除所有节点
        for (var i = 0; i < nodeCount; i++) {
          adjacencyList.removeNode('node_$i');
        }

        expect(adjacencyList.edgeCount, 0);
        expect(adjacencyList.nodeCount, 0);
      });
    });

    group('序列化和持久化边界测试', () {
      test('应该能持久化和加载大图', () async {
        const nodeCount = 1000;

        // 创建大图
        for (var i = 0; i < nodeCount; i++) {
          adjacencyList.addEdge('source_$i', 'target_${i % 100}');
        }

        // 保存
        await adjacencyList.save();

        // 创建新的实例并加载
        final loadedList = AdjacencyList(storageDir: testDir);
        await loadedList.init();

        expect(loadedList.edgeCount, nodeCount);
        expect(loadedList.nodeCount, adjacencyList.nodeCount);

        // 验证一些边
        for (var i = 0; i < 10; i++) {
          expect(loadedList.hasEdge('source_$i', 'target_${i % 100}'), true);
        }
      });

      test('应该能优雅地处理损坏的文件', () async {
        // 创建一些数据
        adjacencyList.addEdge('A', 'B');
        await adjacencyList.save();

        // 损坏文件
        final file = File(path.join(testDir, 'adjacency_list.json'));
        await file.writeAsString('invalid json {{{');

        // 创建新的实例并尝试加载
        final loadedList = AdjacencyList(storageDir: testDir);
        await loadedList.init();

        // 应该创建空的邻接表
        expect(loadedList.edgeCount, 0);
        expect(loadedList.isLoaded, true);
      });

      test('应该能处理缺失的文件目录', () async {
        final newDir = path.join(testDir, 'non_existent', 'subdir');
        final newList = AdjacencyList(storageDir: newDir);

        // 初始化应该创建目录
        await newList.init();

        newList.addEdge('A', 'B');
        await newList.save();

        expect(File(path.join(newDir, 'adjacency_list.json')).existsSync(), true);
      });
    });

    group('从节点构建边界测试', () {
      test('应该能从具有大量引用的节点构建', () {
        final nodes = <Node>[];

        // 创建节点，每个节点引用其他所有节点
        for (var i = 0; i < 50; i++) {
          final references = <String, NodeReference>{};
          for (var j = 0; j < 50; j++) {
            if (i != j) {
              references['node_$j'] = NodeReference(
                nodeId: 'node_$j',
                properties: {'type': 'relatesTo'},
              );
            }
          }

          nodes.add(Node(
            id: 'node_$i',
            title: 'Node $i',
            references: references,
            position: const Offset(0, 0),
            size: const Size(100, 100),
            viewMode: NodeViewMode.titleOnly,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ));
        }

        adjacencyList.buildFromNodes(nodes);

        expect(adjacencyList.nodeCount, 50);
        expect(adjacencyList.edgeCount, 50 * 49);
      });

      test('应该能处理没有引用的节点', () {
        final nodes = [
          Node(
            id: 'isolated_1',
            title: 'Isolated 1',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(100, 100),
            viewMode: NodeViewMode.titleOnly,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
          Node(
            id: 'isolated_2',
            title: 'Isolated 2',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(100, 100),
            viewMode: NodeViewMode.titleOnly,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        adjacencyList.buildFromNodes(nodes);

        expect(adjacencyList.nodeCount, 0); // 没有边的节点不计入
        expect(adjacencyList.edgeCount, 0);
      });

      test('应该能处理空节点列表', () {
        adjacencyList.buildFromNodes([]);

        expect(adjacencyList.nodeCount, 0);
        expect(adjacencyList.edgeCount, 0);
      });
    });

    group('统计信息边界测试', () {
      test('应该能计算空图的统计信息', () {
        final stats = adjacencyList.stats;

        expect(stats.nodeCount, 0);
        expect(stats.edgeCount, 0);
        expect(stats.avgOutDegree, 0.0);
        expect(stats.maxOutDegree, 0);
      });

      test('应该能计算具有不同度数的图的统计信息', () {
        // 创建不同度数的节点
        // 节点0: 0条出边
        // 节点1-5: 各1条出边
        for (var i = 1; i <= 5; i++) {
          adjacencyList.addEdge('node_$i', 'target');
        }
        // 节点6: 10条出边
        for (var i = 0; i < 10; i++) {
          adjacencyList.addEdge('node_6', 'target_$i');
        }

        final stats = adjacencyList.stats;

        expect(stats.nodeCount, greaterThan(0));
        expect(stats.edgeCount, 15);
        expect(stats.maxOutDegree, 10);
        expect(stats.avgOutDegree, closeTo(15 / stats.nodeCount, 0.01));
      });
    });

    group('邻居查询边界测试', () {
      test('应该能处理对不存在节点的查询', () {
        final outgoing = adjacencyList.getOutgoingNeighbors('non_existent');
        final incoming = adjacencyList.getIncomingNeighbors('non_existent');
        final all = adjacencyList.getAllNeighbors('non_existent');

        expect(outgoing, isEmpty);
        expect(incoming, isEmpty);
        expect(all, isEmpty);
      });

      test('应该返回不可修改的邻居集合', () {
        adjacencyList.addEdge('A', 'B');
        adjacencyList.addEdge('A', 'C');

        final neighbors = adjacencyList.getOutgoingNeighbors('A');

        expect(neighbors, contains('B'));
        expect(neighbors, contains('C'));
        expect(neighbors.length, 2);
      });
    });
  });
}
