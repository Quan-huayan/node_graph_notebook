
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/services/infrastructure/storage_path_service.dart';

void main() {
  group('StorageUsage', () {
    test('应该创建具有正确属性的 StorageUsage', () {
      const usage = StorageUsage(
        totalSize: 1024,
        nodesCount: 10,
        graphsCount: 5,
      );

      expect(usage.totalSize, 1024);
      expect(usage.nodesCount, 10);
      expect(usage.graphsCount, 5);
    });

    test('应该从 JSON 创建 StorageUsage', () {
      final json = {
        'totalSize': 2048,
        'nodesCount': 20,
        'graphsCount': 10,
      };

      final usage = StorageUsage.fromJson(json);

      expect(usage.totalSize, 2048);
      expect(usage.nodesCount, 20);
      expect(usage.graphsCount, 10);
    });

    test('应该将 StorageUsage 转换为 JSON', () {
      const usage = StorageUsage(
        totalSize: 1024,
        nodesCount: 10,
        graphsCount: 5,
      );

      final json = usage.toJson();

      expect(json['totalSize'], 1024);
      expect(json['nodesCount'], 10);
      expect(json['graphsCount'], 5);
      expect(json.containsKey('formattedSize'), true);
    });

    test('应该以字节格式化大小', () {
      const usage = StorageUsage(
        totalSize: 512,
        nodesCount: 0,
        graphsCount: 0,
      );

      expect(usage.formattedSize, '512 B');
    });

    test('应该以千字节格式化大小', () {
      const usage = StorageUsage(
        totalSize: 2048,
        nodesCount: 0,
        graphsCount: 0,
      );

      expect(usage.formattedSize, '2.0 KB');
    });

    test('应该以兆字节格式化大小', () {
      const usage = StorageUsage(
        totalSize: 2097152,
        nodesCount: 0,
        graphsCount: 0,
      );

      expect(usage.formattedSize, '2.0 MB');
    });

    test('应该以吉字节格式化大小', () {
      const usage = StorageUsage(
        totalSize: 2147483648,
        nodesCount: 0,
        graphsCount: 0,
      );

      expect(usage.formattedSize, '2.00 GB');
    });
  });
}
