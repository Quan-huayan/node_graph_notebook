import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/ui_layout/coordinate_system.dart';
import 'package:node_graph_notebook/core/ui_layout/layout_strategy.dart';
import 'package:node_graph_notebook/core/ui_layout/ui_hook_tree.dart';

void main() {
  group('LocalPosition', () {
    test('creates absolute position', () {
      const pos = LocalPosition.absolute(10, 20);

      expect(pos.x, 10.0);
      expect(pos.y, 20.0);
      expect(pos.type, PositionType.absolute);
      expect(pos.proportionalValue, isNull);
    });

    test('creates proportional position', () {
      const pos = LocalPosition.proportional(0.5, 0.75);

      expect(pos.x, 0.5);
      expect(pos.y, 0.75);
      expect(pos.type, PositionType.proportional);
      expect(pos.proportionalValue, isNull);
    });

    test('creates sequential position', () {
      final pos = LocalPosition.sequential(index: 2);

      expect(pos.x, 2.0);
      expect(pos.y, 0.0);
      expect(pos.type, PositionType.sequential);
      expect(pos.proportionalValue, isNull);
    });

    test('creates fill position', () {
      const pos = LocalPosition.fill();

      expect(pos.x, 0.0);
      expect(pos.y, 0.0);
      expect(pos.type, PositionType.fill);
      expect(pos.proportionalValue, isNull);
    });

    test('converts absolute position to offset', () {
      const pos = LocalPosition.absolute(100, 200);
      const parentSize = Size(800, 600);

      final offset = pos.toAbsolute(parentSize);

      expect(offset.dx, 100.0);
      expect(offset.dy, 200.0);
    });

    test('converts proportional position to offset', () {
      const pos = LocalPosition.proportional(0.5, 0.75);
      const parentSize = Size(800, 600);

      final offset = pos.toAbsolute(parentSize);

      expect(offset.dx, 400.0); // 50% of 800
      expect(offset.dy, 450.0); // 75% of 600
    });

    test('throws on sequential position to offset', () {
      final pos = LocalPosition.sequential(index: 2);
      const parentSize = Size(800, 600);

      expect(
        () => pos.toAbsolute(parentSize),
        throwsA(isA<StateError>()),
      );
    });

    test('returns zero offset for fill position', () {
      const pos = LocalPosition.fill();
      const parentSize = Size(800, 600);

      final offset = pos.toAbsolute(parentSize);

      expect(offset.dx, 0.0);
      expect(offset.dy, 0.0);
    });

    test('equality works correctly', () {
      const pos1 = LocalPosition.absolute(10, 20);
      const pos2 = LocalPosition.absolute(10, 20);
      const pos3 = LocalPosition.absolute(10, 21);

      expect(pos1, equals(pos2));
      expect(pos1, isNot(equals(pos3)));
      expect(pos1 == pos1, isTrue);
    });

    test('hashCode is consistent with equality', () {
      const pos1 = LocalPosition.absolute(10, 20);
      const pos2 = LocalPosition.absolute(10, 20);

      expect(pos1.hashCode, equals(pos2.hashCode));
    });
  });

  group('GlobalPosition', () {
    test('creates global position', () {
      const pos = GlobalPosition(150, 300);

      expect(pos.x, 150.0);
      expect(pos.y, 300.0);
    });

    test('converts to offset', () {
      const pos = GlobalPosition(150, 300);

      final offset = pos.toOffset();

      expect(offset.dx, 150.0);
      expect(offset.dy, 300.0);
    });

    test('equality works correctly', () {
      const pos1 = GlobalPosition(150, 300);
      const pos2 = GlobalPosition(150, 300);
      const pos3 = GlobalPosition(150, 301);

      expect(pos1, equals(pos2));
      expect(pos1, isNot(equals(pos3)));
    });

    test('hashCode is consistent with equality', () {
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
      // Create a simple Hook tree
      // Root (0, 0) size: 800x600
      //   Child (100, 50) size: 200x300
      //     Grandchild (10, 20) size: 100x100
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

    test('localToGlobal converts position in root Hook', () {
      const localPos = LocalPosition.absolute(50, 100);

      final globalPos = CoordinateSystem.localToGlobal(rootHook, localPos);

      expect(globalPos.x, 50.0);
      expect(globalPos.y, 100.0);
    });

    test('localToGlobal converts position in child Hook', () {
      const localPos = LocalPosition.absolute(30, 40);

      final globalPos = CoordinateSystem.localToGlobal(childHook, localPos);

      // Child is at (100, 50), so local (30, 40) → global (130, 90)
      expect(globalPos.x, 130.0);
      expect(globalPos.y, 90.0);
    });

    test('localToGlobal converts position in grandchild Hook', () {
      const localPos = LocalPosition.absolute(5, 10);

      final globalPos = CoordinateSystem.localToGlobal(grandchildHook, localPos);

      // Root (0,0) + Child (100, 50) + Grandchild (10, 20) + Local (5, 10)
      // = (115, 80)
      expect(globalPos.x, 115.0);
      expect(globalPos.y, 80.0);
    });

    test('globalToLocal converts position to root Hook', () {
      const globalPos = GlobalPosition(50, 100);

      final localPos = CoordinateSystem.globalToLocal(rootHook, globalPos);

      expect(localPos.x, 50.0);
      expect(localPos.y, 100.0);
      expect(localPos.type, PositionType.absolute);
    });

    test('globalToLocal converts position to child Hook', () {
      const globalPos = GlobalPosition(130, 90);

      final localPos = CoordinateSystem.globalToLocal(childHook, globalPos);

      // Child is at (100, 50), so global (130, 90) → local (30, 40)
      expect(localPos.x, 30.0);
      expect(localPos.y, 40.0);
      expect(localPos.type, PositionType.absolute);
    });

    test('globalToLocal converts position to grandchild Hook', () {
      const globalPos = GlobalPosition(115, 80);

      final localPos = CoordinateSystem.globalToLocal(grandchildHook, globalPos);

      // Global (115, 80) - Child (100, 50) - Grandchild (10, 20) = (5, 10)
      expect(localPos.x, 5.0);
      expect(localPos.y, 10.0);
      expect(localPos.type, PositionType.absolute);
    });

    test('convertBetweenHooks converts positions', () {
      const localPosInChild = LocalPosition.absolute(30, 40);

      final localPosInRoot = CoordinateSystem.convertBetweenHooks(
        childHook,
        rootHook,
        localPosInChild,
      );

      // (30, 40) in child → (130, 90) global → (130, 90) in root
      expect(localPosInRoot.x, 130.0);
      expect(localPosInRoot.y, 90.0);
    });

    test('calculateGlobalBounds returns correct rect for root', () {
      final bounds = CoordinateSystem.calculateGlobalBounds(rootHook);

      expect(bounds.left, 0.0);
      expect(bounds.top, 0.0);
      expect(bounds.width, 800.0);
      expect(bounds.height, 600.0);
    });

    test('calculateGlobalBounds returns correct rect for child', () {
      final bounds = CoordinateSystem.calculateGlobalBounds(childHook);

      expect(bounds.left, 100.0);
      expect(bounds.top, 50.0);
      expect(bounds.width, 200.0);
      expect(bounds.height, 300.0);
    });

    test('calculateGlobalBounds returns correct rect for grandchild', () {
      final bounds = CoordinateSystem.calculateGlobalBounds(grandchildHook);

      expect(bounds.left, 110.0); // 100 + 10
      expect(bounds.top, 70.0); // 50 + 20
      expect(bounds.width, 100.0);
      expect(bounds.height, 100.0);
    });

    test('containsPoint works correctly', () {
      const pointInside = GlobalPosition(150, 100);
      const pointOutside = GlobalPosition(500, 500);

      expect(CoordinateSystem.containsPoint(childHook, pointInside), isTrue);
      expect(CoordinateSystem.containsPoint(childHook, pointOutside), isFalse);
    });

    test('round-trip conversion preserves position', () {
      const originalLocal = LocalPosition.absolute(25, 35);

      final global = CoordinateSystem.localToGlobal(childHook, originalLocal);
      final backToLocal = CoordinateSystem.globalToLocal(childHook, global);

      expect(backToLocal.x, originalLocal.x);
      expect(backToLocal.y, originalLocal.y);
      expect(backToLocal.type, originalLocal.type);
    });
  });
}
