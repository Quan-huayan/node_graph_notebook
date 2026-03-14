# 空间分区设计文档

## 1. 概述

### 1.1 职责
空间分区系统负责高效管理大量空间对象，通过空间索引加速：
- 可见性查询
- 碰撞检测
- 邻近搜索
- 范围查询

### 1.2 目标
- **查询性能**: O(log n) 复杂度的空间查询
- **内存效率**: 最小化索引内存开销
- **动态更新**: 支持对象的动态添加/删除
- **可扩展性**: 支持大量对象（10000+）

### 1.3 关键挑战
- **分区策略**: 选择合适的空间分区结构
- **平衡维护**: 保持索引树的平衡
- **批量操作**: 高效的批量插入/删除
- **内存管理**: 控制索引内存占用

## 2. 架构设计

### 2.1 组件结构

```
SpatialPartitioningSystem
    │
    ├── SpatialIndex (空间索引接口)
    │   ├── insert() (插入对象)
    │   ├── remove() (移除对象)
    │   ├── query() (查询对象)
    │   └── update() (更新对象)
    │
    ├── Quadtree (四叉树)
    │   ├── root (根节点)
    │   ├── maxObjects (最大对象数)
    │   ├── maxDepth (最大深度)
    │   └── split() (分裂)
    │
    ├── RTree (R 树)
    │   ├── root (根节点)
    │   ├── maxEntries (最大条目数)
    │   ├── minEntries (最小条目数)
    │   └── split() (分裂)
    │
    └── SpatialHash (空间哈希)
        ├── cellSize (单元格大小)
        ├── grid (网格)
        └── hash() (哈希函数)
```

### 2.2 接口定义

#### 空间对象接口

```dart
/// 空间对象接口
abstract class SpatialObject {
  /// 对象 ID
  String get id;

  /// 边界框（世界坐标）
  Rect get bounds;

  /// 位置
  Vector2 get position;

  /// 更新位置
  void updatePosition(Vector2 newPosition);
}

/// 空间对象实现
class BasicSpatialObject implements SpatialObject {
  @override
  final String id;

  @override
  Rect bounds;

  @override
  Vector2 position;

  BasicSpatialObject({
    required this.id,
    required this.position,
    Size size = const Size(100, 100),
  }) : bounds = Rect.fromCenter(
          center: Offset(position.x, position.y),
          width: size.width,
          height: size.height,
        );

  @override
  void updatePosition(Vector2 newPosition) {
    position = newPosition;
    bounds = Rect.fromCenter(
      center: Offset(newPosition.x, newPosition.y),
      width: bounds.width,
      height: bounds.height,
    );
  }
}
```

#### 空间索引接口

```dart
/// 空间索引接口
abstract class SpatialIndex {
  /// 插入对象
  void insert(SpatialObject object);

  /// 移除对象
  void remove(SpatialObject object);

  /// 更新对象位置
  void update(SpatialObject object);

  /// 查询指定区域内的所有对象
  List<SpatialObject> query(Rect bounds);

  /// 查询指定点附近的对象
  List<SpatialObject> queryPoint(Vector2 point);

  /// 查询与指定对象相交的对象
  List<SpatialObject> queryIntersection(SpatialObject object);

  /// 清空索引
  void clear();

  /// 获取索引中的对象数量
  int get size;

  /// 检查索引是否为空
  bool get isEmpty;
}
```

### 2.3 四叉树实现

```dart
/// 四叉树节点
class QuadTreeNode {
  /// 边界
  Rect bounds;

  /// 对象列表
  final List<SpatialObject> objects = [];

  /// 子节点（左上、右上、左下、右下）
  List<QuadTreeNode>? children;

  /// 深度
  final int depth;

  /// 最大对象数
  final int maxObjects;

  /// 最大深度
  final int maxDepth;

  QuadTreeNode({
    required this.bounds,
    this.depth = 0,
    this.maxObjects = 10,
    this.maxDepth = 10,
  });

  /// 是否是叶子节点
  bool get isLeaf => children == null;

  /// 插入对象
  bool insert(SpatialObject object) {
    // 检查对象是否在节点边界内
    if (!bounds.contains(Offset(object.position.x, object.position.y))) {
      return false;
    }

    // 如果是叶子节点且未超过容量
    if (isLeaf && objects.length < maxObjects) {
      objects.add(object);
      return true;
    }

    // 如果是叶子节点但已超过容量，分裂
    if (isLeaf) {
      split();
    }

    // 插入到子节点
    for (final child in children!) {
      if (child.insert(object)) {
        return true;
      }
    }

    // 如果无法插入到子节点，添加到当前节点
    objects.add(object);
    return true;
  }

  /// 移除对象
  bool remove(SpatialObject object) {
    // 检查对象是否在节点边界内
    if (!bounds.overlaps(object.bounds)) {
      return false;
    }

    // 在当前节点中查找并移除
    if (objects.remove(object)) {
      return true;
    }

    // 在子节点中递归移除
    if (!isLeaf) {
      for (final child in children!) {
        if (child.remove(object)) {
          return true;
        }
      }
    }

    return false;
  }

  /// 查询指定区域内的对象
  void query(Rect queryBounds, List<SpatialObject> results) {
    // 如果查询区域与节点边界不相交，返回
    if (!bounds.overlaps(queryBounds)) {
      return;
    }

    // 检查当前节点的对象
    for (final object in objects) {
      if (queryBounds.overlaps(object.bounds)) {
        results.add(object);
      }
    }

    // 递归查询子节点
    if (!isLeaf) {
      for (final child in children!) {
        child.query(queryBounds, results);
      }
    }
  }

  /// 分裂节点
  void split() {
    if (depth >= maxDepth) return;

    final halfWidth = bounds.width / 2;
    final halfHeight = bounds.height / 2;
    final left = bounds.left;
    final top = bounds.top;

    // 创建四个子节点
    children = [
      // 左上
      QuadTreeNode(
        bounds: Rect.fromLTWH(left, top, halfWidth, halfHeight),
        depth: depth + 1,
        maxObjects: maxObjects,
        maxDepth: maxDepth,
      ),
      // 右上
      QuadTreeNode(
        bounds: Rect.fromLTWH(left + halfWidth, top, halfWidth, halfHeight),
        depth: depth + 1,
        maxObjects: maxObjects,
        maxDepth: maxDepth,
      ),
      // 左下
      QuadTreeNode(
        bounds: Rect.fromLTWH(left, top + halfHeight, halfWidth, halfHeight),
        depth: depth + 1,
        maxObjects: maxObjects,
        maxDepth: maxDepth,
      ),
      // 右下
      QuadTreeNode(
        bounds: Rect.fromLTWH(
          left + halfWidth,
          top + halfHeight,
          halfWidth,
          halfHeight,
        ),
        depth: depth + 1,
        maxObjects: maxObjects,
        maxDepth: maxDepth,
      ),
    ];

    // 将当前节点的对象重新分配到子节点
    final objectsToRedistribute = List<SpatialObject>.from(objects);
    objects.clear();

    for (final object in objectsToRedistribute) {
      insert(object);
    }
  }

  /// 清空节点
  void clear() {
    objects.clear();
    children = null;
  }
}

/// 四叉树
class Quadtree implements SpatialIndex {
  late QuadTreeNode _root;

  final int maxObjects;
  final int maxDepth;

  Quadtree({
    required Rect bounds,
    this.maxObjects = 10,
    this.maxDepth = 10,
  }) : _root = QuadTreeNode(
          bounds: bounds,
          depth: 0,
          maxObjects: maxObjects,
          maxDepth: maxDepth,
        );

  @override
  void insert(SpatialObject object) {
    _root.insert(object);
  }

  @override
  void remove(SpatialObject object) {
    _root.remove(object);
  }

  @override
  void update(SpatialObject object) {
    remove(object);
    insert(object);
  }

  @override
  List<SpatialObject> query(Rect bounds) {
    final results = <SpatialObject>[];
    _root.query(bounds, results);
    return results;
  }

  @override
  List<SpatialObject> queryPoint(Vector2 point) {
    final pointBounds = Rect.fromCircle(
      center: Offset(point.x, point.y),
      radius: 1.0,
    );
    return query(pointBounds);
  }

  @override
  List<SpatialObject> queryIntersection(SpatialObject object) {
    return query(object.bounds);
  }

  @override
  void clear() {
    _root.clear();
  }

  @override
  int get size {
    return _countObjects(_root);
  }

  @override
  bool get isEmpty => size == 0;

  int _countObjects(QuadTreeNode node) {
    int count = node.objects.length;
    if (node.children != null) {
      for (final child in node.children!) {
        count += _countObjects(child);
      }
    }
    return count;
  }
}
```

### 2.4 R-Tree 实现

```dart
/// R-树节点
class RTreeNode {
  /// 边界
  Rect bounds;

  /// 条目（对象或子节点）
  final List<dynamic> entries = [];

  /// 是否是叶子节点
  bool get isLeaf => entries.isNotEmpty && entries.first is SpatialObject;

  /// 父节点
  RTreeNode? parent;

  RTreeNode({required this.bounds});

  /// 更新边界
  void updateBounds() {
    if (entries.isEmpty) {
      bounds = Rect.zero;
      return;
    }

    double left = double.infinity;
    double top = double.infinity;
    double right = double.negativeInfinity;
    double bottom = double.negativeInfinity;

    for (final entry in entries) {
      Rect entryBounds;
      if (entry is SpatialObject) {
        entryBounds = entry.bounds;
      } else if (entry is RTreeNode) {
        entryBounds = entry.bounds;
      } else {
        continue;
      }

      left = min(left, entryBounds.left);
      top = min(top, entryBounds.top);
      right = max(right, entryBounds.right);
      bottom = max(bottom, entryBounds.bottom);
    }

    bounds = Rect.fromLTRB(left, top, right, bottom);
  }
}

/// R-树
class RTree implements SpatialIndex {
  RTreeNode? _root;

  final int maxEntries;
  final int minEntries;

  RTree({
    this.maxEntries = 10,
    this.minEntries = 4,
  });

  @override
  void insert(SpatialObject object) {
    if (_root == null) {
      _root = RTreeNode(bounds: object.bounds);
      _root!.entries.add(object);
      return;
    }

    // 插入逻辑
    _insert(_root!, object);
  }

  void _insert(RTreeNode node, SpatialObject object) {
    // 如果是叶子节点且未满
    if (node.isLeaf && node.entries.length < maxEntries) {
      node.entries.add(object);
      node.updateBounds();
      return;
    }

    // 如果是叶子节点但已满，分裂
    if (node.isLeaf) {
      _splitNode(node);
      _insert(node, object);
      return;
    }

    // 如果是内部节点，选择最佳子节点
    final bestChild = _chooseBestChild(node, object);
    _insert(bestChild, object);
    node.updateBounds();

    // 检查是否需要分裂
    if (node.entries.length > maxEntries) {
      _splitNode(node);
    }
  }

  /// 选择最佳子节点
  RTreeNode _chooseBestChild(RTreeNode node, SpatialObject object) {
    RTreeNode? bestChild;
    double minAreaIncrease = double.infinity;

    for (final entry in node.entries) {
      if (entry is! RTreeNode) continue;

      final child = entry;
      final oldArea = child.bounds.width * child.bounds.height;
      final newBounds = _mergeBounds(child.bounds, object.bounds);
      final newArea = newBounds.width * newBounds.height;
      final areaIncrease = newArea - oldArea;

      if (areaIncrease < minAreaIncrease) {
        minAreaIncrease = areaIncrease;
        bestChild = child;
      }
    }

    return bestChild!;
  }

  /// 合并边界
  Rect _mergeBounds(Rect a, Rect b) {
    return Rect.fromLTRB(
      min(a.left, b.left),
      min(a.top, b.top),
      max(a.right, b.right),
      max(a.bottom, b.bottom),
    );
  }

  /// 分裂节点
  void _splitNode(RTreeNode node) {
    // 简化的分裂算法：随机分为两组
    final group1 = <dynamic>[];
    final group2 = <dynamic>[];

    for (int i = 0; i < node.entries.length; i++) {
      if (i % 2 == 0) {
        group1.add(node.entries[i]);
      } else {
        group2.add(node.entries[i]);
      }
    }

    // 创建新节点
    final newNode = RTreeNode(bounds: Rect.zero);
    newNode.entries.addAll(group2);
    newNode.updateBounds();

    // 更新原节点
    node.entries.clear();
    node.entries.addAll(group1);
    node.updateBounds();

    // 将新节点添加到父节点
    if (node.parent == null) {
      // 创建新的根节点
      final newRoot = RTreeNode(bounds: Rect.zero);
      newRoot.entries.add(node);
      newRoot.entries.add(newNode);
      node.parent = newRoot;
      newNode.parent = newRoot;
      newRoot.updateBounds();
      _root = newRoot;
    } else {
      newNode.parent = node.parent;
      node.parent!.entries.add(newNode);
      node.parent!.updateBounds();

      // 检查父节点是否需要分裂
      if (node.parent!.entries.length > maxEntries) {
        _splitNode(node.parent!);
      }
    }
  }

  @override
  void remove(SpatialObject object) {
    // 实现删除逻辑
    // TODO: 实现完整的 R-树删除算法
  }

  @override
  void update(SpatialObject object) {
    remove(object);
    insert(object);
  }

  @override
  List<SpatialObject> query(Rect bounds) {
    final results = <SpatialObject>[];
    if (_root != null) {
      _query(_root!, bounds, results);
    }
    return results;
  }

  void _query(RTreeNode node, Rect queryBounds, List<SpatialObject> results) {
    if (!node.bounds.overlaps(queryBounds)) {
      return;
    }

    for (final entry in node.entries) {
      if (entry is SpatialObject) {
        if (queryBounds.overlaps(entry.bounds)) {
          results.add(entry);
        }
      } else if (entry is RTreeNode) {
        _query(entry, queryBounds, results);
      }
    }
  }

  @override
  List<SpatialObject> queryPoint(Vector2 point) {
    final pointBounds = Rect.fromCircle(
      center: Offset(point.x, point.y),
      radius: 1.0,
    );
    return query(pointBounds);
  }

  @override
  List<SpatialObject> queryIntersection(SpatialObject object) {
    return query(object.bounds);
  }

  @override
  void clear() {
    _root = null;
  }

  @override
  int get size {
    if (_root == null) return 0;
    return _countObjects(_root!);
  }

  @override
  bool get isEmpty => size == 0;

  int _countObjects(RTreeNode node) {
    int count = 0;
    for (final entry in node.entries) {
      if (entry is SpatialObject) {
        count++;
      } else if (entry is RTreeNode) {
        count += _countObjects(entry);
      }
    }
    return count;
  }
}
```

### 2.5 空间哈希实现

```dart
/// 空间哈希
class SpatialHash implements SpatialIndex {
  /// 单元格大小
  final double cellSize;

  /// 哈希表
  final Map<String, List<SpatialObject>> _grid = {};

  SpatialHash({this.cellSize = 100.0});

  /// 计算单元格键
  String _getCellKey(Vector2 position) {
    final x = (position.x / cellSize).floor();
    final y = (position.y / cellSize).floor();
    return '$x,$y';
  }

  /// 获取对象覆盖的所有单元格
  List<String> _getCellKeysForObject(SpatialObject object) {
    final keys = <String>[];

    final startX = (object.bounds.left / cellSize).floor();
    final endX = (object.bounds.right / cellSize).floor();
    final startY = (object.bounds.top / cellSize).floor();
    final endY = (object.bounds.bottom / cellSize).floor();

    for (int x = startX; x <= endX; x++) {
      for (int y = startY; y <= endY; y++) {
        keys.add('$x,$y');
      }
    }

    return keys;
  }

  @override
  void insert(SpatialObject object) {
    final keys = _getCellKeysForObject(object);
    for (final key in keys) {
      _grid.putIfAbsent(key, () => []);
      _grid[key]!.add(object);
    }
  }

  @override
  void remove(SpatialObject object) {
    final keys = _getCellKeysForObject(object);
    for (final key in keys) {
      _grid[key]?.remove(object);
      if (_grid[key]!.isEmpty) {
        _grid.remove(key);
      }
    }
  }

  @override
  void update(SpatialObject object) {
    // 空间哈希的更新需要先删除再插入
    // 为了优化，可以跟踪对象的旧位置
    // 这里简化为直接删除再插入
    remove(object);
    insert(object);
  }

  @override
  List<SpatialObject> query(Rect bounds) {
    final results = <SpatialObject>{};
    final keys = <String>[];

    // 获取查询区域覆盖的所有单元格
    final startX = (bounds.left / cellSize).floor();
    final endX = (bounds.right / cellSize).floor();
    final startY = (bounds.top / cellSize).floor();
    final endY = (bounds.bottom / cellSize).floor();

    for (int x = startX; x <= endX; x++) {
      for (int y = startY; y <= endY; y++) {
        final key = '$x,$y';
        final objects = _grid[key];
        if (objects != null) {
          for (final object in objects) {
            if (bounds.overlaps(object.bounds)) {
              results.add(object);
            }
          }
        }
      }
    }

    return results.toList();
  }

  @override
  List<SpatialObject> queryPoint(Vector2 point) {
    final key = _getCellKey(point);
    final objects = _grid[key] ?? [];
    return objects.where((obj) =>
        obj.bounds.contains(Offset(point.x, point.y))).toList();
  }

  @override
  List<SpatialObject> queryIntersection(SpatialObject object) {
    return query(object.bounds);
  }

  @override
  void clear() {
    _grid.clear();
  }

  @override
  int get size {
    int count = 0;
    for (final objects in _grid.values) {
      count += objects.length;
    }
    return count;
  }

  @override
  bool get isEmpty => _grid.isEmpty;
}
```

## 3. 核心算法

### 3.1 空间查询

**问题描述**:
快速查询指定区域内的所有对象。

**算法描述**:
使用空间索引结构，只搜索相关的区域，避免遍历所有对象。

**伪代码**:
```
function query(index, bounds):
    results = []
    queryRecursive(index.root, bounds, results)
    return results

function queryRecursive(node, bounds, results):
    if not node.bounds.intersects(bounds):
        return

    for object in node.objects:
        if bounds.intersects(object.bounds):
            results.add(object)

    if node.isInternal:
        for child in node.children:
            queryRecursive(child, bounds, results)
```

**复杂度分析**:
- 时间复杂度: O(log n + m)，m 为结果数量
- 空间复杂度: O(m)

### 3.2 索引选择策略

```dart
/// 索引类型
enum SpatialIndexType {
  quadtree,
  rtree,
  spatialHash,
}

/// 索引选择器
class SpatialIndexSelector {
  /// 根据场景特征选择最佳索引
  static SpatialIndex select({
    required Rect bounds,
    required int estimatedObjectCount,
    required double averageObjectSize,
    SpatialIndexType type = SpatialIndexType.quadtree,
  }) {
    switch (type) {
      case SpatialIndexType.quadtree:
        return Quadtree(
          bounds: bounds,
          maxObjects: 10,
          maxDepth: 10,
        );

      case SpatialIndexType.rtree:
        return RTree(
          maxEntries: 10,
          minEntries: 4,
        );

      case SpatialIndexType.spatialHash:
        final cellSize = averageObjectSize * 2;
        return SpatialHash(cellSize: cellSize);
    }
  }

  /// 自动选择最佳索引类型
  static SpatialIndexType autoSelect({
    required int estimatedObjectCount,
    required double averageObjectSize,
    required Rect worldBounds,
  }) {
    final worldArea = worldBounds.width * worldBounds.height;
    final density = estimatedObjectCount / worldArea;

    // 高密度场景：使用四叉树
    if (density > 0.001) {
      return SpatialIndexType.quadtree;
    }

    // 低密度场景：使用空间哈希
    if (density < 0.0001) {
      return SpatialIndexType.spatialHash;
    }

    // 默认：R-树
    return SpatialIndexType.rtree;
  }
}
```

## 4. 性能考虑

### 4.1 概念性性能指标

| 指标 | 四叉树 | R-树 | 空间哈希 |
|------|--------|------|----------|
| 插入复杂度 | O(log n) | O(log n) | O(1) |
| 查询复杂度 | O(log n + m) | O(log n + m) | O(k + m) |
| 内存开销 | O(n) | O(n) | O(n) |
| 适用场景 | 均匀分布 | 任意分布 | 固定大小对象 |

### 4.2 优化策略

1. **批量操作**:
   - 批量插入时延迟索引重建
   - 先收集所有对象再统一插入

2. **缓存友好**:
   - 优化数据结构布局
   - 减少内存碎片

3. **自适应调整**:
   - 根据对象分布动态调整参数
   - 自动选择最佳索引结构

## 5. 关键文件清单

```
lib/flame/rendering/spatial/
├── spatial_object.dart            # 空间对象接口
├── spatial_index.dart             # 空间索引接口
├── quadtree/
│   ├── quadtree.dart              # 四叉树实现
│   └── quadtree_node.dart         # 四叉树节点
├── rtree/
│   ├── rtree.dart                 # R-树实现
│   └── rtree_node.dart            # R-树节点
├── spatial_hash/
│   └── spatial_hash.dart          # 空间哈希实现
└── selector.dart                  # 索引选择器
```

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
