import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/cqrs/queries/load_node_query.dart';
import 'package:node_graph_notebook/core/cqrs/query/query.dart';
import 'package:node_graph_notebook/core/cqrs/query/query_bus.dart';
import 'package:node_graph_notebook/core/cqrs/query/query_cache.dart';
import 'package:node_graph_notebook/core/cqrs/read_models/node_read_model.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/plugin/service_registry.dart';

/// CQRS 性能基准测试
///
/// 测试内容：
/// 1. Query Cache 命中率测试
/// 2. Query Bus 分发性能测试
/// 3. NodeReadModel vs Node 内存占用对比
/// 4. 搜索索引性能测试
void main() {
  group('CQRS Performance Benchmarks', () {
    late ServiceRegistry serviceRegistry;
    late QueryBus queryBus;

    setUp(() {
      // 初始化测试环境
      serviceRegistry = ServiceRegistry();
      queryBus = QueryBus(serviceRegistry: serviceRegistry);
    });

    test('Query Cache Performance - 1000 queries', () async {
      // 创建测试数据（用于缓存测试）
      List.generate(1000, (i) => Node(
        id: 'node_$i',
        title: 'Node $i',
        references: {},
        position: const Offset(0, 0),
        size: const Size(100, 100),
        viewMode: NodeViewMode.titleOnly,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      ));

      final stopwatch = Stopwatch()..start();

      // 执行1000次查询
      for (var i = 0; i < 1000; i++) {
        final query = LoadNodeQuery(nodeId: 'node_${i % 100}');
        await queryBus.dispatch(query);
      }

      stopwatch.stop();

      debugPrint('Query Cache Performance:');
      debugPrint('  Total time: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('  Average per query: ${stopwatch.elapsedMicroseconds / 1000}μs');
      debugPrint('  Queries per second: ${1000000 / stopwatch.elapsedMicroseconds * 1000}');

      // 验证性能：应该很快（<100ms for 1000 queries）
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('NodeReadModel Memory Efficiency', () {
      // 创建完整Node
      final fullNode = Node(
        id: 'test_node',
        title: 'Test Node with Content',
        content: 'A' * 1000, // 1KB content
        references: {},
        position: const Offset(0, 0),
        size: const Size(100, 100),
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {'key1': 'value1' * 100},
      );

      // 创建轻量级读模型
      final readModel = NodeReadModel.fromNode(fullNode);

      debugPrint('Memory Efficiency Comparison:');
      debugPrint('  Full Node estimated: ~${2 + 1}KB');
      debugPrint('  ReadModel estimated: ${readModel.estimatedMemoryBytes} bytes');
      debugPrint('  Memory saved: ${(100 - (readModel.estimatedMemoryBytes / 2048 * 100)).toStringAsFixed(1)}%');

      // 验证内存节省 > 80%
      final memorySavedPercent = 100 - (readModel.estimatedMemoryBytes / 2048 * 100);
      expect(memorySavedPercent, greaterThan(80));
    });

    test('Query Cache Statistics', () {
      final cache = QueryCache(maxSize: 100, defaultTtl: const Duration(minutes: 5));

      // 添加100个条目
      for (var i = 0; i < 100; i++) {
        final query = LoadNodeQuery(nodeId: 'node_$i');
        final result = QueryResult.success(null);
        cache.put(query, result);
      }

      final stats = cache.stats;

      debugPrint('Query Cache Statistics:');
      debugPrint('  $stats');
      debugPrint('  Usage rate: ${(stats.usageRate * 100).toStringAsFixed(1)}%');

      // 验证缓存使用率
      expect(stats.size, equals(100));
      expect(stats.usageRate, greaterThan(0));
    });
  });

  group('Performance Regression Tests', () {
    test('Adjacency List Performance - O(1) neighbor lookup', () {
      // TODO: 实现邻接表性能测试
      // 目标：验证邻居查询是O(1)而非O(n)
    });

    test('QuadTree Spatial Query - O(log n) vs O(n)', () {
      // TODO: 实现QuadTree性能测试
      // 目标：验证空间查询是O(log n)而非O(n)
    });

    test('Search Index - O(1) lookup vs O(n) scan', () {
      // TODO: 实现搜索索引性能测试
      // 目标：验证搜索是O(1)而非O(n)
    });
  });
}
