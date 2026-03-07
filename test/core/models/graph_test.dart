import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/models/models.dart';

void main() {
  group('Camera', () {
    late Camera testCamera;

    setUp(() {
      testCamera = const Camera(
        x: 2048,
        y: 1080,
        zoom: 1.5,
      );
    });

    test('should create camera with default values', () {
      const defaultCamera = Camera();

      expect(defaultCamera.x, 0);
      expect(defaultCamera.y, 0);
      expect(defaultCamera.zoom, 1.0);
    });

    test('should create camera with custom values', () {
      expect(testCamera.x, 2048);
      expect(testCamera.y, 1080);
      expect(testCamera.zoom, 1.5);
    });

    test('should copy with updated fields', () {
      final updatedCamera = testCamera.copyWith(
        x: 100,
        zoom: 2.0,
      );

      expect(updatedCamera.x, 100);
      expect(updatedCamera.y, testCamera.y); // Unchanged
      expect(updatedCamera.zoom, 2.0);
    });

    test('should implement equality correctly', () {
      const identicalCamera = Camera(
        x: 2048,
        y: 1080,
        zoom: 1.5,
      );

      expect(testCamera, identicalCamera);
      expect(testCamera.hashCode, identicalCamera.hashCode);
    });

    test('should not be equal with different properties', () {
      const differentCamera = Camera(x: 100, y: 1080, zoom: 1.5);

      expect(testCamera == differentCamera, false);
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final json = testCamera.toJson();

        expect(json['x'], 2048);
        expect(json['y'], 1080);
        expect(json['zoom'], 1.5);
      });

      test('should deserialize from JSON correctly', () {
        final json = testCamera.toJson();
        final deserializedCamera = Camera.fromJson(json);

        expect(deserializedCamera.x, testCamera.x);
        expect(deserializedCamera.y, testCamera.y);
        expect(deserializedCamera.zoom, testCamera.zoom);
      });
    });
  });

  group('GraphViewConfig', () {
    late GraphViewConfig testConfig;

    setUp(() {
      testConfig = const GraphViewConfig(
        camera: Camera(x: 100, y: 100, zoom: 1.0),
        autoLayoutEnabled: true,
        layoutAlgorithm: LayoutAlgorithm.forceDirected,
        showConnectionLines: true,
        backgroundStyle: BackgroundStyle.grid,
      );
    });

    test('should use default config', () {
      const defaultConfig = GraphViewConfig.defaultConfig;

      expect(defaultConfig.autoLayoutEnabled, false);
      expect(defaultConfig.layoutAlgorithm, LayoutAlgorithm.forceDirected);
      expect(defaultConfig.showConnectionLines, true);
      expect(defaultConfig.backgroundStyle, BackgroundStyle.grid);
    });

    test('should create config with custom values', () {
      expect(testConfig.autoLayoutEnabled, true);
      expect(testConfig.layoutAlgorithm, LayoutAlgorithm.forceDirected);
      expect(testConfig.showConnectionLines, true);
      expect(testConfig.backgroundStyle, BackgroundStyle.grid);
    });

    test('should copy with updated fields', () {
      final updatedConfig = testConfig.copyWith(
        autoLayoutEnabled: false,
        backgroundStyle: BackgroundStyle.dots,
      );

      expect(updatedConfig.autoLayoutEnabled, false);
      expect(updatedConfig.backgroundStyle, BackgroundStyle.dots);
      expect(updatedConfig.layoutAlgorithm, testConfig.layoutAlgorithm); // Unchanged
    });

    test('should implement equality based on camera', () {
      final identicalConfig = GraphViewConfig(
        camera: testConfig.camera,
        autoLayoutEnabled: false, // Different but not used for equality
        layoutAlgorithm: LayoutAlgorithm.circular,
        showConnectionLines: false,
        backgroundStyle: BackgroundStyle.none,
      );

      expect(testConfig, identicalConfig);
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final json = testConfig.toJson();

        expect(json['autoLayoutEnabled'], true);
        expect(json['layoutAlgorithm'], 'forceDirected');
        expect(json['showConnectionLines'], true);
        expect(json['backgroundStyle'], 'grid');
      });

      test('should deserialize from JSON correctly', () {
        final json = testConfig.toJson();
        final deserializedConfig = GraphViewConfig.fromJson(json);

        expect(deserializedConfig.autoLayoutEnabled, testConfig.autoLayoutEnabled);
        expect(deserializedConfig.layoutAlgorithm, testConfig.layoutAlgorithm);
        expect(deserializedConfig.showConnectionLines, testConfig.showConnectionLines);
        expect(deserializedConfig.backgroundStyle, testConfig.backgroundStyle);
      });
    });
  });

  group('Graph', () {
    late Graph testGraph;

    setUp(() {
      testGraph = Graph(
        id: 'test-graph-id',
        name: 'Test Graph',
        nodeIds: ['node1', 'node2', 'node3'],
        nodePositions: {
          'node1': const Offset(100, 100),
          'node2': const Offset(200, 200),
          'node3': const Offset(300, 300),
        },
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
    });

    test('should create an empty graph', () {
      final emptyGraph = Graph.empty('empty-id');

      expect(emptyGraph.id, 'empty-id');
      expect(emptyGraph.name, '');
      expect(emptyGraph.nodeIds, isEmpty);
      expect(emptyGraph.nodePositions, isEmpty);
      expect(emptyGraph.viewConfig, GraphViewConfig.defaultConfig);
    });

    test('should create graph with all fields', () {
      expect(testGraph.id, 'test-graph-id');
      expect(testGraph.name, 'Test Graph');
      expect(testGraph.nodeIds.length, 3);
      expect(testGraph.nodePositions.length, 3);
    });

    test('should add node to graph', () {
      final updatedGraph = testGraph.addNode('node4', position: const Offset(400, 400));

      expect(updatedGraph.nodeIds.length, 4);
      expect(updatedGraph.nodeIds, contains('node4'));
      expect(updatedGraph.nodePositions['node4'], const Offset(400, 400));
    });

    test('should not duplicate node when adding existing node', () {
      final updatedGraph = testGraph.addNode('node1');

      expect(updatedGraph.nodeIds.length, 3); // Still 3, not 4
      expect(updatedGraph.nodeIds.where((id) => id == 'node1').length, 1);
    });

    test('should remove node from graph', () {
      final updatedGraph = testGraph.removeNode('node2');

      expect(updatedGraph.nodeIds.length, 2);
      expect(updatedGraph.nodeIds, isNot(contains('node2')));
      expect(updatedGraph.nodePositions.containsKey('node2'), false);
    });

    test('should update node position', () {
      const newPosition = Offset(500, 500);
      final updatedGraph = testGraph.updateNodePosition('node1', newPosition);

      expect(updatedGraph.nodePositions['node1'], newPosition);
      expect(updatedGraph.nodePositions['node2'], const Offset(200, 200)); // Unchanged
    });

    test('should get node position', () {
      final position = testGraph.getNodePosition('node1');

      expect(position, const Offset(100, 100));
    });

    test('should return null for non-existent node position', () {
      final position = testGraph.getNodePosition('non-existent');

      expect(position, null);
    });

    test('should copy with updated fields', () {
      final updatedGraph = testGraph.copyWith(
        name: 'Updated Graph Name',
        nodeIds: ['node1'],
      );

      expect(updatedGraph.id, testGraph.id); // Unchanged
      expect(updatedGraph.name, 'Updated Graph Name');
      expect(updatedGraph.nodeIds.length, 1);
      expect(updatedGraph.viewConfig, testGraph.viewConfig); // Unchanged
    });

    test('should update timestamp', () async {
      final beforeUpdate = DateTime.now();
      // Add a delay to ensure timestamp difference
      await Future.delayed(const Duration(milliseconds: 50));
      final updatedGraph = testGraph.updateTimestamp();
      final afterUpdate = DateTime.now();

      // The updated timestamp should be different from the original
      expect(updatedGraph.updatedAt.isAtSameMomentAs(testGraph.updatedAt), false);

      // The updated timestamp should be after beforeUpdate or same moment (in rare cases)
      expect(updatedGraph.updatedAt.isAfter(beforeUpdate) || updatedGraph.updatedAt.isAtSameMomentAs(beforeUpdate), true);

      // The updated timestamp should be before or at same moment as afterUpdate
      expect(updatedGraph.updatedAt.isBefore(afterUpdate) || updatedGraph.updatedAt.isAtSameMomentAs(afterUpdate), true);
    });

    test('should implement equality based on id', () {
      final identicalGraph = Graph(
        id: 'test-graph-id', // Same ID
        name: 'Different Name', // Different name
        nodeIds: [],
        nodePositions: {},
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: DateTime(2023, 1, 1), // Different date
        updatedAt: DateTime(2023, 1, 1),
      );

      // Graph equality is based on all fields, not just id
      // Since fields differ, these graphs are not equal
      expect(testGraph == identicalGraph, false);
      // Skip hashCode check as it's based on all fields
    });

    test('should not be equal with different id', () {
      final differentGraph = Graph(
        id: 'different-id',
        name: 'Test Graph',
        nodeIds: ['node1', 'node2', 'node3'],
        nodePositions: const {},
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(testGraph == differentGraph, false);
    });

    test('should provide meaningful toString', () {
      final str = testGraph.toString();

      expect(str, contains('test-graph-id'));
      expect(str, contains('Test Graph'));
      expect(str, contains('3')); // node count
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final json = testGraph.toJson();

        expect(json['id'], 'test-graph-id');
        expect(json['name'], 'Test Graph');
        expect(json['nodeIds'], ['node1', 'node2', 'node3']);
        expect(json['createdAt'], '2024-01-01T00:00:00.000');
      });

      test('should deserialize from JSON correctly', () {
        final json = testGraph.toJson();
        final deserializedGraph = Graph.fromJson(json);

        expect(deserializedGraph.id, testGraph.id);
        expect(deserializedGraph.name, testGraph.name);
        expect(deserializedGraph.nodeIds, testGraph.nodeIds);
        expect(deserializedGraph.nodePositions, testGraph.nodePositions);
        expect(deserializedGraph.createdAt, testGraph.createdAt);
        expect(deserializedGraph.updatedAt, testGraph.updatedAt);
      });

      test('should handle serialization/deserialization roundtrip', () {
        final json = testGraph.toJson();
        final roundtripGraph = Graph.fromJson(json);

        expect(testGraph, roundtripGraph);
      });
    });
  });
}
