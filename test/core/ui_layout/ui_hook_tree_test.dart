import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/ui_layout/coordinate_system.dart';
import 'package:node_graph_notebook/core/ui_layout/layout_strategy.dart';
import 'package:node_graph_notebook/core/ui_layout/node_attachment.dart';
import 'package:node_graph_notebook/core/ui_layout/ui_hook_tree.dart';

void main() {
  group('UIHookNode', () {
    test('creates root Hook', () {
      final root = UIHookNode.root();

      expect(root.id, 'root');
      expect(root.hookPointId, 'root');
      expect(root.localPosition, const LocalPosition.absolute(0, 0));
      expect(root.size, Size.infinite);
      expect(root.parent, isNull);
      expect(root.children, isEmpty);
      expect(root.attachedNodes, isEmpty);
    });

    test('creates Hook with properties', () {
      final hook = UIHookNode(
        id: 'test-hook',
        hookPointId: 'sidebar',
        localPosition: const LocalPosition.absolute(10, 20),
        size: const Size(300, 400),
        layoutConfig: const LayoutConfig(
          strategy: LayoutStrategy.sequential,
          direction: Axis.vertical,
        ),
      );

      expect(hook.id, 'test-hook');
      expect(hook.hookPointId, 'sidebar');
      expect(hook.size, const Size(300, 400));
      expect(hook.layoutConfig.strategy, LayoutStrategy.sequential);
      expect(hook.parent, isNull);
    });

    test('adds child Hook', () {
      final parent = UIHookNode.root();
      final child = UIHookNode(
        id: 'child',
        hookPointId: 'child',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(100, 100),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
      );

      parent.addChild(child);

      expect(parent.children, hasLength(1));
      expect(parent.children.first, child);
      expect(child.parent, parent);
    });

    test('removes child Hook', () {
      final parent = UIHookNode.root();
      final child = UIHookNode(
        id: 'child',
        hookPointId: 'child',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(100, 100),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: parent,
      );

      final removed = parent.removeChild('child');

      expect(removed, child);
      expect(parent.children, isEmpty);
      expect(child.parent, isNull);
    });

    test('removes non-existent child returns null', () {
      final parent = UIHookNode.root();

      final removed = parent.removeChild('non-existent');

      expect(removed, isNull);
    });

    test('finds child by ID', () {
      final parent = UIHookNode.root();
      final child = UIHookNode(
        id: 'child-1',
        hookPointId: 'child',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(100, 100),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: parent,
      );

      final found = parent.findChild('child-1');

      expect(found, child);
    });

    test('finds descendant child by ID', () {
      final root = UIHookNode.root();
      final child = UIHookNode(
        id: 'child',
        hookPointId: 'child',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(100, 100),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: root,
      );
      final grandchild = UIHookNode(
        id: 'grandchild',
        hookPointId: 'grandchild',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(50, 50),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: child,
      );

      final found = root.findChild('grandchild');

      expect(found, grandchild);
    });

    test('finds non-existent child returns null', () {
      final parent = UIHookNode.root();

      final found = parent.findChild('non-existent');

      expect(found, isNull);
    });

    test('finds by hook point ID', () {
      final root = UIHookNode.root();
      final sidebar = UIHookNode(
        id: 'sidebar-hook',
        hookPointId: 'sidebar',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(300, 600),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: root,
      );

      final found = root.findByHookPointId('sidebar');

      expect(found, sidebar);
    });

    test('attaches node to Hook', () {
      final hook = UIHookNode.root();
      const attachment = NodeAttachment(
        nodeId: 'node-1',
        localPosition: LocalPosition.absolute(10, 20),
        zIndex: 0,
      );

      hook.attachNode(attachment);

      expect(hook.attachedNodes, hasLength(1));
      expect(hook.attachedNodes['node-1'], attachment);
    });

    test('detaches node from Hook', () {
      final hook = UIHookNode.root();
      const attachment = NodeAttachment(
        nodeId: 'node-1',
        localPosition: LocalPosition.absolute(10, 20),
        zIndex: 0,
      );
      hook.attachNode(attachment);

      final detached = hook.detachNode('node-1');

      expect(detached, attachment);
      expect(hook.attachedNodes, isEmpty);
    });

    test('detaches non-existent node returns null', () {
      final hook = UIHookNode.root();

      final detached = hook.detachNode('non-existent');

      expect(detached, isNull);
    });

    test('throws when attaching duplicate node', () {
      final hook = UIHookNode.root();
      const attachment1 = NodeAttachment(
        nodeId: 'node-1',
        localPosition: LocalPosition.absolute(10, 20),
        zIndex: 0,
      );
      const attachment2 = NodeAttachment(
        nodeId: 'node-1',
        localPosition: LocalPosition.absolute(30, 40),
        zIndex: 1,
      );

      hook.attachNode(attachment1);

      expect(
        () => hook.attachNode(attachment2),
        throwsA(isA<StateError>()),
      );
    });

    test('updates node position', () {
      final hook = UIHookNode.root();
      const attachment = NodeAttachment(
        nodeId: 'node-1',
        localPosition: LocalPosition.absolute(10, 20),
        zIndex: 0,
      );
      hook.attachNode(attachment);

      const newPosition = LocalPosition.absolute(50, 100);
      hook.updateNodePosition('node-1', newPosition);

      final updated = hook.getAttachedNode('node-1');
      expect(updated?.localPosition, newPosition);
    });

    test('throws when updating non-existent node position', () {
      final hook = UIHookNode.root();

      expect(
        () => hook.updateNodePosition(
          'non-existent',
          const LocalPosition.absolute(10, 20),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('gets attached node', () {
      final hook = UIHookNode.root();
      const attachment = NodeAttachment(
        nodeId: 'node-1',
        localPosition: LocalPosition.absolute(10, 20),
        zIndex: 0,
      );
      hook.attachNode(attachment);

      final retrieved = hook.getAttachedNode('node-1');

      expect(retrieved, attachment);
    });

    test('checks if node is attached', () {
      final hook = UIHookNode.root();
      const attachment = NodeAttachment(
        nodeId: 'node-1',
        localPosition: LocalPosition.absolute(10, 20),
        zIndex: 0,
      );

      expect(hook.hasNodeAttached('node-1'), isFalse);

      hook.attachNode(attachment);

      expect(hook.hasNodeAttached('node-1'), isTrue);
    });

    test('gets path from root', () {
      final root = UIHookNode.root();
      final child = UIHookNode(
        id: 'child',
        hookPointId: 'child',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(100, 100),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: root,
      );
      final grandchild = UIHookNode(
        id: 'grandchild',
        hookPointId: 'grandchild',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(50, 50),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: child,
      );

      final path = grandchild.getPath();

      expect(path, ['root', 'child', 'grandchild']);
    });

    test('calculates depth', () {
      final root = UIHookNode.root();
      final child = UIHookNode(
        id: 'child',
        hookPointId: 'child',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(100, 100),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: root,
      );
      final grandchild = UIHookNode(
        id: 'grandchild',
        hookPointId: 'grandchild',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(50, 50),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: child,
      );

      expect(root.getDepth(), 0);
      expect(child.getDepth(), 1);
      expect(grandchild.getDepth(), 2);
    });

    test('gets all descendants', () {
      final root = UIHookNode.root();
      final child1 = UIHookNode(
        id: 'child-1',
        hookPointId: 'child',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(100, 100),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: root,
      );
      final child2 = UIHookNode(
        id: 'child-2',
        hookPointId: 'child',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(100, 100),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: root,
      );
      final grandchild = UIHookNode(
        id: 'grandchild',
        hookPointId: 'grandchild',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(50, 50),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: child1,
      );

      final descendants = root.getDescendants();

      expect(descendants, hasLength(3));
      expect(descendants, containsAll([child1, child2, grandchild]));
    });

    test('counts total attached nodes', () {
      final root = UIHookNode.root();
      root.attachNode(const NodeAttachment(
        nodeId: 'root-node',
        localPosition: LocalPosition.absolute(0, 0),
      ));

      final child = UIHookNode(
        id: 'child',
        hookPointId: 'child',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(100, 100),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: root,
      );
      child.attachNode(const NodeAttachment(
        nodeId: 'child-node-1',
        localPosition: LocalPosition.absolute(0, 0),
      ));
      child.attachNode(const NodeAttachment(
        nodeId: 'child-node-2',
        localPosition: LocalPosition.absolute(0, 0),
      ));

      expect(root.getTotalAttachedNodeCount(), 3);
      expect(child.getTotalAttachedNodeCount(), 2);
    });

    test('toString contains relevant info', () {
      final root = UIHookNode.root();
      final child = UIHookNode(
        id: 'child',
        hookPointId: 'sidebar',
        localPosition: const LocalPosition.absolute(10, 20),
        size: const Size(300, 400),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: root,
      );
      child.attachNode(const NodeAttachment(
        nodeId: 'node-1',
        localPosition: LocalPosition.absolute(0, 0),
      ));

      final str = child.toString();

      expect(str, contains('child'));
      expect(str, contains('sidebar'));
      expect(str, contains('depth: 1'));
      expect(str, contains('children: 0'));
      expect(str, contains('nodes: 1'));
    });

    test('throws when adding child with existing parent', () {
      final parent1 = UIHookNode.root();
      final parent2 = UIHookNode(
        id: 'parent2',
        hookPointId: 'parent',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(100, 100),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
      );
      final child = UIHookNode(
        id: 'child',
        hookPointId: 'child',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(50, 50),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: parent1,
      );

      expect(
        () => parent2.addChild(child),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('LayoutConfig', () {
    test('creates config with default values', () {
      const config = LayoutConfig(strategy: LayoutStrategy.absolute);

      expect(config.strategy, LayoutStrategy.absolute);
      expect(config.direction, Axis.vertical);
      expect(config.spacing, 0.0);
      expect(config.crossAxisSpacing, 0.0);
      expect(config.padding, EdgeInsets.zero);
      expect(config.columns, isNull);
      expect(config.customCalculator, isNull);
    });

    test('creates config with values', () {
      const config = LayoutConfig(
        strategy: LayoutStrategy.grid,
        direction: Axis.horizontal,
        spacing: 8,
        crossAxisSpacing: 4,
        padding: EdgeInsets.all(16),
        columns: 3,
      );

      expect(config.strategy, LayoutStrategy.grid);
      expect(config.direction, Axis.horizontal);
      expect(config.spacing, 8.0);
      expect(config.crossAxisSpacing, 4.0);
      expect(config.padding, const EdgeInsets.all(16));
      expect(config.columns, 3);
    });

    test('copyWith creates new config', () {
      const config = LayoutConfig(
        strategy: LayoutStrategy.sequential,
        direction: Axis.vertical,
        spacing: 8,
      );

      final copied = config.copyWith(
        spacing: 16,
        direction: Axis.horizontal,
      );

      expect(copied.strategy, LayoutStrategy.sequential);
      expect(copied.direction, Axis.horizontal);
      expect(copied.spacing, 16.0);
      expect(config.spacing, 8.0); // Original unchanged
    });

    test('throws on custom strategy without calculator', () {
      expect(
        () => LayoutConfig(strategy: LayoutStrategy.custom),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('NodeAttachment', () {
    test('creates attachment', () {
      const attachment = NodeAttachment(
        nodeId: 'node-1',
        localPosition: LocalPosition.absolute(10, 20),
        zIndex: 1,
        size: Size(100, 50),
      );

      expect(attachment.nodeId, 'node-1');
      expect(attachment.localPosition, const LocalPosition.absolute(10, 20));
      expect(attachment.zIndex, 1);
      expect(attachment.size, const Size(100, 50));
    });

    test('creates attachment with defaults', () {
      const attachment = NodeAttachment(
        nodeId: 'node-1',
        localPosition: LocalPosition.absolute(10, 20),
      );

      expect(attachment.zIndex, 0);
      expect(attachment.size, isNull);
      expect(attachment.metadata, isNull);
    });

    test('copyWith creates new attachment', () {
      const attachment = NodeAttachment(
        nodeId: 'node-1',
        localPosition: LocalPosition.absolute(10, 20),
        zIndex: 0,
      );

      final copied = attachment.copyWith(
        zIndex: 5,
        localPosition: const LocalPosition.absolute(30, 40),
      );

      expect(copied.nodeId, 'node-1');
      expect(copied.zIndex, 5);
      expect(copied.localPosition, const LocalPosition.absolute(30, 40));
      expect(attachment.zIndex, 0); // Original unchanged
    });

    test('equality works correctly', () {
      const attachment1 = NodeAttachment(
        nodeId: 'node-1',
        localPosition: LocalPosition.absolute(10, 20),
        zIndex: 0,
      );
      const attachment2 = NodeAttachment(
        nodeId: 'node-1',
        localPosition: LocalPosition.absolute(10, 20),
        zIndex: 0,
      );
      const attachment3 = NodeAttachment(
        nodeId: 'node-1',
        localPosition: LocalPosition.absolute(10, 20),
        zIndex: 1,
      );

      expect(attachment1, equals(attachment2));
      expect(attachment1, isNot(equals(attachment3)));
    });
  });
}
