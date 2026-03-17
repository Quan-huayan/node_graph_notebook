import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/plugins/layout/service/layout_service.dart';

void main() {
  group('LayoutService', () {
    late LayoutServiceImpl layoutService;

    setUp(() {
      layoutService = LayoutServiceImpl();
    });

    group('forceDirectedLayout', () {
      test('should handle empty node list', () async {
        await layoutService.forceDirectedLayout(nodes: <Node>[]);

        expect(layoutService.lastLayoutPositions, isEmpty);
      });

      test('should layout single node', () async {
        final node = Node(
          id: 'node_1',
          title: 'Test Node',
          content: 'Content',
          references: const {},
          position: const Offset(0, 0),
          size: const Size(200, 150),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await layoutService.forceDirectedLayout(nodes: <Node>[node]);

        expect(layoutService.lastLayoutPositions.length, 1);
        expect(layoutService.lastLayoutPositions.containsKey('node_1'), true);
      });

      test('should layout multiple nodes', () async {
        final nodes = <Node>[
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
          Node(
            id: 'node_2',
            title: 'Node 2',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
          Node(
            id: 'node_3',
            title: 'Node 3',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        await layoutService.forceDirectedLayout(nodes: nodes);

        expect(layoutService.lastLayoutPositions.length, 3);
        expect(layoutService.lastLayoutPositions.containsKey('node_1'), true);
        expect(layoutService.lastLayoutPositions.containsKey('node_2'), true);
        expect(layoutService.lastLayoutPositions.containsKey('node_3'), true);
      });

      test('should respect node references', () async {
        final nodes = <Node>[
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content',
            references: const {'node_2': NodeReference(nodeId: 'node_2', properties: {'type': 'link'})},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
          Node(
            id: 'node_2',
            title: 'Node 2',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        await layoutService.forceDirectedLayout(nodes: nodes);

        expect(layoutService.lastLayoutPositions.length, 2);
        final pos1 = layoutService.lastLayoutPositions['node_1']!;
        final pos2 = layoutService.lastLayoutPositions['node_2']!;

        final distance = (pos1 - pos2).distance;
        expect(distance, greaterThan(0));
      });

      test('should use custom options', () async {
        final nodes = <Node>[
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        const options = ForceDirectedOptions(
          repulsion: 500,
          attraction: 0.05,
          iterations: 50,
          damping: 0.8,
        );

        await layoutService.forceDirectedLayout(
          nodes: nodes,
          options: options,
        );

        expect(layoutService.lastLayoutPositions.length, 1);
      });
    });

    group('hierarchicalLayout', () {
      test('should handle empty node list', () async {
        await layoutService.hierarchicalLayout(nodes: <Node>[]);

        expect(layoutService.lastLayoutPositions, isEmpty);
      });

      test('should layout single node', () async {
        final node = Node(
          id: 'node_1',
          title: 'Test Node',
          content: 'Content',
          references: const {},
          position: const Offset(0, 0),
          size: const Size(200, 150),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await layoutService.hierarchicalLayout(nodes: <Node>[node]);

        expect(layoutService.lastLayoutPositions.length, 1);
        expect(layoutService.lastLayoutPositions.containsKey('node_1'), true);
      });

      test('should layout nodes with references', () async {
        final nodes = <Node>[
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content',
            references: const {
              'node_2': NodeReference(nodeId: 'node_2', properties: {'type': 'link'}),
              'node_3': NodeReference(nodeId: 'node_3', properties: {'type': 'link'}),
            },
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
          Node(
            id: 'node_2',
            title: 'Node 2',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
          Node(
            id: 'node_3',
            title: 'Node 3',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        await layoutService.hierarchicalLayout(nodes: nodes);

        expect(layoutService.lastLayoutPositions.length, 3);
        final pos1 = layoutService.lastLayoutPositions['node_1']!;
        final pos2 = layoutService.lastLayoutPositions['node_2']!;
        final pos3 = layoutService.lastLayoutPositions['node_3']!;

        expect(pos1.dy, lessThan(pos2.dy));
        expect(pos1.dy, lessThan(pos3.dy));
      });

      test('should handle multiple root nodes', () async {
        final nodes = <Node>[
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
          Node(
            id: 'node_2',
            title: 'Node 2',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        await layoutService.hierarchicalLayout(nodes: nodes);

        expect(layoutService.lastLayoutPositions.length, 2);
        final pos1 = layoutService.lastLayoutPositions['node_1']!;
        final pos2 = layoutService.lastLayoutPositions['node_2']!;

        expect(pos1.dy, equals(pos2.dy));
      });

      test('should use custom options', () async {
        final nodes = <Node>[
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        const options = HierarchicalOptions(
          nodeSpacing: 150,
          levelSpacing: 200,
          nodeWidth: 400,
          nodeHeight: 250,
        );

        await layoutService.hierarchicalLayout(
          nodes: nodes,
          options: options,
        );

        expect(layoutService.lastLayoutPositions.length, 1);
      });
    });

    group('circularLayout', () {
      test('should handle empty node list', () async {
        await layoutService.circularLayout(nodes: <Node>[]);

        expect(layoutService.lastLayoutPositions, isEmpty);
      });

      test('should layout single node', () async {
        final node = Node(
          id: 'node_1',
          title: 'Test Node',
          content: 'Content',
          references: const {},
          position: const Offset(0, 0),
          size: const Size(200, 150),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        await layoutService.circularLayout(nodes: <Node>[node]);

        expect(layoutService.lastLayoutPositions.length, 1);
        expect(layoutService.lastLayoutPositions.containsKey('node_1'), true);
      });

      test('should layout nodes in circle', () async {
        final nodes = List<Node>.generate(
          4,
          (i) => Node(
            id: 'node_$i',
            title: 'Node $i',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        );

        await layoutService.circularLayout(nodes: nodes);

        expect(layoutService.lastLayoutPositions.length, 4);

        final positions = layoutService.lastLayoutPositions.values.toList();
        const center = Offset(640, 400);
        const radius = 300.0;

        for (final pos in positions) {
          final distance = (pos - center).distance;
          expect(distance, closeTo(radius, 1.0));
        }
      });

      test('should distribute nodes evenly', () async {
        final nodes = List<Node>.generate(
          4,
          (i) => Node(
            id: 'node_$i',
            title: 'Node $i',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        );

        await layoutService.circularLayout(nodes: nodes);

        final positions = layoutService.lastLayoutPositions.values.toList();
        const center = Offset(640, 400);

        final angles = positions.map((pos) {
          final dx = pos.dx - center.dx;
          final dy = pos.dy - center.dy;
          return (atan2(dy, dx) + 2 * pi) % (2 * pi);
        }).toList()
        ..sort();

        for (var i = 1; i < angles.length; i++) {
          final angleDiff = (angles[i] - angles[i - 1] + 2 * pi) % (2 * pi);
          final expectedAngle = 2 * pi / nodes.length;
          expect(angleDiff, closeTo(expectedAngle, 0.1));
        }
      });

      test('should use custom options', () async {
        final nodes = <Node>[
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        const options = CircularOptions(
          radius: 500,
          nodeSpacing: 150,
          levelSpacing: 200,
        );

        await layoutService.circularLayout(
          nodes: nodes,
          options: options,
        );

        expect(layoutService.lastLayoutPositions.length, 1);
        final pos = layoutService.lastLayoutPositions['node_1']!;
        const center = Offset(640, 400);
        final distance = (pos - center).distance;
        expect(distance, closeTo(500.0, 1.0));
      });
    });

    group('applyLayout', () {
      test('should apply force directed layout', () async {
        final nodes = <Node>[
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        final result = await layoutService.applyLayout(
          nodes: nodes,
          algorithm: LayoutAlgorithm.forceDirected,
        );

        expect(result.length, 1);
        expect(result.containsKey('node_1'), true);
      });

      test('should apply hierarchical layout', () async {
        final nodes = <Node>[
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        final result = await layoutService.applyLayout(
          nodes: nodes,
          algorithm: LayoutAlgorithm.hierarchical,
        );

        expect(result.length, 1);
        expect(result.containsKey('node_1'), true);
      });

      test('should apply circular layout', () async {
        final nodes = <Node>[
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        final result = await layoutService.applyLayout(
          nodes: nodes,
          algorithm: LayoutAlgorithm.circular,
        );

        expect(result.length, 1);
        expect(result.containsKey('node_1'), true);
      });

      test('should handle free layout', () async {
        final nodes = <Node>[
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content',
            references: const {},
            position: const Offset(100, 200),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        final result = await layoutService.applyLayout(
          nodes: nodes,
          algorithm: LayoutAlgorithm.free,
        );

        expect(result, isEmpty);
      });

      test('should return unmodifiable map', () async {
        final nodes = <Node>[
          Node(
            id: 'node_1',
            title: 'Node 1',
            content: 'Content',
            references: const {},
            position: const Offset(0, 0),
            size: const Size(200, 150),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        final result = await layoutService.applyLayout(
          nodes: nodes,
          algorithm: LayoutAlgorithm.forceDirected,
        );

        expect(
          () => result['node_2'] = const Offset(0, 0),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('LayoutOptions', () {
      test('should create default options', () {
        const options = LayoutOptions();

        expect(options.nodeSpacing, 100.0);
        expect(options.levelSpacing, 150.0);
        expect(options.alignToGrid, false);
      });

      test('should create custom options', () {
        const options = LayoutOptions(
          nodeSpacing: 150,
          levelSpacing: 200,
          alignToGrid: true,
        );

        expect(options.nodeSpacing, 150.0);
        expect(options.levelSpacing, 200.0);
        expect(options.alignToGrid, true);
      });
    });

    group('ForceDirectedOptions', () {
      test('should create default options', () {
        const options = ForceDirectedOptions();

        expect(options.nodeSpacing, 100.0);
        expect(options.levelSpacing, 150.0);
        expect(options.alignToGrid, false);
        expect(options.repulsion, 1000.0);
        expect(options.attraction, 0.1);
        expect(options.iterations, 100);
        expect(options.damping, 0.9);
      });

      test('should create custom options', () {
        const options = ForceDirectedOptions(
          repulsion: 500,
          attraction: 0.05,
          iterations: 50,
          damping: 0.8,
        );

        expect(options.repulsion, 500.0);
        expect(options.attraction, 0.05);
        expect(options.iterations, 50);
        expect(options.damping, 0.8);
      });
    });

    group('HierarchicalOptions', () {
      test('should create default options', () {
        const options = HierarchicalOptions();

        expect(options.nodeSpacing, 100.0);
        expect(options.levelSpacing, 150.0);
        expect(options.alignToGrid, false);
        expect(options.nodeWidth, 300.0);
        expect(options.nodeHeight, 200.0);
      });

      test('should create custom options', () {
        const options = HierarchicalOptions(
          nodeWidth: 400,
          nodeHeight: 250,
        );

        expect(options.nodeWidth, 400.0);
        expect(options.nodeHeight, 250.0);
      });
    });

    group('CircularOptions', () {
      test('should create default options', () {
        const options = CircularOptions();

        expect(options.nodeSpacing, 100.0);
        expect(options.levelSpacing, 150.0);
        expect(options.alignToGrid, false);
        expect(options.radius, 300.0);
      });

      test('should create custom options', () {
        const options = CircularOptions(radius: 500);

        expect(options.radius, 500.0);
      });
    });
  });
}
