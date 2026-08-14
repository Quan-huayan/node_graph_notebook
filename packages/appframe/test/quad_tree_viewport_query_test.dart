/// QuadTreeViewportQuery 测试：UIStateStore 位置键 → 视口内 nodeId。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_ui_state_store.dart';

void main() {
  group('QuadTreeViewportQuery', () {
    test('返回视口内的画布成员 nodeId', () {
      final store = InMemoryUIStateStore()
        ..set(canvasPositionKey('a'), <String, dynamic>{'x': 10, 'y': 10})
        ..set(canvasPositionKey('b'), <String, dynamic>{'x': 400, 'y': 400})
        ..set(canvasPositionKey('c'), <String, dynamic>{'x': 60, 'y': 60});
      final query = QuadTreeViewportQuery(uiStateStore: store);

      expect(
        query.queryNodes(const ValueRect(x: 0, y: 0, width: 100, height: 100)),
        containsAll(<String>['a', 'c']),
      );
      expect(
        query.queryNodes(const ValueRect(x: 0, y: 0, width: 100, height: 100)),
        isNot(contains('b')),
      );
    });

    test('损坏位置键被跳过（不显示，不崩溃）', () {
      final store = InMemoryUIStateStore()
        ..set(canvasPositionKey('a'), <String, dynamic>{'x': 10, 'y': 10})
        ..set(canvasPositionKey('bad'), 'not-a-map')
        ..set(canvasPositionKey('partial'), <String, dynamic>{'x': 1});
      final query = QuadTreeViewportQuery(uiStateStore: store);

      final ids = query
          .queryNodes(const ValueRect(x: 0, y: 0, width: 1000, height: 1000))
          .toList();
      expect(ids, <String>['a']);
    });

    test('空位置：空结果', () {
      final query = QuadTreeViewportQuery(uiStateStore: InMemoryUIStateStore());
      expect(
        query.queryNodes(const ValueRect(x: 0, y: 0, width: 100, height: 100)),
        isEmpty,
      );
    });

    test('键助手：position 键格式（02 §2.3 带容器上下文）', () {
      expect(canvasPositionKey('noteB'), 'position.graph.noteB');
      expect(
        parseCanvasPosition(<String, dynamic>{'x': 1.5, 'y': 2}),
        const Offset(1.5, 2),
      );
      expect(parseCanvasPosition(<String, dynamic>{'x': 1}), isNull);
    });
  });
}
