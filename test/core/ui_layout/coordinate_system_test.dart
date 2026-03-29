import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/ui_layout/coordinate_system.dart';
import 'package:node_graph_notebook/core/ui_layout/layout_strategy.dart';
import 'package:node_graph_notebook/core/ui_layout/ui_hook_tree.dart';

void main() {
  group('LocalPosition', () {
    test('创建绝对位置', () {
      const pos = LocalPosition.absolute(10, 20);

      expect(pos.x, 10.0);
      expect(pos.y, 20.0);
      expect(pos.type, PositionType.absolute);
      expect(pos.proportionalValue, isNull);
    });

    test('创建比例位置', () {
      const pos = LocalPosition.proportional(0.5, 0.75);

      expect(pos.x, 0.5);
      expect(pos.y, 0.75);
      expect(pos.type, PositionType.proportional);
      expect(pos.proportionalValue, isNull);
    });

    test('创建顺序位置', () {
      final pos = LocalPosition.sequential(index: 2);

      expect(pos.x, 2.0);
      expect(pos.y, 0.0);
      expect(pos.type, PositionType.sequential);
      expect(pos.proportionalValue, isNull);
    });

    test('创建填充位置', () {
      const pos = LocalPosition.fill();

      expect(pos.x, 0.0);
      expect(pos.y, 0.0);
      expect(pos.type, PositionType.fill);
      expect(pos.proportionalValue, isNull);
    });

    test('将绝对位置转换为偏移量', () {
      const pos = LocalPosition.absolute(100, 200);
      const parentSize = Size(800, 600);

      final offset = pos.toAbsolute(parentSize);

      expect(offset.dx, 100.0);
      expect(offset.dy, 200.0);
    });

    test('将比例位置转换为偏移量', () {
      const pos = LocalPosition.proportional(0.5, 0.75);
      const parentSize = Size(800, 600);

      final offset = pos.toAbsolute(parentSize);

      expect(offset.dx, 400.0); // 800的50%
      expect(offset.dy, 450.0); // 600的75%
    });

    test('顺序位置转偏移量时抛出异常', () {
      final pos = LocalPosition.sequential(index: 2);
      const parentSize = Size(800, 600);

      expect(
        () => pos.toAbsolute(parentSize),
        throwsA(isA<StateError>()),
      );
    });

    test('填充位置返回零偏移量', () {
      const pos = LocalPosition.fill();
      const parentSize = Size(800, 600);

      final offset = pos.toAbsolute(parentSize);

      expect(offset.dx, 0.0);
      expect(offset.dy, 0.0);
    });

    test('相等性判断正常工作', () {
      const pos1 = LocalPosition.absolute(10, 20);
      const pos2 = LocalPosition.absolute(10, 20);
      const pos3 = LocalPosition.absolute(10, 21);

      expect(pos1, equals(pos2));
      expect(pos1, isNot(equals(pos3)));
      expect(pos1 == pos1, isTrue);
    });

    test('hashCode与相等性一致', () {
      const pos1 = LocalPosition.absolute(10, 20);
      const pos2 = LocalPosition.absolute(10, 20);

      expect(pos1.hashCode, equals(pos2.hashCode));
    });
  });

  group('GlobalPosition', () {
    test('创建全局位置', () {
      const pos = GlobalPosition(150, 300);

      expect(pos.x, 150.0);
      expect(pos.y, 300.0);
    });

    test('转换为偏移量', () {
      const pos = GlobalPosition(150, 300);

      final offset = pos.toOffset();

      expect(offset.dx, 150.0);
      expect(offset.dy, 300.0);
    });

    test('相等性判断正常工作', () {
      const pos1 = GlobalPosition(150, 300);
      const pos2 = GlobalPosition(150, 300);
      const pos3 = GlobalPosition(150, 301);

      expect(pos1, equals(pos2));
      expect(pos1, isNot(equals(pos3)));
    });

    test('hashCode与相等性一致', () {
      const pos1 = GlobalPosition(150, 300);
      const pos2 = GlobalPosition(150, 300);

      expect(pos1.hashCode, equals(pos2.hashCode));
    });
  });

  group('CoordinateSystem', () {
    late UIHookNode rootHook;
    late UIHookNode childHook;
    late UIHookNode grandchildHook;

    setUp(() {
      // 创建一个简单的Hook树
      // 根节点 (0, 0) 尺寸: 800x600
      //   子节点 (100, 50) 尺寸: 200x300
      //     孙节点 (10, 20) 尺寸: 100x100
      rootHook = UIHookNode(
        id: 'root',
        hookPointId: 'root',
        localPosition: const LocalPosition.absolute(0, 0),
        size: const Size(800, 600),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
      );

      childHook = UIHookNode(
        id: 'child',
        hookPointId: 'child',
        localPosition: const LocalPosition.absolute(100, 50),
        size: const Size(200, 300),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: rootHook,
      );

      grandchildHook = UIHookNode(
        id: 'grandchild',
        hookPointId: 'grandchild',
        localPosition: const LocalPosition.absolute(10, 20),
        size: const Size(100, 100),
        layoutConfig: const LayoutConfig(strategy: LayoutStrategy.absolute),
        parent: childHook,
      );
    });

    test('localToGlobal转换根Hook中的位置', () {
      const localPos = LocalPosition.absolute(50, 100);

      final globalPos = CoordinateSystem.localToGlobal(rootHook, localPos);

      expect(globalPos.x, 50.0);
      expect(globalPos.y, 100.0);
    });

    test('localToGlobal转换子Hook中的位置', () {
      const localPos = LocalPosition.absolute(30, 40);

      final globalPos = CoordinateSystem.localToGlobal(childHook, localPos);

      // 子节点在(100, 50)，所以局部(30, 40) → 全局(130, 90)
      expect(globalPos.x, 130.0);
      expect(globalPos.y, 90.0);
    });

    test('localToGlobal转换孙Hook中的位置', () {
      const localPos = LocalPosition.absolute(5, 10);

      final globalPos = CoordinateSystem.localToGlobal(grandchildHook, localPos);

      // 根节点(0,0) + 子节点(100, 50) + 孙节点(10, 20) + 局部(5, 10)
      // = (115, 80)
      expect(globalPos.x, 115.0);
      expect(globalPos.y, 80.0);
    });

    test('globalToLocal转换位置到根Hook', () {
      const globalPos = GlobalPosition(50, 100);

      final localPos = CoordinateSystem.globalToLocal(rootHook, globalPos);

      expect(localPos.x, 50.0);
      expect(localPos.y, 100.0);
      expect(localPos.type, PositionType.absolute);
    });

    test('globalToLocal转换位置到子Hook', () {
      const globalPos = GlobalPosition(130, 90);

      final localPos = CoordinateSystem.globalToLocal(childHook, globalPos);

      // 子节点在(100, 50)，所以全局(130, 90) → 局部(30, 40)
      expect(localPos.x, 30.0);
      expect(localPos.y, 40.0);
      expect(localPos.type, PositionType.absolute);
    });

    test('globalToLocal转换位置到孙Hook', () {
      const globalPos = GlobalPosition(115, 80);

      final localPos = CoordinateSystem.globalToLocal(grandchildHook, globalPos);

      // 全局(115, 80) - 子节点(100, 50) - 孙节点(10, 20) = (5, 10)
      expect(localPos.x, 5.0);
      expect(localPos.y, 10.0);
      expect(localPos.type, PositionType.absolute);
    });

    test('convertBetweenHooks转换位置', () {
      const localPosInChild = LocalPosition.absolute(30, 40);

      final localPosInRoot = CoordinateSystem.convertBetweenHooks(
        childHook,
        rootHook,
        localPosInChild,
      );

      // 子节点中的(30, 40) → 全局(130, 90) → 根节点中的(130, 90)
      expect(localPosInRoot.x, 130.0);
      expect(localPosInRoot.y, 90.0);
    });

    test('calculateGlobalBounds返回根节点的正确矩形', () {
      final bounds = CoordinateSystem.calculateGlobalBounds(rootHook);

      expect(bounds.left, 0.0);
      expect(bounds.top, 0.0);
      expect(bounds.width, 800.0);
      expect(bounds.height, 600.0);
    });

    test('calculateGlobalBounds返回子节点的正确矩形', () {
      final bounds = CoordinateSystem.calculateGlobalBounds(childHook);

      expect(bounds.left, 100.0);
      expect(bounds.top, 50.0);
      expect(bounds.width, 200.0);
      expect(bounds.height, 300.0);
    });

    test('calculateGlobalBounds返回孙节点的正确矩形', () {
      final bounds = CoordinateSystem.calculateGlobalBounds(grandchildHook);

      expect(bounds.left, 110.0); // 100 + 10
      expect(bounds.top, 70.0); // 50 + 20
      expect(bounds.width, 100.0);
      expect(bounds.height, 100.0);
    });

    test('containsPoint正常工作', () {
      const pointInside = GlobalPosition(150, 100);
      const pointOutside = GlobalPosition(500, 500);

      expect(CoordinateSystem.containsPoint(childHook, pointInside), isTrue);
      expect(CoordinateSystem.containsPoint(childHook, pointOutside), isFalse);
    });

    test('往返转换保持位置不变', () {
      const originalLocal = LocalPosition.absolute(25, 35);

      final global = CoordinateSystem.localToGlobal(childHook, originalLocal);
      final backToLocal = CoordinateSystem.globalToLocal(childHook, global);

      expect(backToLocal.x, originalLocal.x);
      expect(backToLocal.y, originalLocal.y);
      expect(backToLocal.type, originalLocal.type);
    });
  });
}
