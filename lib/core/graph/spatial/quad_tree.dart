import 'dart:math' as math;

import 'package:flame/extensions.dart';

/// Rect扩展
extension RectExtension on Rect {
  /// 检查是否包含Vector2点
  bool containsVector2(Vector2 point) => contains(Offset(point.x, point.y));
}

/// QuadTree 空间索引
///
/// 用于高效地进行空间查询，如：
/// - 获取可视区域内的节点
/// - 碰撞检测
/// - 范围查询
///
/// 性能特性：
/// - 插入: 平均 O(log n)，最坏 O(n)
/// - 查询: O(log n + k)，其中k是结果数量
/// - 删除: O(log n)
///
/// 相比遍历所有节点的 O(n)，空间查询显著提升性能
class QuadTree {
  /// 构造函数
  QuadTree({
    required this.bounds,
    this.capacity = 16,
    this.maxDepth = 8,
    int depth = 0,
  })  : _depth = depth,
        _items = [];

  /// 边界矩形
  final Rect bounds;

  /// 每个节点的最大容量
  final int capacity;

  /// 最大深度
  final int maxDepth;

  /// 当前深度
  final int _depth;

  /// 存储的项目
  final List<QuadTreeItem> _items;

  /// 子节点
  QuadTree? _northWest;
  QuadTree? _northEast;
  QuadTree? _southWest;
  QuadTree? _southEast;

  /// 是否已分割
  bool get _isDivided =>
      _northWest != null ||
      _northEast != null ||
      _southWest != null ||
      _southEast != null;

  /// 项目数量
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

  /// 插入项目
  ///
  /// [item] 要插入的项目
  /// 返回是否成功插入
  bool insert(QuadTreeItem item) {
    // 检查项目是否在边界内
    if (!bounds.containsVector2(item.position)) {
      return false;
    }

    // 如果未达到容量且未分割，直接添加
    if (_items.length < capacity || _depth >= maxDepth) {
      _items.add(item);
      return true;
    }

    // 如果需要分割但还未分割
    if (!_isDivided) {
      _subdivide();
    }

    // 尝试插入到子节点
    if (_northWest!.insert(item)) return true;
    if (_northEast!.insert(item)) return true;
    if (_southWest!.insert(item)) return true;
    if (_southEast!.insert(item)) return true;

    // 如果子节点都无法插入，保留在当前节点
    _items.add(item);
    return true;
  }

  /// 分割成4个子节点
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

    // 将现有项目重新分配到子节点
    final itemsToRedistribute = List<QuadTreeItem>.from(_items);
    _items.clear();

    itemsToRedistribute.forEach(insert);
  }

  /// 查询范围内的所有项目
  ///
  /// [range] 查询范围
  /// 返回范围内的项目列表
  List<QuadTreeItem> query(Rect range) {
    final found = <QuadTreeItem>[];

    // 如果查询范围不与当前节点相交，返回空
    if (!bounds.overlaps(range)) {
      return found;
    }

    // 检查当前节点的项目
    for (final item in _items) {
      if (range.containsVector2(item.position)) {
        found.add(item);
      }
    }

    // 如果已分割，递归查询子节点
    if (_isDivided) {
      found.addAll(_northWest!.query(range));
      found.addAll(_northEast!.query(range));
      found.addAll(_southWest!.query(range));
      found.addAll(_southEast!.query(range));
    }

    return found;
  }

  /// 查询附近的节点
  ///
  /// [position] 中心位置
  /// [radius] 查询半径
  /// 返回范围内的项目列表
  List<QuadTreeItem> queryNearby(Vector2 position, double radius) {
    final range = Rect.fromCircle(
      center: Offset(position.x, position.y),
      radius: radius,
    );
    return query(range);
  }

  /// 移除项目
  ///
  /// [item] 要移除的项目
  /// 返回是否成功移除
  bool remove(QuadTreeItem item) {
    // 如果项目不在边界内，无法移除
    if (!bounds.containsVector2(item.position)) {
      return false;
    }

    // 尝试从当前节点移除
    if (_items.remove(item)) {
      return true;
    }

    // 如果已分割，尝试从子节点移除
    if (_isDivided) {
      if (_northWest!.remove(item)) return true;
      if (_northEast!.remove(item)) return true;
      if (_southWest!.remove(item)) return true;
      if (_southEast!.remove(item)) return true;
    }

    return false;
  }

  /// 更新项目位置
  ///
  /// [item] 要更新的项目
  /// [newPosition] 新位置
  /// 返回是否成功更新
  bool update(QuadTreeItem item, Vector2 newPosition) {
    // 移除旧位置
    if (!remove(item)) {
      return false;
    }

    // 更新位置
    item.position = newPosition;

    // 插入新位置
    return insert(item);
  }

  /// 清空所有项目
  void clear() {
    _items.clear();
    _northWest = null;
    _northEast = null;
    _southWest = null;
    _southEast = null;
  }

  /// 获取所有项目
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

  /// 获取统计信息
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

  /// 统计节点数
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

  /// 获取最大深度
  int _getMaxDepth() {
    if (!_isDivided) {
      return _depth;
    }

    final depths = [
      _northWest!._getMaxDepth(),
      _northEast!._getMaxDepth(),
      _southWest!._getMaxDepth(),
      _southEast!._getMaxDepth(),
    ];

    return depths.reduce(math.max);
  }

  @override
  String toString() => 'QuadTree(size: $size, depth: $_depth, bounds: $bounds)';
}

/// QuadTree 项目
///
/// 存储在QuadTree中的项目
class QuadTreeItem {
  /// 构造函数
  QuadTreeItem({
    required this.id,
    required this.position,
    this.data,
  });

  /// 项目ID（通常是节点ID）
  final String id;

  /// 位置
  Vector2 position;

  /// 附加数据（可选）
  final Object? data;

  @override
  String toString() => 'QuadTreeItem(id: $id, position: $position)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuadTreeItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// QuadTree 统计信息
class QuadTreeStats {
  /// 构造函数
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

  /// 平均每节点项目数
  final double avgItemsPerNode;

  @override
  String toString() => 'QuadTreeStats('
        'items: $totalItems, '
        'nodes: $totalNodes, '
        'maxDepth: $maxDepth, '
        'avgItems: ${avgItemsPerNode.toStringAsFixed(2)})';
}
