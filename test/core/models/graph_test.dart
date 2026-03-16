import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/graph.dart';

void main() {
  group('Graph', () {
    late Graph graph;
    late DateTime now;

    setUp(() {
      now = DateTime.now();
      graph = Graph(
        id: 'graph_1',
        name: 'Test Graph',
        nodeIds: ['node_1', 'node_2'],
        nodePositions: {
          'node_1': const Offset(100, 200),
          'node_2': const Offset(300, 400),
        },
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: now,
        updatedAt: now,
      );
    });

    test('should create a Graph instance with correct properties', () {
      expect(graph.id, 'graph_1');
      expect(graph.name, 'Test Graph');
      expect(graph.nodeIds, ['node_1', 'node_2']);
      expect(graph.nodePositions.length, 2);
      expect(graph.nodePositions['node_1'], const Offset(100, 200));
      expect(graph.nodePositions['node_2'], const Offset(300, 400));
      expect(graph.viewConfig, GraphViewConfig.defaultConfig);
      expect(graph.createdAt, now);
      expect(graph.updatedAt, now);
    });

    test('should create an empty graph', () {
      final emptyGraph = Graph.empty('empty_graph');
      expect(emptyGraph.id, 'empty_graph');
      expect(emptyGraph.name, '');
      expect(emptyGraph.nodeIds, isEmpty);
      expect(emptyGraph.nodePositions, isEmpty);
      expect(emptyGraph.viewConfig, GraphViewConfig.defaultConfig);
      expect(emptyGraph.createdAt, isNotNull);
      expect(emptyGraph.updatedAt, isNotNull);
    });

    test('should add a node', () {
      final updatedGraph = graph.addNode('node_3', position: const Offset(500, 600));
      expect(updatedGraph.nodeIds.length, 3);
      expect(updatedGraph.nodeIds.contains('node_3'), true);
      expect(updatedGraph.nodePositions['node_3'], const Offset(500, 600));
    });

    test('should add a node without position', () {
      final updatedGraph = graph.addNode('node_3');
      expect(updatedGraph.nodeIds.length, 3);
      expect(updatedGraph.nodeIds.contains('node_3'), true);
      expect(updatedGraph.nodePositions.containsKey('node_3'), false);
    });

    test('should not duplicate existing node', () {
      final updatedGraph = graph.addNode('node_1', position: const Offset(999, 999));
      expect(updatedGraph.nodeIds.length, 2);
      expect(updatedGraph.nodePositions['node_1'], const Offset(999, 999));
    });

    test('should remove a node', () {
      final updatedGraph = graph.removeNode('node_1');
      expect(updatedGraph.nodeIds.length, 1);
      expect(updatedGraph.nodeIds.contains('node_1'), false);
      expect(updatedGraph.nodePositions.containsKey('node_1'), false);
    });

    test('should update node position', () {
      final updatedGraph = graph.updateNodePosition('node_1', const Offset(999, 999));
      expect(updatedGraph.nodePositions['node_1'], const Offset(999, 999));
    });

    test('should get node position', () {
      expect(graph.getNodePosition('node_1'), const Offset(100, 200));
      expect(graph.getNodePosition('non_existent'), null);
    });

    test('should update timestamp', () {
      final updatedGraph = graph.updateTimestamp();
      expect(updatedGraph.updatedAt.isAfter(now) || updatedGraph.updatedAt.isAtSameMomentAs(now), true);
    });

    test('should copy with updated fields', () {
      final updatedGraph = graph.copyWith(
        name: 'Updated Graph',
      );
      expect(updatedGraph.name, 'Updated Graph');
      expect(updatedGraph.id, graph.id); // Should remain the same
    });

    test('should have correct equality check', () {
      final sameGraph = Graph(
        id: 'graph_1',
        name: 'Test Graph',
        nodeIds: ['node_1', 'node_2'],
        nodePositions: {
          'node_1': const Offset(100, 200),
          'node_2': const Offset(300, 400),
        },
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: now,
        updatedAt: now,
      );

      final differentGraph = graph.copyWith(id: 'graph_2');

      expect(graph == sameGraph, true);
      expect(graph == differentGraph, false);
    });

    test('should have correct hashCode', () {
      expect(graph.hashCode, isNotNull);
    });

    test('should have correct toString', () {
      expect(graph.toString(), 'Graph(id: graph_1, name: Test Graph, nodes: 2)');
    });
  });

  group('GraphViewConfig', () {
    test('should create a GraphViewConfig with correct properties', () {
      const config = GraphViewConfig(
        camera: Camera(),
        autoLayoutEnabled: true,
        layoutAlgorithm: LayoutAlgorithm.hierarchical,
        showConnectionLines: false,
        backgroundStyle: BackgroundStyle.none,
      );

      expect(config.camera, isNotNull);
      expect(config.autoLayoutEnabled, true);
      expect(config.layoutAlgorithm, LayoutAlgorithm.hierarchical);
      expect(config.showConnectionLines, false);
      expect(config.backgroundStyle, BackgroundStyle.none);
    });

    test('should have default config', () {
      const defaultConfig = GraphViewConfig.defaultConfig;
      expect(defaultConfig.camera, isNotNull);
      expect(defaultConfig.autoLayoutEnabled, false);
      expect(defaultConfig.layoutAlgorithm, LayoutAlgorithm.forceDirected);
      expect(defaultConfig.showConnectionLines, true);
      expect(defaultConfig.backgroundStyle, BackgroundStyle.grid);
    });

    test('should copy with updated fields', () {
      const config = GraphViewConfig.defaultConfig;
      final updatedConfig = config.copyWith(autoLayoutEnabled: true);
      expect(updatedConfig.autoLayoutEnabled, true);
    });
  });

  group('Camera', () {
    test('should create a Camera with correct properties', () {
      const camera = Camera(
        x: 100,
        y: 200,
        zoom: 1.5,
        centerWidth: 800,
        centerHeight: 600,
      );

      expect(camera.x, 100);
      expect(camera.y, 200);
      expect(camera.zoom, 1.5);
      expect(camera.centerWidth, 800);
      expect(camera.centerHeight, 600);
    });

    test('should have default values', () {
      const camera = Camera();
      expect(camera.x, 0);
      expect(camera.y, 0);
      expect(camera.zoom, 1.0);
      expect(camera.centerWidth, 4096);
      expect(camera.centerHeight, 2160);
    });

    test('should get center position', () {
      const camera = Camera(centerWidth: 800, centerHeight: 600);
      expect(camera.centerPosition, const Offset(400, 300));
    });

    test('should copy with updated fields', () {
      const camera = Camera();
      final updatedCamera = camera.copyWith(zoom: 2);
      expect(updatedCamera.zoom, 2.0);
    });

    test('should have correct equality check', () {
      const camera1 = Camera(x: 100, y: 200);
      const camera2 = Camera(x: 100, y: 200);
      const camera3 = Camera(x: 300, y: 400);

      expect(camera1 == camera2, true);
      expect(camera1 == camera3, false);
    });
  });
}
