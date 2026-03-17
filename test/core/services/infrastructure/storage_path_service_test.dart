
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/services/infrastructure/storage_path_service.dart';

void main() {
  group('StorageUsage', () {
    test('should create StorageUsage with correct properties', () {
      const usage = StorageUsage(
        totalSize: 1024,
        nodesCount: 10,
        graphsCount: 5,
      );

      expect(usage.totalSize, 1024);
      expect(usage.nodesCount, 10);
      expect(usage.graphsCount, 5);
    });

    test('should create StorageUsage from JSON', () {
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

    test('should convert StorageUsage to JSON', () {
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

    test('should format size in bytes', () {
      const usage = StorageUsage(
        totalSize: 512,
        nodesCount: 0,
        graphsCount: 0,
      );

      expect(usage.formattedSize, '512 B');
    });

    test('should format size in kilobytes', () {
      const usage = StorageUsage(
        totalSize: 2048,
        nodesCount: 0,
        graphsCount: 0,
      );

      expect(usage.formattedSize, '2.0 KB');
    });

    test('should format size in megabytes', () {
      const usage = StorageUsage(
        totalSize: 2097152,
        nodesCount: 0,
        graphsCount: 0,
      );

      expect(usage.formattedSize, '2.0 MB');
    });

    test('should format size in gigabytes', () {
      const usage = StorageUsage(
        totalSize: 2147483648,
        nodesCount: 0,
        graphsCount: 0,
      );

      expect(usage.formattedSize, '2.00 GB');
    });
  });
}
