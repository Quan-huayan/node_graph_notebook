import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// QuadTree 空间索引
///
/// 用于高效地进行空间查询：
/// - 获取可视区域内的节点
/// - 碰撞检测
/// - 范围查询
///
/// 性能特性：
/// - 插入: 平均 O(log n)，最坏 O(n)
/// - 查询: O(log n + k)，其中k是结果数量
/// - 删除: O(log n)
class QuadTree {
  /// 创建一个 QuadTree 实例
  ///
  /// [bounds] 定义四叉树的边界范围
  /// [capacity] 每个节点最多容纳的项目数量，默认为 16
  /// [maxDepth] 四叉树的最大深度，默认为 8
  /// [depth] 当前节点的深度，默认为 0
  QuadTree({
    required this.bounds,
    this.capacity = 16,
    this.maxDepth = 8,
    int depth = 0,
  })  : _depth = depth,
        _items = [];

  /// 四叉树的边界范围
  final Rect bounds;
  
  /// 每个节点最多容纳的项目数量
  final int capacity;
  
  /// 四叉树的最大深度
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

  /// 获取四叉树中所有项目的数量
  int get size {
    if (!_isDivided) return _items.length;
    var count = _items.length;
    count += _northWest?.size ?? 0;
    count += _northEast?.size ?? 0;
    count += _southWest?.size ?? 0;
    count += _southEast?.size ?? 0;
    return count;
  }

  /// 向四叉树中插入一个项目
  ///
  /// 返回 true 表示插入成功，false 表示插入失败（项目不在边界内）
  bool insert(QuadTreeItem item) {
    if (!bounds.contains(item.position)) return false;

    if (_items.length < capacity || _depth >= maxDepth) {
      _items.add(item);
      return true;
    }

    if (!_isDivided) _subdivide();

    if (_northWest!.insert(item)) return true;
    if (_northEast!.insert(item)) return true;
    if (_southWest!.insert(item)) return true;
    if (_southEast!.insert(item)) return true;

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
      capacity: capacity, maxDepth: maxDepth, depth: _depth + 1,
    );
    _northEast = QuadTree(
      bounds: Rect.fromLTWH(x + halfWidth, y, halfWidth, halfHeight),
      capacity: capacity, maxDepth: maxDepth, depth: _depth + 1,
    );
    _southWest = QuadTree(
      bounds: Rect.fromLTWH(x, y + halfHeight, halfWidth, halfHeight),
      capacity: capacity, maxDepth: maxDepth, depth: _depth + 1,
    );
    _southEast = QuadTree(
      bounds: Rect.fromLTWH(x + halfWidth, y + halfHeight, halfWidth, halfHeight),
      capacity: capacity, maxDepth: maxDepth, depth: _depth + 1,
    );

    final itemsToRedistribute = List<QuadTreeItem>.from(_items);
    _items.clear();
    for (final item in itemsToRedistribute) {
      if (_northWest!.insert(item)) continue;
      if (_northEast!.insert(item)) continue;
      if (_southWest!.insert(item)) continue;
      if (_southEast!.insert(item)) continue;
      _items.add(item);
    }
  }

  /// 查询指定矩形范围内的所有项目
  ///
  /// [range] 查询的矩形范围
  /// 返回该范围内的所有项目列表
  List<QuadTreeItem> query(Rect range) {
    final found = <QuadTreeItem>[];
    if (!bounds.overlaps(range)) return found;

    for (final item in _items) {
      if (range.contains(item.position)) found.add(item);
    }

    if (_isDivided) {
      found.addAll(_northWest!.query(range));
      found.addAll(_northEast!.query(range));
      found.addAll(_southWest!.query(range));
      found.addAll(_southEast!.query(range));
    }
    return found;
  }

  /// 查询指定位置附近指定半径内的所有项目
  ///
  /// [position] 中心位置
  /// [radius] 查询半径
  /// 返回该范围内的所有项目列表
  List<QuadTreeItem> queryNearby(Offset position, double radius) {
    final range = Rect.fromCircle(center: position, radius: radius);
    return query(range);
  }

  /// 从四叉树中移除指定项目
  ///
  /// 返回 true 表示移除成功，false 表示项目不存在
  bool remove(QuadTreeItem item) {
    if (!bounds.contains(item.position)) return false;
    if (_items.remove(item)) return true;
    if (_isDivided) {
      if (_northWest!.remove(item)) return true;
      if (_northEast!.remove(item)) return true;
      if (_southWest!.remove(item)) return true;
      if (_southEast!.remove(item)) return true;
    }
    return false;
  }

  /// 更新项目的位置
  ///
  /// [item] 要更新的项目
  /// [newPosition] 新的位置
  /// 返回 true 表示更新成功，false 表示更新失败
  bool update(QuadTreeItem item, Offset newPosition) {
    final oldPosition = item.position;
    if (!remove(item)) return false;
    item.position = newPosition;
    if (insert(item)) return true;
    item.position = oldPosition;
    insert(item);
    return false;
  }

  /// 清空四叉树中的所有项目
  void clear() {
    _items.clear();
    _northWest = null;
    _northEast = null;
    _southWest = null;
    _southEast = null;
  }

  /// 获取四叉树中的所有项目
  ///
  /// 返回所有项目的列表
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

  /// 获取四叉树的统计信息
  ///
  /// 包括总项目数、总节点数、最大深度和平均每个节点的项目数
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
    if (!_isDivided) return 1;
    var count = 1;
    count += _northWest!._countNodes();
    count += _northEast!._countNodes();
    count += _southWest!._countNodes();
    count += _southEast!._countNodes();
    return count;
  }

  int _getMaxDepth() {
    if (!_isDivided) return _depth;
    return [
      _northWest!._getMaxDepth(),
      _northEast!._getMaxDepth(),
      _southWest!._getMaxDepth(),
      _southEast!._getMaxDepth(),
    ].reduce(math.max);
  }

  @override
  String toString() => 'QuadTree(size: $size, depth: $_depth, bounds: $bounds)';
}

/// QuadTree 项目
class QuadTreeItem {
  /// 创建一个 QuadTreeItem 实例
  ///
  /// [id] 项目的唯一标识符
  /// [position] 项目的位置
  /// [data] 项目携带的数据，可选
  QuadTreeItem({required this.id, required this.position, this.data});

  /// 项目的唯一标识符
  final String id;
  
  /// 项目的位置
  Offset position;
  
  /// 项目携带的数据
  final Object? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is QuadTreeItem && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'QuadTreeItem(id: $id, position: $position)';
}

/// QuadTree 统计信息
class QuadTreeStats {
  /// 创建一个 QuadTreeStats 实例
  ///
  /// [totalItems] 总项目数
  /// [totalNodes] 总节点数
  /// [maxDepth] 最大深度
  /// [avgItemsPerNode] 平均每个节点的项目数
  const QuadTreeStats({
    required this.totalItems,
    required this.totalNodes,
    required this.maxDepth,
    required this.avgItemsPerNode,
  });

  /// 总项目数
  final int totalItems;
  
  /// 总节点数
  final int totalNodes;
  
  /// 最大深度
  final int maxDepth;
  
  /// 平均每个节点的项目数
  final double avgItemsPerNode;

  @override
  String toString() => 'QuadTreeStats('
      'items: $totalItems, '
      'nodes: $totalNodes, '
      'maxDepth: $maxDepth, '
      'avgItems: ${avgItemsPerNode.toStringAsFixed(2)})';
}
