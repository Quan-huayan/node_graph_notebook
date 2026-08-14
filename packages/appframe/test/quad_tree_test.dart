/// QuadTree 空间索引测试（10⁶ 核心资产，架构 §5.1 查询侧）。
library;

import 'package:appframe/appframe.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuadTree', () {
    test('插入 + 矩形查询', () {
      final tree = QuadTree(bounds: const Rect.fromLTWH(0, 0, 100, 100));
      tree
        ..insert(QuadTreeItem(id: 'a', position: const Offset(10, 10)))
        ..insert(QuadTreeItem(id: 'b', position: const Offset(90, 90)))
        ..insert(QuadTreeItem(id: 'c', position: const Offset(200, 200))); // 越界
      expect(tree.size, 2);

      final found = tree.query(const Rect.fromLTWH(0, 0, 50, 50));
      expect(found.map((i) => i.id), <String>['a']);
    });

    test('查询边界语义：左闭右开（右/下边界不含）', () {
      final tree = QuadTree(bounds: const Rect.fromLTWH(0, 0, 100, 100));
      tree.insert(QuadTreeItem(id: 'edge', position: const Offset(10, 10)));
      tree.insert(QuadTreeItem(id: 'in', position: const Offset(9.9, 9.9)));
      // 右/下边界不含（Rect.contains 语义）。
      expect(
        tree.query(const Rect.fromLTWH(0, 0, 10, 10)).map((i) => i.id),
        <String>['in'],
      );
    });

    test('移除与更新', () {
      final tree = QuadTree(bounds: const Rect.fromLTWH(0, 0, 100, 100));
      final item = QuadTreeItem(id: 'a', position: const Offset(10, 10));
      tree.insert(item);
      expect(tree.remove(item), isTrue);
      expect(tree.size, 0);

      tree.insert(item);
      expect(tree.update(item, const Offset(80, 80)), isTrue);
      expect(
        tree.query(const Rect.fromLTWH(70, 70, 20, 20)).map((i) => i.id),
        <String>['a'],
      );
    });

    test('容量分裂后查询全量正确（> 1 个节点）', () {
      final tree = QuadTree(
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        capacity: 2,
      );
      for (var i = 0; i < 20; i++) {
        tree.insert(
          QuadTreeItem(id: 'n$i', position: Offset(i * 4.0, i * 4.0)),
        );
      }
      expect(tree.size, 20);
      expect(tree.query(const Rect.fromLTWH(0, 0, 100, 100)).length, 20);
      // 局部查询命中子集（左闭右开：i*4 < 20 → 5 项）。
      expect(tree.query(const Rect.fromLTWH(0, 0, 20, 20)).length, 5);
    });

    test('clear 清空全部', () {
      final tree = QuadTree(bounds: const Rect.fromLTWH(0, 0, 100, 100));
      tree.insert(QuadTreeItem(id: 'a', position: const Offset(10, 10)));
      tree.clear();
      expect(tree.size, 0);
      expect(tree.query(const Rect.fromLTWH(0, 0, 100, 100)), isEmpty);
    });
  });
}
