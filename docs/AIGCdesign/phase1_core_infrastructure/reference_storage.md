# 引用存储设计文档

## 1. 概述

### 1.1 职责
引用存储是图结构的核心组件，负责：
- 存储节点间的有向关系（引用）
- 支持前向和反向引用查询
- 高效的图遍历操作
- 传递闭包计算
- 引用完整性维护

### 1.2 目标
- **查询性能**: 单次引用查询延迟 < 1ms
- **遍历性能**: BFS 遍历 1000 个节点 < 10ms
- **空间效率**: 每个引用占用 < 100 bytes
- **完整性**: 引用一致性保证

### 1.3 关键挑战
- **双向查询**: 前向和反向引用的高效存储
- **传递闭包**: 可达性计算的性能优化
- **索引更新**: 引用变更时的索引维护
- **大规模图**: 千万级节点的图遍历

## 2. 架构设计

### 2.1 组件结构

```
ReferenceStorage
    │
    ├── Forward References (前向引用)
    │   ├── Map<SourceId, List<Reference>>
    │   └── 节点 → 出边
    │
    ├── Backward References (反向引用)
    │   ├── Map<TargetId, List<Reference>>
    │   └── 节点 → 入边
    │
    ├── Index (索引)
    │   ├── Type Index (引用类型索引)
    │   └── Property Index (属性索引)
    │
    └── Traversal Cache (遍历缓存)
        ├── Reachability Cache (可达性缓存)
        └── Path Cache (路径缓存)
```

### 2.2 数据结构定义

#### Reference 定义

```dart
/// 节点引用关系
class Reference {
  /// 源节点 ID
  final String sourceId;

  /// 目标节点 ID
  final String targetId;

  /// 引用类型
  final ReferenceType type;

  /// 引用属性
  final Map<String, dynamic> properties;

  /// 创建时间
  final DateTime createdAt;

  Reference({
    required this.sourceId,
    required this.targetId,
    required this.type,
    required this.properties,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 序列化
  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'targetId': targetId,
        'type': type.index,
        'properties': properties,
        'createdAt': createdAt.toIso8601String(),
      };

  /// 反序列化
  static Reference fromJson(Map<String, dynamic> json) => Reference(
        sourceId: json['sourceId'] as String,
        targetId: json['targetId'] as String,
        type: ReferenceType.values[json['type'] as int],
        properties: json['properties'] as Map<String, dynamic>,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  /// 复制
  Reference copyWith({
    String? sourceId,
    String? targetId,
    ReferenceType? type,
    Map<String, dynamic>? properties,
  }) {
    return Reference(
      sourceId: sourceId ?? this.sourceId,
      targetId: targetId ?? this.targetId,
      type: type ?? this.type,
      properties: properties ?? this.properties,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Reference &&
      sourceId == other.sourceId &&
      targetId == other.targetId &&
      type == other.type;

  @override
  int get hashCode => Object.hash(sourceId, targetId, type);
}

/// 引用类型
enum ReferenceType {
  /// 父子关系
  parent,

  /// 包含关系
  contains,

  /// 链接关系
  link,

  /// 依赖关系
  depends,

  /// 引用关系
  reference,

  /// 自定义类型
  custom,
}
```

#### ReferenceStorage 接口

```dart
/// 引用存储接口
abstract class IReferenceStorage {
  /// 添加引用
  Future<void> addReference(Reference reference);

  /// 批量添加引用
  Future<void> addReferences(List<Reference> references);

  /// 删除引用
  Future<void> removeReference(Reference reference);

  /// 批量删除引用
  Future<void> removeReferences(List<Reference> references);

  /// 更新引用
  Future<void> updateReference(Reference oldRef, Reference newRef);

  /// 获取前向引用（从节点出发的引用）
  Future<List<Reference>> getForwardReferences(String nodeId);

  /// 获取反向引用（指向节点的引用）
  Future<List<Reference>> getBackwardReferences(String nodeId);

  /// 获取特定类型的引用
  Future<List<Reference>> getReferencesByType(
    String nodeId,
    ReferenceType type,
    {bool forward = true},
  );

  /// 检查引用是否存在
  Future<bool> hasReference(Reference reference);

  /// 获取两个节点之间的所有引用
  Future<List<Reference>> getReferencesBetween(
    String sourceId,
    String targetId,
  );

  /// 获取节点的所有邻居
  Future<Set<String>> getNeighbors(String nodeId);

  /// BFS 遍历
  Future<List<String>> bfs(
    String startNodeId, {
    int? maxDepth,
    int? maxNodes,
    Set<ReferenceType>? types,
  });

  /// DFS 遍历
  Future<List<String>> dfs(
    String startNodeId, {
    int? maxDepth,
    int? maxNodes,
    Set<ReferenceType>? types,
  });

  /// 计算可达节点（传递闭包）
  Future<Set<String>> getReachableNodes(
    String startNodeId, {
    int? maxDepth,
    Set<ReferenceType>? types,
  });

  /// 检查两个节点是否可达
  Future<bool> isReachable(
    String sourceId,
    String targetId, {
    int? maxDepth,
    Set<ReferenceType>? types,
  });

  /// 获取最短路径
  Future<List<String>?> getShortestPath(
    String sourceId,
    String targetId, {
    Set<ReferenceType>? types,
  });

  /// 清除缓存
  void clearCache();

  /// 获取统计信息
  ReferenceStats get stats;
}

/// 引用统计信息
class ReferenceStats {
  final int totalReferences;
  final int totalNodes;
  final int cacheSize;
  final double averageReferencesPerNode;

  ReferenceStats({
    required this.totalReferences,
    required this.totalNodes,
    required this.cacheSize,
    required this.averageReferencesPerNode,
  });
}
```

## 3. 核心数据结构

### 3.1 前向引用存储

**描述**:
存储从节点出发的引用（出边）。

**数据结构**:

```dart
/// 前向引用存储
class ForwardReferenceStorage {
  /// nodeId -> 引用列表
  final Map<String, List<Reference>> _forwardRefs = {};

  /// 添加引用
  void add(Reference reference) {
    _forwardRefs
        .putIfAbsent(reference.sourceId, () => [])
        .add(reference);
  }

  /// 删除引用
  void remove(Reference reference) {
    final refs = _forwardRefs[reference.sourceId];
    if (refs != null) {
      refs.removeWhere((r) => r == reference);
      if (refs.isEmpty) {
        _forwardRefs.remove(reference.sourceId);
      }
    }
  }

  /// 获取前向引用
  List<Reference> get(String nodeId) {
    return _forwardRefs[nodeId] ?? [];
  }

  /// 获取所有节点 ID
  Set<String> getAllNodeIds() {
    return _forwardRefs.keys.toSet();
  }
}
```

### 3.2 反向引用存储

**描述**:
存储指向节点的引用（入边）。

**数据结构**:

```dart
/// 反向引用存储
class BackwardReferenceStorage {
  /// nodeId -> 引用列表
  final Map<String, List<Reference>> _backwardRefs = {};

  /// 添加引用
  void add(Reference reference) {
    _backwardRefs
        .putIfAbsent(reference.targetId, () => [])
        .add(reference);
  }

  /// 删除引用
  void remove(Reference reference) {
    final refs = _backwardRefs[reference.targetId];
    if (refs != null) {
      refs.removeWhere((r) => r == reference);
      if (refs.isEmpty) {
        _backwardRefs.remove(reference.targetId);
      }
    }
  }

  /// 获取反向引用
  List<Reference> get(String nodeId) {
    return _backwardRefs[nodeId] ?? [];
  }

  /// 获取所有节点 ID
  Set<String> getAllNodeIds() {
    return _backwardRefs.keys.toSet();
  }
}
```

### 3.3 类型索引

**描述**:
按引用类型索引，加速类型过滤查询。

**数据结构**:

```dart
/// 引用类型索引
class ReferenceTypeIndex {
  /// type -> (nodeId -> 引用列表)
  final Map<ReferenceType, Map<String, List<Reference>>> _index = {};

  /// 添加引用
  void add(Reference reference) {
    _index
        .putIfAbsent(reference.type, () => {})
        .putIfAbsent(reference.sourceId, () => [])
        .add(reference);
  }

  /// 删除引用
  void remove(Reference reference) {
    final typeMap = _index[reference.type];
    if (typeMap != null) {
      final refs = typeMap[reference.sourceId];
      if (refs != null) {
        refs.removeWhere((r) => r == reference);
        if (refs.isEmpty) {
          typeMap.remove(reference.sourceId);
        }
      }
    }
  }

  /// 获取特定类型的引用
  List<Reference> get(String nodeId, ReferenceType type) {
    return _index[type]?[nodeId] ?? [];
  }

  /// 获取节点的所有类型
  Set<ReferenceType> getTypesForNode(String nodeId) {
    final types = <ReferenceType>{};
    for (final entry in _index.entries) {
      if (entry.value.containsKey(nodeId)) {
        types.add(entry.key);
      }
    }
    return types;
  }
}
```

## 4. 核心算法

### 4.1 BFS 遍历

**问题描述**:
从起始节点开始，按层遍历所有可达节点。

**算法描述**:
使用队列实现广度优先搜索，支持深度限制和类型过滤。

**伪代码**:
```
function bfs(startNodeId, maxDepth, types):
    visited = Set()
    queue = Queue()
    result = []

    queue.enqueue((startNodeId, 0))

    while not queue.isEmpty():
        (nodeId, depth) = queue.dequeue()

        if nodeId in visited:
            continue

        visited.add(nodeId)
        result.add(nodeId)

        if maxDepth != null and depth >= maxDepth:
            continue

        // 获取邻居
        neighbors = getForwardReferences(nodeId)

        for ref in neighbors:
            if types != null and ref.type not in types:
                continue

            if ref.targetId not in visited:
                queue.enqueue((ref.targetId, depth + 1))

    return result
```

**复杂度分析**:
- 时间复杂度: O(V + E)，V 为节点数，E 为边数
- 空间复杂度: O(V)

**实现**:

```dart
@override
Future<List<String>> bfs(
  String startNodeId, {
  int? maxDepth,
  int? maxNodes,
  Set<ReferenceType>? types,
}) async {
  final visited = <String>{};
  final queue = Queue<_BFSNode>();
  final result = <String>[];

  queue.add(_BFSNode(startNodeId, 0));

  while (queue.isNotEmpty) {
    final current = queue.removeFirst();

    if (visited.contains(current.nodeId)) continue;

    visited.add(current.nodeId);
    result.add(current.nodeId);

    if (maxNodes != null && result.length >= maxNodes) break;

    if (maxDepth != null && current.depth >= maxDepth) continue;

    // 获取前向引用
    final refs = _forwardStorage.get(current.nodeId);

    for (final ref in refs) {
      // 类型过滤
      if (types != null && !types.contains(ref.type)) continue;

      if (!visited.contains(ref.targetId)) {
        queue.add(_BFSNode(ref.targetId, current.depth + 1));
      }
    }
  }

  return result;
}

class _BFSNode {
  final String nodeId;
  final int depth;

  _BFSNode(this.nodeId, this.depth);
}
```

### 4.2 DFS 遍历

**问题描述**:
从起始节点开始，深度优先遍历所有可达节点。

**算法描述**:
使用栈或递归实现深度优先搜索。

**伪代码**:
```
function dfs(startNodeId, maxDepth, types):
    visited = Set()
    stack = Stack()
    result = []

    stack.push((startNodeId, 0))

    while not stack.isEmpty():
        (nodeId, depth) = stack.pop()

        if nodeId in visited:
            continue

        visited.add(nodeId)
        result.add(nodeId)

        if maxDepth != null and depth >= maxDepth:
            continue

        // 获取邻居
        neighbors = getForwardReferences(nodeId)

        for ref in neighbors:
            if types != null and ref.type not in types:
                continue

            if ref.targetId not in visited:
                stack.push((ref.targetId, depth + 1))

    return result
```

**复杂度分析**:
- 时间复杂度: O(V + E)
- 空间复杂度: O(V)

### 4.3 可达性计算（传递闭包）

**问题描述**:
计算从起始节点可达的所有节点。

**算法描述**:
基于 BFS 的传递闭包计算，支持深度限制。

**伪代码**:
```
function getReachableNodes(startNodeId, maxDepth, types):
    visited = Set()
    queue = Queue()

    queue.enqueue(startNodeId)

    while not queue.isEmpty():
        nodeId = queue.dequeue()

        if nodeId in visited:
            continue

        visited.add(nodeId)

        // TODO: 实现深度跟踪

        // 获取邻居
        neighbors = getForwardReferences(nodeId)

        for ref in neighbors:
            if types != null and ref.type not in types:
                continue

            if ref.targetId not in visited:
                queue.enqueue(ref.targetId)

    return visited
```

**复杂度分析**:
- 时间复杂度: O(V + E)
- 空间复杂度: O(V)

**实现**:

```dart
@override
Future<Set<String>> getReachableNodes(
  String startNodeId, {
  int? maxDepth,
  Set<ReferenceType>? types,
}) async {
  final visited = <String>{};
  final queue = Queue<_DFSNode>();

  queue.add(_DFSNode(startNodeId, 0));

  while (queue.isNotEmpty) {
    final current = queue.removeFirst();

    if (visited.contains(current.nodeId)) continue;

    visited.add(current.nodeId);

    if (maxDepth != null && current.depth >= maxDepth) continue;

    // 获取前向引用
    final refs = _forwardStorage.get(current.nodeId);

    for (final ref in refs) {
      if (types != null && !types.contains(ref.type)) continue;

      if (!visited.contains(ref.targetId)) {
        queue.add(_DFSNode(ref.targetId, current.depth + 1));
      }
    }
  }

  return visited;
}

class _DFSNode {
  final String nodeId;
  final int depth;

  _DFSNode(this.nodeId, this.depth);
}
```

### 4.4 最短路径计算

**问题描述**:
找到两个节点之间的最短路径。

**算法描述**:
使用 BFS 找到最短路径，记录父节点用于路径重建。

**伪代码**:
```
function getShortestPath(sourceId, targetId, types):
    if sourceId == targetId:
        return [sourceId]

    visited = Set()
    parent = Map()  // nodeId -> parentNodeId
    queue = Queue()

    queue.enqueue(sourceId)
    visited.add(sourceId)

    while not queue.isEmpty():
        nodeId = queue.dequeue()

        if nodeId == targetId:
            // 重建路径
            path = []
            current = targetId
            while current != null:
                path.add(current)
                current = parent[current]
            return path.reverse()

        // 获取邻居
        neighbors = getForwardReferences(nodeId)

        for ref in neighbors:
            if types != null and ref.type not in types:
                continue

            if ref.targetId not in visited:
                visited.add(ref.targetId)
                parent[ref.targetId] = nodeId
                queue.enqueue(ref.targetId)

    return null  // 不可达
```

**复杂度分析**:
- 时间复杂度: O(V + E)
- 空间复杂度: O(V)

**实现**:

```dart
@override
Future<List<String>?> getShortestPath(
  String sourceId,
  String targetId, {
  Set<ReferenceType>? types,
}) async {
  if (sourceId == targetId) {
    return [sourceId];
  }

  final visited = <String>{};
  final parent = <String, String>{};
  final queue = Queue<String>();

  queue.add(sourceId);
  visited.add(sourceId);

  while (queue.isNotEmpty) {
    final nodeId = queue.removeFirst();

    if (nodeId == targetId) {
      // 重建路径
      final path = <String>[];
      String? current = targetId;
      while (current != null) {
        path.add(current);
        current = parent[current];
      }
      return path.reversed.toList();
    }

    // 获取前向引用
    final refs = _forwardStorage.get(nodeId);

    for (final ref in refs) {
      if (types != null && !types.contains(ref.type)) continue;

      if (!visited.contains(ref.targetId)) {
        visited.add(ref.targetId);
        parent[ref.targetId] = nodeId;
        queue.add(ref.targetId);
      }
    }
  }

  return null; // 不可达
}
```

## 5. 缓存策略

### 5.1 可达性缓存

**描述**:
缓存节点的可达性查询结果。

**数据结构**:

```dart
/// 可达性缓存
class ReachabilityCache {
  /// (source, target, depth?, types?) -> bool
  final Map<String, bool> _cache = {};

  /// 生成缓存键
  String _generateKey(
    String sourceId,
    String targetId, {
    int? maxDepth,
    Set<ReferenceType>? types,
  }) {
    final buffer = StringBuffer();
    buffer.write(sourceId);
    buffer.write('->');
    buffer.write(targetId);
    if (maxDepth != null) {
      buffer.write(':d$maxDepth');
    }
    if (types != null) {
      buffer.write(':t${types.join(',')}');
    }
    return buffer.toString();
  }

  /// 获取缓存
  bool? get(
    String sourceId,
    String targetId, {
    int? maxDepth,
    Set<ReferenceType>? types,
  }) {
    final key = _generateKey(sourceId, targetId,
        maxDepth: maxDepth, types: types);
    return _cache[key];
  }

  /// 设置缓存
  void set(
    String sourceId,
    String targetId,
    bool value, {
    int? maxDepth,
    Set<ReferenceType>? types,
  }) {
    final key = _generateKey(sourceId, targetId,
        maxDepth: maxDepth, types: types);
    _cache[key] = value;
  }

  /// 清除缓存
  void clear() {
    _cache.clear();
  }

  /// 清除特定节点的缓存
  void invalidate(String nodeId) {
    _cache.removeWhere((key, value) =>
        key.startsWith('$nodeId->') || key.endsWith('->$nodeId'));
  }
}
```

### 5.2 邻居缓存

**描述**:
缓存节点的邻居列表。

**数据结构**:

```dart
/// 邻居缓存
class NeighborCache {
  /// nodeId -> 邻居集合
  final Map<String, Set<String>> _cache = {};

  /// 获取缓存
  Set<String>? get(String nodeId) {
    return _cache[nodeId];
  }

  /// 设置缓存
  void set(String nodeId, Set<String> neighbors) {
    _cache[nodeId] = neighbors;
  }

  /// 清除缓存
  void clear() {
    _cache.clear();
  }

  /// 清除特定节点的缓存
  void invalidate(String nodeId) {
    _cache.remove(nodeId);
  }
}
```

## 6. 并发模型

### 6.1 读写锁

**策略**:
- 多个读操作可以并发
- 写操作独占访问

**实现**:

```dart
class ReadWriteLock {
  int _readers = 0;
  bool _writer = false;
  final Queue<Completer<void>> _writeQueue = Queue();

  /// 获取读锁
  Future<void> acquireRead() async {
    while (_writer || _writeQueue.isNotEmpty) {
      await Future.delayed(Duration(microseconds: 100));
    }
    _readers++;
  }

  /// 释放读锁
  void releaseRead() {
    _readers--;
  }

  /// 获取写锁
  Future<void> acquireWrite() async {
    final completer = Completer<void>();
    _writeQueue.add(completer);

    while (_readers > 0 || _writer) {
      await Future.delayed(Duration(microseconds: 100));
    }

    _writeQueue.remove(completer);
    _writer = true;
  }

  /// 释放写锁
  void releaseWrite() {
    _writer = false;
  }
}
```

### 6.2 写操作串行化

**策略**:
- 所有写操作进入队列
- 按顺序执行
- 保证引用一致性

**实现**:

```dart
class ReferenceStorage implements IReferenceStorage {
  final ForwardReferenceStorage _forwardStorage;
  final BackwardReferenceStorage _backwardStorage;
  final ReferenceTypeIndex _typeIndex;
  final ReachabilityCache _reachabilityCache;
  final NeighborCache _neighborCache;

  final WriteQueue _writeQueue = WriteQueue();

  ReferenceStorage()
      : _forwardStorage = ForwardReferenceStorage(),
        _backwardStorage = BackwardReferenceStorage(),
        _typeIndex = ReferenceTypeIndex(),
        _reachabilityCache = ReachabilityCache(),
        _neighborCache = NeighborCache();

  @override
  Future<void> addReference(Reference reference) async {
    await _writeQueue.enqueue(() async {
      // 1. 添加到前向存储
      _forwardStorage.add(reference);

      // 2. 添加到反向存储
      _backwardStorage.add(reference);

      // 3. 更新类型索引
      _typeIndex.add(reference);

      // 4. 使缓存失效
      _invalidateCache(reference);
    });
  }

  void _invalidateCache(Reference reference) {
    // 使可达性缓存失效
    _reachabilityCache.invalidate(reference.sourceId);
    _reachabilityCache.invalidate(reference.targetId);

    // 使邻居缓存失效
    _neighborCache.invalidate(reference.sourceId);
  }

  @override
  Future<List<Reference>> getForwardReferences(String nodeId) async {
    // 读操作无需排队
    return _forwardStorage.get(nodeId);
  }

  // ... 其他方法
}
```

## 7. 错误处理

### 7.1 引用完整性检查

**策略**:
- 添加引用前检查节点存在性
- 删除节点时清理相关引用
- 定期完整性验证

**实现**:

```dart
/// 添加引用前检查
Future<void> addReference(Reference reference) async {
  await _writeQueue.enqueue(() async {
    // 1. 检查节点是否存在
    final sourceExists = await _nodeExists(reference.sourceId);
    final targetExists = await _nodeExists(reference.targetId);

    if (!sourceExists || !targetExists) {
      throw ReferenceIntegrityException(
        '引用的节点不存在: ${reference.sourceId} -> ${reference.targetId}',
      );
    }

    // 2. 检查引用是否已存在
    final exists = await hasReference(reference);
    if (exists) {
      throw ReferenceExistsException(
        '引用已存在: ${reference.sourceId} -> ${reference.targetId}',
      );
    }

    // 3. 添加引用
    _forwardStorage.add(reference);
    _backwardStorage.add(reference);
    _typeIndex.add(reference);
  });
}

/// 检查节点是否存在
Future<bool> _nodeExists(String nodeId) async {
  // TODO: 从存储引擎检查
  return true;
}
```

### 7.2 循环引用检测

**策略**:
- 使用 DFS 检测环
- 添加引用前检测
- 可选：允许或禁止环

**实现**:

```dart
/// 检测是否会形成环
Future<bool> _wouldCreateCycle(Reference reference) async {
  // 检查从 target 到 source 是否可达
  final reachable = await isReachable(
    reference.targetId,
    reference.sourceId,
  );

  return reachable;
}

/// 添加引用（禁止环）
Future<void> addReferenceWithoutCycle(Reference reference) async {
  await _writeQueue.enqueue(() async {
    // 检测环
    final wouldCreateCycle = await _wouldCreateCycle(reference);
    if (wouldCreateCycle) {
      throw CycleDetectedException(
        '禁止创建循环引用: ${reference.sourceId} -> ${reference.targetId}',
      );
    }

    // 添加引用
    _forwardStorage.add(reference);
    _backwardStorage.add(reference);
    _typeIndex.add(reference);
  });
}
```

## 8. 性能考虑

### 8.1 概念性性能指标

| 操作 | 目标延迟 | 说明 |
|------|----------|------|
| 添加引用 | < 5ms | 包含索引更新 |
| 删除引用 | < 5ms | 包含索引清理 |
| 查询引用 | < 1ms | 内存查询 |
| BFS 遍历（1000 节点） | < 10ms | 无缓存 |
| 可达性查询 | < 1ms | 缓存命中 |

### 8.2 优化方向

1. **索引优化**:
   - 多级索引
   - 复合索引
   - 位图索引

2. **缓存优化**:
   - LRU 缓存
   - 分层缓存
   - 预计算

3. **遍历优化**:
   - 双向 BFS
   - A* 算法
   - 并行遍历

### 8.3 瓶颈分析

**潜在瓶颈**:
- 大规模图的遍历
- 深度递归
- 缓存未命中

**解决方案**:
- 迭代代替代归归
- 增量计算
- 异步预加载

## 9. 关键文件清单

```
lib/core/storage/
└── reference/
    ├── reference_storage.dart     # IReferenceStorage 接口
    ├── reference.dart             # Reference 数据类
    ├── forward_storage.dart       # 前向引用存储
    ├── backward_storage.dart      # 反向引用存储
    ├── type_index.dart            # 类型索引
    ├── traversal.dart             # 遍历算法
    ├── reachability_cache.dart    # 可达性缓存
    ├── neighbor_cache.dart        # 邻居缓存
    ├── integrity.dart             # 完整性检查
    └── exceptions.dart            # 异常定义
```

## 10. 参考资料

### 图算法
- Introduction to Algorithms - CLRS
- Graph Algorithms - Sedgewick

### 图数据库
- Neo4j Documentation
- Apache TinkerPop

### 相关论文
- "Graph-based databases" - Angles, Gutierrez
- "A survey of graph database systems" - Ciglan, et al.

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
