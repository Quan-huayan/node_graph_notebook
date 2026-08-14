/// QuadTreeViewportQuery —— ViewportQuery 的空间索引实现（架构 §5.1 查询侧）。
///
/// 画布成员 = 外观位置（判据②）：从 UIStateStore 的 `position.graph.<nodeId>`
/// 键构建 QuadTree（nodeId → 点），queryNodes(viewport) 返回视口内 nodeId。
/// 10⁶ 背书：查询 O(log n + k)，与全库规模无关；索引 M6 全量重建 O(n)，
/// 10⁶ 增量索引记入优化项（01 拍板记录回填）。
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/painting.dart';

import 'quad_tree.dart';

/// position 键的域前缀（02 §2.3 键方案：`<domain>.<containerId>.<hookId>`）。
const String canvasPositionPrefix = 'position.graph.';

/// 画布位置键（nodeId 唯一身份；单画布 v1，容器上下文 'graph' 已携带）。
String canvasPositionKey(String nodeId) => '$canvasPositionPrefix$nodeId';

/// 解析画布位置值（`{'x': num, 'y': num}`）→ Offset。
///
/// 损坏/缺失坐标 → null（跳过分区索引，节点不显示）。
Offset? parseCanvasPosition(dynamic value) {
  if (value is! Map<String, dynamic>) {
    return null;
  }
  final x = value['x'];
  final y = value['y'];
  if (x is! num || y is! num) {
    return null;
  }
  return Offset(x.toDouble(), y.toDouble());
}

/// 空间索引实现：视口矩形 → 画布成员 nodeId。
class QuadTreeViewportQuery implements ViewportQuery {
  /// 注入外观存储与索引边界。
  ///
  /// [bounds] 索引边界（缺省大固定区：画布世界坐标不限域；
  /// 越界节点不参与索引，10⁶ 项：分块索引）。
  QuadTreeViewportQuery({required this.uiStateStore, Rect? bounds})
    : _bounds = bounds ?? const Rect.fromLTRB(-10000, -10000, 20000, 20000);

  /// 外观存储（成员 = 位置键）。
  final UIStateStore uiStateStore;

  final Rect _bounds;

  /// 视口内 nodeId（含边界）。
  @override
  Iterable<String> queryNodes(ValueRect viewport) {
    final items = _buildIndex().query(
      Rect.fromLTWH(viewport.x, viewport.y, viewport.width, viewport.height),
    );
    return items.map((item) => item.id);
  }

  /// 全量重建索引（M6 数据量小；10⁶：增量维护，优化项）。
  QuadTree _buildIndex() {
    final tree = QuadTree(bounds: _bounds);
    uiStateStore.getByPrefix(canvasPositionPrefix).forEach((key, value) {
      final position = parseCanvasPosition(value);
      if (position == null) {
        return;
      }
      tree.insert(
        QuadTreeItem(
          id: key.substring(canvasPositionPrefix.length),
          position: position,
        ),
      );
    });
    return tree;
  }
}
