import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/ui_layout/coordinate_system.dart';
import 'package:node_graph_notebook/core/ui_layout/layout_strategy.dart';
import 'package:node_graph_notebook/core/ui_layout/node_attachment.dart';
import 'package:node_graph_notebook/core/ui_layout/ui_hook_tree.dart';

void main() {
  group('UIHookNode', () {
    test('创建根Hook', () {
      final root = UIHookNode.root();

      expect(root.id, 'root');
      expect(root.hookPointId, 'root');
      expect(root.localPosition, const LocalPosition.absolute(0, 0));
      expect(root.size, Size.infinite);
      expect(root.parent, isNull);
      expect(root.children, isEmpty);
      expect(root.attachedNodes, isEmpty);
    });

    test('创建带属性的Hook', () {
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

    test('添加子Hook', () {
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

    test('移除子Hook', () {
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

    test('移除不存在的子节点返回null', () {
      final parent = UIHookNode.root();

      final removed = parent.removeChild('non-existent');

      expect(removed, isNull);
    });

    test('通过ID查找子节点', () {
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

    test('通过ID查找后代节点', () {
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

    test('查找不存在的子节点返回null', () {
      final parent = UIHookNode.root();

      final found = parent.findChild('non-existent');

      expect(found, isNull);
    });

    test('通过hook点ID查找', () {
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

    test('将节点附加到Hook', () {
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

    test('从Hook分离节点', () {
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

    test('分离不存在的节点返回null', () {
      final hook = UIHookNode.root();

      final detached = hook.detachNode('non-existent');

      expect(detached, isNull);
    });

    test('附加重复节点时抛出异常', () {
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

    test('更新节点位置', () {
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

    test('更新不存在节点位置时抛出异常', () {
      final hook = UIHookNode.root();

      expect(
        () => hook.updateNodePosition(
          'non-existent',
          const LocalPosition.absolute(10, 20),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('获取已附加的节点', () {
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

    test('检查节点是否已附加', () {
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

    test('获取从根节点开始的路径', () {
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

    test('计算深度', () {
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

    test('获取所有后代节点', () {
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

    test('统计总附加节点数', () {
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

    test('toString包含相关信息', () {
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

    test('添加已有父节点的子节点时抛出异常', () {
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
    test('使用默认值创建配置', () {
      const config = LayoutConfig(strategy: LayoutStrategy.absolute);

      expect(config.strategy, LayoutStrategy.absolute);
      expect(config.direction, Axis.vertical);
      expect(config.spacing, 0.0);
      expect(config.crossAxisSpacing, 0.0);
      expect(config.padding, EdgeInsets.zero);
      expect(config.columns, isNull);
      expect(config.customCalculator, isNull);
    });

    test('使用指定值创建配置', () {
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

    test('copyWith创建新配置', () {
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
      expect(config.spacing, 8.0); // 原配置未改变
    });

    test('自定义策略无计算器时抛出异常', () {
      expect(
        () => LayoutConfig(strategy: LayoutStrategy.custom),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('NodeAttachment', () {
    test('创建附件', () {
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

    test('使用默认值创建附件', () {
      const attachment = NodeAttachment(
        nodeId: 'node-1',
        localPosition: LocalPosition.absolute(10, 20),
      );

      expect(attachment.zIndex, 0);
      expect(attachment.size, isNull);
      expect(attachment.metadata, isNull);
    });

    test('copyWith创建新附件', () {
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
      expect(attachment.zIndex, 0); // 原附件未改变
    });

    test('相等性判断正常工作', () {
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
