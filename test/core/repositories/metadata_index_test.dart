import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/repositories/metadata_index.dart';

void main() {
  group('PositionInfo - 位置信息', () {
    test('应该使用正确的属性创建PositionInfo', () {
      const position = PositionInfo(dx: 100, dy: 200);

      expect(position.dx, 100.0);
      expect(position.dy, 200.0);
    });

    test('应该序列化为JSON', () {
      const position = PositionInfo(dx: 100, dy: 200);
      final json = position.toJson();

      expect(json['dx'], 100.0);
      expect(json['dy'], 200.0);
    });

    test('应该从JSON反序列化', () {
      final json = {'dx': 100.0, 'dy': 200.0};
      final position = PositionInfo.fromJson(json);

      expect(position.dx, 100.0);
      expect(position.dy, 200.0);
    });

    test('应该具有正确的相等性', () {
      const position1 = PositionInfo(dx: 100, dy: 200);
      const position2 = PositionInfo(dx: 100, dy: 200);
      const position3 = PositionInfo(dx: 300, dy: 400);

      expect(position1 == position2, true);
      expect(position1 == position3, false);
    });

    test('应该具有正确的hashCode', () {
      const position1 = PositionInfo(dx: 100, dy: 200);
      const position2 = PositionInfo(dx: 100, dy: 200);

      expect(position1.hashCode, position2.hashCode);
    });
  });

  group('SizeInfo - 尺寸信息', () {
    test('应该使用正确的属性创建SizeInfo', () {
      const size = SizeInfo(width: 300, height: 400);

      expect(size.width, 300.0);
      expect(size.height, 400.0);
    });

    test('应该序列化为JSON', () {
      const size = SizeInfo(width: 300, height: 400);
      final json = size.toJson();

      expect(json['width'], 300.0);
      expect(json['height'], 400.0);
    });

    test('应该从JSON反序列化', () {
      final json = {'width': 300.0, 'height': 400.0};
      final size = SizeInfo.fromJson(json);

      expect(size.width, 300.0);
      expect(size.height, 400.0);
    });

    test('应该具有正确的相等性', () {
      const size1 = SizeInfo(width: 300, height: 400);
      const size2 = SizeInfo(width: 300, height: 400);
      const size3 = SizeInfo(width: 500, height: 600);

      expect(size1 == size2, true);
      expect(size1 == size3, false);
    });

    test('应该具有正确的hashCode', () {
      const size1 = SizeInfo(width: 300, height: 400);
      const size2 = SizeInfo(width: 300, height: 400);

      expect(size1.hashCode, size2.hashCode);
    });
  });

  group('NodeMetadata - 节点元数据', () {
    late DateTime now;

    setUp(() {
      now = DateTime.now();
    });

    test('应该使用正确的属性创建NodeMetadata', () {
      const position = PositionInfo(dx: 100, dy: 200);
      const size = SizeInfo(width: 300, height: 400);

      final metadata = NodeMetadata(
        id: 'node_1',
        title: 'Test Node',
        position: position,
        size: size,
        filePath: '/path/to/node_1.md',
        referencedNodeIds: ['node_2', 'node_3'],
        createdAt: now,
        updatedAt: now,
      );

      expect(metadata.id, 'node_1');
      expect(metadata.title, 'Test Node');
      expect(metadata.position, position);
      expect(metadata.size, size);
      expect(metadata.filePath, '/path/to/node_1.md');
      expect(metadata.referencedNodeIds, ['node_2', 'node_3']);
      expect(metadata.createdAt, now);
      expect(metadata.updatedAt, now);
    });

    test('应该序列化为JSON', () {
      const position = PositionInfo(dx: 100, dy: 200);
      const size = SizeInfo(width: 300, height: 400);

      final metadata = NodeMetadata(
        id: 'node_1',
        title: 'Test Node',
        position: position,
        size: size,
        filePath: '/path/to/node_1.md',
        referencedNodeIds: ['node_2', 'node_3'],
        createdAt: now,
        updatedAt: now,
      );

      final json = metadata.toJson();

      expect(json['id'], 'node_1');
      expect(json['title'], 'Test Node');
      expect(json['position'], isNotNull);
      expect(json['size'], isNotNull);
      expect(json['filePath'], '/path/to/node_1.md');
      expect(json['referencedNodeIds'], ['node_2', 'node_3']);
      expect(json['createdAt'], isNotNull);
      expect(json['updatedAt'], isNotNull);
    });

    test('应该从JSON反序列化', () {
      final json = {
        'id': 'node_1',
        'title': 'Test Node',
        'position': {'dx': 100.0, 'dy': 200.0},
        'size': {'width': 300.0, 'height': 400.0},
        'filePath': '/path/to/node_1.md',
        'referencedNodeIds': ['node_2', 'node_3'],
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final metadata = NodeMetadata.fromJson(json);

      expect(metadata.id, 'node_1');
      expect(metadata.title, 'Test Node');
      expect(metadata.position.dx, 100.0);
      expect(metadata.position.dy, 200.0);
      expect(metadata.size.width, 300.0);
      expect(metadata.size.height, 400.0);
      expect(metadata.filePath, '/path/to/node_1.md');
      expect(metadata.referencedNodeIds, ['node_2', 'node_3']);
    });

    test('应该基于id具有正确的相等性', () {
      const position = PositionInfo(dx: 100, dy: 200);
      const size = SizeInfo(width: 300, height: 400);

      final metadata1 = NodeMetadata(
        id: 'node_1',
        title: 'Test Node',
        position: position,
        size: size,
        filePath: '/path/to/node_1.md',
        referencedNodeIds: [],
        createdAt: now,
        updatedAt: now,
      );

      final metadata2 = NodeMetadata(
        id: 'node_1',
        title: 'Different Title',
        position: position,
        size: size,
        filePath: '/different/path.md',
        referencedNodeIds: ['node_2'],
        createdAt: now,
        updatedAt: now,
      );

      final metadata3 = NodeMetadata(
        id: 'node_2',
        title: 'Test Node',
        position: position,
        size: size,
        filePath: '/path/to/node_1.md',
        referencedNodeIds: [],
        createdAt: now,
        updatedAt: now,
      );

      expect(metadata1 == metadata2, true);
      expect(metadata1 == metadata3, false);
    });

    test('应该基于id具有正确的hashCode', () {
      const position = PositionInfo(dx: 100, dy: 200);
      const size = SizeInfo(width: 300, height: 400);

      final metadata1 = NodeMetadata(
        id: 'node_1',
        title: 'Test Node',
        position: position,
        size: size,
        filePath: '/path/to/node_1.md',
        referencedNodeIds: [],
        createdAt: now,
        updatedAt: now,
      );

      final metadata2 = NodeMetadata(
        id: 'node_1',
        title: 'Different Title',
        position: position,
        size: size,
        filePath: '/different/path.md',
        referencedNodeIds: ['node_2'],
        createdAt: now,
        updatedAt: now,
      );

      expect(metadata1.hashCode, metadata2.hashCode);
    });

    test('应该处理空的referencedNodeIds', () {
      const position = PositionInfo(dx: 100, dy: 200);
      const size = SizeInfo(width: 300, height: 400);

      final metadata = NodeMetadata(
        id: 'node_1',
        title: 'Test Node',
        position: position,
        size: size,
        filePath: '/path/to/node_1.md',
        referencedNodeIds: [],
        createdAt: now,
        updatedAt: now,
      );

      expect(metadata.referencedNodeIds, isEmpty);
    });
  });

  group('MetadataIndex - 元数据索引', () {
    late DateTime now;

    setUp(() {
      now = DateTime.now();
    });

    test('应该使用正确的属性创建MetadataIndex', () {
      const position1 = PositionInfo(dx: 100, dy: 200);
      const size1 = SizeInfo(width: 300, height: 400);

      const position2 = PositionInfo(dx: 300, dy: 400);
      const size2 = SizeInfo(width: 300, height: 400);

      final nodes = [
        NodeMetadata(
          id: 'node_1',
          title: 'Node 1',
          position: position1,
          size: size1,
          filePath: '/path/to/node_1.md',
          referencedNodeIds: [],
          createdAt: now,
          updatedAt: now,
        ),
        NodeMetadata(
          id: 'node_2',
          title: 'Node 2',
          position: position2,
          size: size2,
          filePath: '/path/to/node_2.md',
          referencedNodeIds: [],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final index = MetadataIndex(
        nodes: nodes,
        lastUpdated: now,
      );

      expect(index.nodes.length, 2);
      expect(index.lastUpdated, now);
    });

    test('应该创建空的MetadataIndex', () {
      final index = MetadataIndex(
        nodes: [],
        lastUpdated: now,
      );

      expect(index.nodes, isEmpty);
      expect(index.lastUpdated, now);
    });

    test('应该序列化为JSON', () {
      const position = PositionInfo(dx: 100, dy: 200);
      const size = SizeInfo(width: 300, height: 400);

      final nodes = [
        NodeMetadata(
          id: 'node_1',
          title: 'Node 1',
          position: position,
          size: size,
          filePath: '/path/to/node_1.md',
          referencedNodeIds: [],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final index = MetadataIndex(
        nodes: nodes,
        lastUpdated: now,
      );

      final json = index.toJson();

      expect(json['nodes'], isNotNull);
      expect(json['nodes'] is List, true);
      expect(json['lastUpdated'], isNotNull);
    });

    test('应该从JSON反序列化', () {
      final json = {
        'nodes': [
          {
            'id': 'node_1',
            'title': 'Node 1',
            'position': {'dx': 100.0, 'dy': 200.0},
            'size': {'width': 300.0, 'height': 400.0},
            'filePath': '/path/to/node_1.md',
            'referencedNodeIds': [],
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        ],
        'lastUpdated': now.toIso8601String(),
      };

      final index = MetadataIndex.fromJson(json);

      expect(index.nodes.length, 1);
      expect(index.nodes[0].id, 'node_1');
      expect(index.lastUpdated, isNotNull);
    });

    test('应该处理索引中的多个节点', () {
      const position1 = PositionInfo(dx: 100, dy: 200);
      const size1 = SizeInfo(width: 300, height: 400);

      const position2 = PositionInfo(dx: 300, dy: 400);
      const size2 = SizeInfo(width: 300, height: 400);

      const position3 = PositionInfo(dx: 500, dy: 600);
      const size3 = SizeInfo(width: 300, height: 400);

      final nodes = [
        NodeMetadata(
          id: 'node_1',
          title: 'Node 1',
          position: position1,
          size: size1,
          filePath: '/path/to/node_1.md',
          referencedNodeIds: ['node_2', 'node_3'],
          createdAt: now,
          updatedAt: now,
        ),
        NodeMetadata(
          id: 'node_2',
          title: 'Node 2',
          position: position2,
          size: size2,
          filePath: '/path/to/node_2.md',
          referencedNodeIds: [],
          createdAt: now,
          updatedAt: now,
        ),
        NodeMetadata(
          id: 'node_3',
          title: 'Node 3',
          position: position3,
          size: size3,
          filePath: '/path/to/node_3.md',
          referencedNodeIds: [],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final index = MetadataIndex(
        nodes: nodes,
        lastUpdated: now,
      );

      expect(index.nodes.length, 3);
      expect(index.nodes[0].referencedNodeIds.length, 2);
      expect(index.nodes[1].referencedNodeIds.isEmpty, true);
    });

    test('应该完成序列化往返', () {
      const position = PositionInfo(dx: 100, dy: 200);
      const size = SizeInfo(width: 300, height: 400);

      final nodes = [
        NodeMetadata(
          id: 'node_1',
          title: 'Node 1',
          position: position,
          size: size,
          filePath: '/path/to/node_1.md',
          referencedNodeIds: [],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final originalIndex = MetadataIndex(
        nodes: nodes,
        lastUpdated: now,
      );

      final json = originalIndex.toJson();
      final restoredIndex = MetadataIndex.fromJson(json);

      expect(restoredIndex.nodes.length, originalIndex.nodes.length);
      expect(restoredIndex.nodes[0].id, originalIndex.nodes[0].id);
      expect(restoredIndex.nodes[0].title, originalIndex.nodes[0].title);
      expect(restoredIndex.nodes[0].position.dx, originalIndex.nodes[0].position.dx);
      expect(restoredIndex.nodes[0].position.dy, originalIndex.nodes[0].position.dy);
      expect(restoredIndex.nodes[0].size.width, originalIndex.nodes[0].size.width);
      expect(restoredIndex.nodes[0].size.height, originalIndex.nodes[0].size.height);
    });
  });
}
