/// QuadTree 空间索引（旧资产带走：archive/appframe/graph/quad_tree.dart）。
///
/// 用于高效空间查询（架构 §5.1 视口物化的查询侧，10⁶ 核心资产）：
/// - 获取视口矩形内的节点
/// - 范围查询
///
/// 性能特性：插入平均 O(log n)、查询 O(log n + k)、删除 O(log n)。
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// 四叉树空间索引。
class QuadTree {
  /// 创建四叉树。
  ///
  /// [bounds] 边界范围；[capacity] 节点容量（默认 16）；
  /// [maxDepth] 最大深度（默认 8）；[depth] 当前深度（子节点递归）。
  QuadTree({
    required this.bounds,
    this.capacity = 16,
    this.maxDepth = 8,
    int depth = 0,
  }) : _depth = depth,
       _items = <QuadTreeItem>[];

  /// 边界范围。
  final Rect bounds;

  /// 每节点容量。
  final int capacity;

  /// 最大深度。
  final int maxDepth;

  final int _depth;
  final List<QuadTreeItem> _items;

  QuadTree? _northWest;
  QuadTree? _northEast;
  QuadTree? _southWest;
  QuadTree? _southEast;

  bool get _isDivided =>
      _northWest != null ||
      _northEast != null ||
      _southWest != null ||
      _southEast != null;

  /// 树中项目总数。
  int get size {
    if (!_isDivided) {
      return _items.length;
    }
    var count = _items.length;
    count += _northWest?.size ?? 0;
    count += _northEast?.size ?? 0;
    count += _southWest?.size ?? 0;
    count += _southEast?.size ?? 0;
    return count;
  }

  /// 插入项目。返回 false = 位置在边界外。
  bool insert(QuadTreeItem item) {
    if (!bounds.contains(item.position)) {
      return false;
    }

    if (_items.length < capacity || _depth >= maxDepth) {
      _items.add(item);
      return true;
    }

    if (!_isDivided) {
      _subdivide();
    }

    if (_northWest!.insert(item)) {
      return true;
    }
    if (_northEast!.insert(item)) {
      return true;
    }
    if (_southWest!.insert(item)) {
      return true;
    }
    if (_southEast!.insert(item)) {
      return true;
    }

    _items.add(item);
    return true;
  }

  void _subdivide() {
    final halfWidth = bounds.width / 2;
    final halfHeight = bounds.height / 2;
    final x = bounds.left;
    final y = bounds.top;

    _northWest = QuadTree(
      bounds: Rect.fromLTWH(x, y, halfWidth, halfHeight),
      capacity: capacity,
      maxDepth: maxDepth,
      depth: _depth + 1,
    );
    _northEast = QuadTree(
      bounds: Rect.fromLTWH(x + halfWidth, y, halfWidth, halfHeight),
      capacity: capacity,
      maxDepth: maxDepth,
      depth: _depth + 1,
    );
    _southWest = QuadTree(
      bounds: Rect.fromLTWH(x, y + halfHeight, halfWidth, halfHeight),
      capacity: capacity,
      maxDepth: maxDepth,
      depth: _depth + 1,
    );
    _southEast = QuadTree(
      bounds: Rect.fromLTWH(
        x + halfWidth,
        y + halfHeight,
        halfWidth,
        halfHeight,
      ),
      capacity: capacity,
      maxDepth: maxDepth,
      depth: _depth + 1,
    );

    final itemsToRedistribute = List<QuadTreeItem>.from(_items);
    _items.clear();
    for (final item in itemsToRedistribute) {
      if (_northWest!.insert(item)) {
        continue;
      }
      if (_northEast!.insert(item)) {
        continue;
      }
      if (_southWest!.insert(item)) {
        continue;
      }
      if (_southEast!.insert(item)) {
        continue;
      }
      _items.add(item);
    }
  }

  /// 查询 [range] 矩形内的全部项目。
  List<QuadTreeItem> query(Rect range) {
    final found = <QuadTreeItem>[];
    if (!bounds.overlaps(range)) {
      return found;
    }

    for (final item in _items) {
      if (range.contains(item.position)) {
        found.add(item);
      }
    }

    if (_isDivided) {
      found.addAll(_northWest!.query(range));
      found.addAll(_northEast!.query(range));
      found.addAll(_southWest!.query(range));
      found.addAll(_southEast!.query(range));
    }
    return found;
  }

  /// 查询 [position] 附近 [radius] 半径内的全部项目。
  List<QuadTreeItem> queryNearby(Offset position, double radius) {
    final range = Rect.fromCircle(center: position, radius: radius);
    return query(range);
  }

  /// 移除项目。返回 false = 项目不存在。
  bool remove(QuadTreeItem item) {
    if (!bounds.contains(item.position)) {
      return false;
    }
    if (_items.remove(item)) {
      return true;
    }
    if (_isDivided) {
      if (_northWest!.remove(item)) {
        return true;
      }
      if (_northEast!.remove(item)) {
        return true;
      }
      if (_southWest!.remove(item)) {
        return true;
      }
      if (_southEast!.remove(item)) {
        return true;
      }
    }
    return false;
  }

  /// 更新项目位置。返回 false = 原位置移除失败或新位置在边界外。
  bool update(QuadTreeItem item, Offset newPosition) {
    final oldPosition = item.position;
    if (!remove(item)) {
      return false;
    }
    item.position = newPosition;
    if (insert(item)) {
      return true;
    }
    item.position = oldPosition;
    insert(item);
    return false;
  }

  /// 清空全部项目。
  void clear() {
    _items.clear();
    _northWest = null;
    _northEast = null;
    _southWest = null;
    _southEast = null;
  }

  /// 全部项目（含子节点）。
  List<QuadTreeItem> getAllItems() {
    final allItems = <QuadTreeItem>[];
    allItems.addAll(_items);
    if (_isDivided) {
      allItems.addAll(_northWest!.getAllItems());
      allItems.addAll(_northEast!.getAllItems());
      allItems.addAll(_southWest!.getAllItems());
      allItems.addAll(_southEast!.getAllItems());
    }
    return allItems;
  }

  /// 统计信息（总项目数/总节点数/最大深度/平均每节点项目数）。
  QuadTreeStats get stats {
    final nodeCounts = _countNodes();
    final maxDepthReached = _getMaxDepth();
    final avgItemsPerNode = nodeCounts > 0 ? size / nodeCounts : 0.0;
    return QuadTreeStats(
      totalItems: size,
      totalNodes: nodeCounts,
      maxDepth: maxDepthReached,
      avgItemsPerNode: avgItemsPerNode,
    );
  }

  int _countNodes() {
    if (!_isDivided) {
      return 1;
    }
    var count = 1;
    count += _northWest!._countNodes();
    count += _northEast!._countNodes();
    count += _southWest!._countNodes();
    count += _southEast!._countNodes();
    return count;
  }

  int _getMaxDepth() {
    if (!_isDivided) {
      return _depth;
    }
    return <int>[
      _northWest!._getMaxDepth(),
      _northEast!._getMaxDepth(),
      _southWest!._getMaxDepth(),
      _southEast!._getMaxDepth(),
    ].reduce(math.max);
  }

  @override
  String toString() => 'QuadTree(size: $size, depth: $_depth, bounds: $bounds)';
}

/// 空间索引项目（id 为唯一标识，位置可变）。
class QuadTreeItem {
  /// 创建空间索引项目。
  QuadTreeItem({required this.id, required this.position, this.data});

  /// 唯一标识。
  final String id;

  /// 位置。
  Offset position;

  /// 携带数据（可选）。
  final Object? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is QuadTreeItem && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'QuadTreeItem(id: $id, position: $position)';
}

/// QuadTree 统计信息。
class QuadTreeStats {
  /// 创建统计信息。
  const QuadTreeStats({
    required this.totalItems,
    required this.totalNodes,
    required this.maxDepth,
    required this.avgItemsPerNode,
  });

  /// 总项目数。
  final int totalItems;

  /// 总节点数。
  final int totalNodes;

  /// 最大深度。
  final int maxDepth;

  /// 平均每节点项目数。
  final double avgItemsPerNode;

  @override
  String toString() =>
      'QuadTreeStats('
      'items: $totalItems, '
      'nodes: $totalNodes, '
      'maxDepth: $maxDepth, '
      'avgItems: ${avgItemsPerNode.toStringAsFixed(2)})';
}
