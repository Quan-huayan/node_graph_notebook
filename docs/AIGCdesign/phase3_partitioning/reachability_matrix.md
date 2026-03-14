# 可达性矩阵设计文档

## 1. 概述

### 1.1 职责
可达性矩阵是图遍历和路径查询的核心数据结构，负责：
- 计算图的传递闭包（所有节点对的可达性）
- 高效回答可达性查询（节点 A 是否可达节点 B）
- 支持增量更新（图变化时更新可达性）
- 提供路径长度和最短路径信息
- 优化存储和查询性能

### 1.2 目标
- **查询性能**: O(1) 时间复杂度回答可达性查询
- **更新性能**: 增量更新时间复杂度接近线性
- **空间效率**: 压缩存储大规模稀疏图的可达性矩阵
- **可扩展性**: 支持分布式计算和存储
- **灵活性**: 支持有向图和无向图

### 1.3 关键挑战
- **空间复杂度**: 完整矩阵需要 O(|V|²) 空间
- **计算复杂度**: 传递闭包计算需要 O(|V|³) 时间
- **增量更新**: 图变化时高效更新矩阵
- **内存限制**: 大规模图无法完整加载到内存
- **稀疏性利用**: 充分利用图的稀疏性优化存储

## 2. 架构设计

### 2.1 组件结构

```
ReachabilityMatrix
    │
    ├── Matrix Storage (矩阵存储)
    │   ├── Dense Matrix (稠密矩阵)
    │   ├── Sparse Matrix (稀疏矩阵)
    │   ├── Compressed Bitmap (压缩位图)
    │   └── Hierarchical Matrix (分层矩阵)
    │
    ├── Computation Engine (计算引擎)
    │   ├── Floyd-Warshall (全源最短路径)
    │   ├── Transitive Closure (传递闭包)
    │   ├── BFS/DFS Forest (广度/深度优先搜索森林)
    │   └── Matrix Multiplication (矩阵乘法)
    │
    ├── Incremental Updater (增量更新器)
    │   ├── Edge Insertion (边插入)
    │   ├── Edge Deletion (边删除)
    │   ├── Node Insertion (节点插入)
    │   └── Node Deletion (节点删除)
    │
    ├── Query Engine (查询引擎)
    │   ├── Reachability Query (可达性查询)
    │   ├── Path Query (路径查询)
    │   ├── Distance Query (距离查询)
    │   └── Ancestor/Descendant (祖先/后代查询)
    │
    └── Cache Manager (缓存管理器)
        ├── Hot Data Cache (热点数据缓存)
        ├── Prefetch Strategy (预取策略)
        └── Eviction Policy (淘汰策略)
```

### 2.2 接口定义

#### ReachabilityMatrix 接口

```dart
/// 可达性矩阵接口
abstract class IReachabilityMatrix {
  /// 查询节点 u 是否可达节点 v
  Future<bool> isReachable(String u, String v);

  /// 查询节点 u 到节点 v 的最短距离
  Future<int?> getDistance(String u, String v);

  /// 获取节点 u 到节点 v 的路径
  Future<List<String>?> getPath(String u, String v);

  /// 获取节点的所有可达节点
  Future<Set<String>> getReachableNodes(String node);

  /// 获取可以到达指定节点的所有节点
  Future<Set<String>> getAncestors(String node);

  /// 获取节点的所有后代节点
  Future<Set<String>> getDescendants(String node);

  /// 插入边
  Future<void> insertEdge(String u, String v);

  /// 删除边
  Future<void> deleteEdge(String u, String v);

  /// 插入节点
  Future<void> insertNode(String nodeId);

  /// 删除节点
  Future<void> deleteNode(String nodeId);

  /// 重新计算矩阵
  Future<void> recompute();

  /// 获取矩阵统计信息
  MatrixStats get stats;

  /// 获取内存使用情况
  MemoryUsage get memoryUsage;
}
```

#### MatrixStats 定义

```dart
/// 矩阵统计信息
class MatrixStats {
  /// 节点数量
  final int nodeCount;

  /// 可达节点对数量
  final int reachablePairs;

  /// 总节点对数量
  final int totalPairs;

  /// 密度（可达节点对 / 总节点对）
  final double density;

  /// 平均距离
  final double averageDistance;

  /// 最大距离（图的直径）
  final int diameter;

  /// 强连通分量数量
  final int sccCount;

  MatrixStats({
    required this.nodeCount,
    required this.reachablePairs,
    required this.totalPairs,
    required this.density,
    required this.averageDistance,
    required this.diameter,
    required this.sccCount,
  });
}
```

#### MemoryUsage 定义

```dart
/// 内存使用情况
class MemoryUsage {
  /// 矩阵数据占用（字节）
  final int matrixSize;

  /// 索引占用（字节）
  final int indexSize;

  /// 缓存占用（字节）
  final int cacheSize;

  /// 总占用（字节）
  final int totalSize;

  MemoryUsage({
    required this.matrixSize,
    required this.indexSize,
    required this.cacheSize,
    required this.totalSize,
  });

  /// 格式化显示
  String format() {
    return '''
矩阵数据: ${_formatBytes(matrixSize)}
索引数据: ${_formatBytes(indexSize)}
缓存数据: ${_formatBytes(cacheSize)}
总占用:   ${_formatBytes(totalSize)}
''';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
```

## 3. 核心算法

### 3.1 Floyd-Warshall 算法

**问题描述**:
计算所有节点对之间的最短路径。

**算法描述**:
动态规划方法，逐步考虑中间节点。

**伪代码**:
```
function floydWarshall(graph):
    n = graph.nodeCount
    dist = n x n matrix

    // 初始化
    for i in 0..n-1:
        for j in 0..n-1:
            if i == j:
                dist[i][j] = 0
            else if graph.hasEdge(i, j):
                dist[i][j] = graph.getEdgeWeight(i, j)
            else:
                dist[i][j] = INFINITY

    // 动态规划
    for k in 0..n-1:
        for i in 0..n-1:
            for j in 0..n-1:
                if dist[i][j] > dist[i][k] + dist[k][j]:
                    dist[i][j] = dist[i][k] + dist[k][j]

    return dist
```

**复杂度分析**:
- 时间复杂度: O(|V|³)
- 空间复杂度: O(|V|²)

**优化实现**:

```dart
class FloydWarshallReachability implements IReachabilityMatrix {
  late List<List<int?>> _distanceMatrix;
  late Map<String, int> _nodeToIndex;
  late Map<int, String> _indexToNode;
  final Graph _graph;

  FloydWarshallReachability(this._graph);

  @override
  Future<void> recompute() async {
    final nodes = _graph.nodes.toList();
    final n = nodes.length;

    // 构建索引映射
    _nodeToIndex = {};
    _indexToNode = {};
    for (int i = 0; i < n; i++) {
      _nodeToIndex[nodes[i].id] = i;
      _indexToNode[i] = nodes[i].id;
    }

    // 初始化距离矩阵
    _distanceMatrix = List.generate(
      n,
      (_) => List<int?>.filled(n, null),
    );

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        if (i == j) {
          _distanceMatrix[i][j] = 0;
        } else {
          final edge = _graph.getEdge(nodes[i].id, nodes[j].id);
          if (edge != null) {
            _distanceMatrix[i][j] = 1; // 无权图
          }
        }
      }
    }

    // Floyd-Warshall 算法
    for (int k = 0; k < n; k++) {
      for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
          final distIK = _distanceMatrix[i][k];
          final distKJ = _distanceMatrix[k][j];

          if (distIK != null && distKJ != null) {
            final currentDist = _distanceMatrix[i][j];
            final newDist = distIK + distKJ;

            if (currentDist == null || newDist < currentDist) {
              _distanceMatrix[i][j] = newDist;
            }
          }
        }
      }
    }
  }

  @override
  Future<bool> isReachable(String u, String v) async {
    final i = _nodeToIndex[u];
    final j = _nodeToIndex[v];

    if (i == null || j == null) return false;

    return _distanceMatrix[i][j] != null;
  }

  @override
  Future<int?> getDistance(String u, String v) async {
    final i = _nodeToIndex[u];
    final j = _nodeToIndex[v];

    if (i == null || j == null) return null;

    return _distanceMatrix[i][j];
  }

  @override
  Future<List<String>?> getPath(String u, String v) async {
    final i = _nodeToIndex[u];
    final j = _nodeToIndex[v];

    if (i == null || j == null) return null;
    if (_distanceMatrix[i][j] == null) return null;

    // 使用 BFS 重建路径
    return await _reconstructPath(u, v);
  }

  Future<List<String>> _reconstructPath(String u, String v) async {
    // 使用 BFS 找到最短路径
    final visited = <String>{};
    final parent = <String, String?>{};
    final queue = <String>[u];

    visited.add(u);
    parent[u] = null;

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);

      if (current == v) {
        // 重建路径
        final path = <String>[];
        var node = v;
        while (node != null) {
          path.insert(0, node);
          node = parent[node];
        }
        return path;
      }

      final neighbors = _graph.getNeighbors(current);
      for (final neighbor in neighbors) {
        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          parent[neighbor] = current;
          queue.add(neighbor);
        }
      }
    }

    return [];
  }

  // ... 其他方法实现
}
```

### 3.2 传递闭包算法

**问题描述**:
计算图的传递闭包（所有节点对的可达性）。

**算法描述**:
使用矩阵乘法或 Warshall 算法。

**伪代码**:
```
function transitiveClosure(graph):
    n = graph.nodeCount
    closure = n x n boolean matrix

    // 初始化邻接矩阵
    for i in 0..n-1:
        for j in 0..n-1:
            closure[i][j] = graph.hasEdge(i, j)

    // Warshall 算法
    for k in 0..n-1:
        for i in 0..n-1:
            for j in 0..n-1:
                closure[i][j] = closure[i][j] or (closure[i][k] and closure[k][j])

    return closure
```

**复杂度分析**:
- 时间复杂度: O(|V|³)
- 空间复杂度: O(|V|²)

**位图优化实现**:

```dart
class BitmapTransitiveClosure implements IReachabilityMatrix {
  late List<BitSet> _closure;
  late Map<String, int> _nodeToIndex;
  late Map<int, String> _indexToNode;
  final Graph _graph;

  BitmapTransitiveClosure(this._graph);

  @override
  Future<void> recompute() async {
    final nodes = _graph.nodes.toList();
    final n = nodes.length;

    // 构建索引映射
    _nodeToIndex = {};
    _indexToNode = {};
    for (int i = 0; i < n; i++) {
      _nodeToIndex[nodes[i].id] = i;
      _indexToNode[i] = nodes[i].id;
    }

    // 初始化闭包矩阵
    _closure = List.generate(n, (_) => BitSet(n));

    // 初始化邻接矩阵
    for (final node in nodes) {
      final i = _nodeToIndex[node.id]!;
      final neighbors = _graph.getNeighbors(node.id);

      for (final neighbor in neighbors) {
        final j = _nodeToIndex[neighbor];
        if (j != null) {
          _closure[i].set(j);
        }
      }
    }

    // Warshall 算法（位图优化）
    for (int k = 0; k < n; k++) {
      for (int i = 0; i < n; i++) {
        if (_closure[i].get(k)) {
          // 闭包[i] = 闭包[i] OR 闭包[k]
          _closure[i].or(_closure[k]);
        }
      }
    }
  }

  @override
  Future<bool> isReachable(String u, String v) async {
    final i = _nodeToIndex[u];
    final j = _nodeToIndex[v];

    if (i == null || j == null) return false;

    return _closure[i].get(j);
  }

  @override
  Future<Set<String>> getReachableNodes(String node) async {
    final i = _nodeToIndex[node];
    if (i == null) return {};

    final result = <String>{};
    final bitset = _closure[i];

    for (int j = 0; j < bitset.length; j++) {
      if (bitset.get(j)) {
        final nodeId = _indexToNode[j];
        if (nodeId != null) {
          result.add(nodeId);
        }
      }
    }

    return result;
  }
}

/// 位集合实现
class BitSet {
  final List<int> _words;
  final int length;

  BitSet(this.length)
      : _words = List.filled((length + 63) ~/ 64, 0);

  bool get(int index) {
    final wordIndex = index ~/ 64;
    final bitIndex = index % 64;
    return (_words[wordIndex] & (1 << bitIndex)) != 0;
  }

  void set(int index) {
    final wordIndex = index ~/ 64;
    final bitIndex = index % 64;
    _words[wordIndex] |= (1 << bitIndex);
  }

  void clear(int index) {
    final wordIndex = index ~/ 64;
    final bitIndex = index % 64;
    _words[wordIndex] &= ~(1 << bitIndex);
  }

  void or(BitSet other) {
    for (int i = 0; i < _words.length && i < other._words.length; i++) {
      _words[i] |= other._words[i];
    }
  }

  void and(BitSet other) {
    for (int i = 0; i < _words.length && i < other._words.length; i++) {
      _words[i] &= other._words[i];
    }
  }
}
```

### 3.3 BFS 森林算法

**问题描述**:
如何高效计算多个节点的可达性。

**算法描述**:
从每个节点出发运行 BFS，构建可达性集合。

**伪代码**:
```
function bfsForest(graph):
    reachable = Map<Node, Set<Node>>

    for source in graph.nodes:
        visited = set()
        queue = [source]

        while queue not empty:
            node = queue.dequeue()
            visited.add(node)

            for neighbor in graph.neighbors(node):
                if neighbor not in visited:
                    queue.enqueue(neighbor)

        reachable[source] = visited

    return reachable
```

**复杂度分析**:
- 时间复杂度: O(|V| × (|V| + |E|))
- 空间复杂度: O(|V|²)

**优化实现**:

```dart
class BFSForestReachability implements IReachabilityMatrix {
  late Map<String, Set<String>> _reachableMap;
  final Graph _graph;

  BFSForestReachability(this._graph);

  @override
  Future<void> recompute() async {
    _reachableMap = {};

    for (final node in _graph.nodes) {
      _reachableMap[node.id] = await _bfs(node.id);
    }
  }

  Future<Set<String>> _bfs(String source) async {
    final visited = <String>{};
    final queue = <String>[source];

    visited.add(source);

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final neighbors = _graph.getNeighbors(current);

      for (final neighbor in neighbors) {
        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          queue.add(neighbor);
        }
      }
    }

    return visited;
  }

  @override
  Future<bool> isReachable(String u, String v) async {
    final reachable = _reachableMap[u];
    return reachable?.contains(v) ?? false;
  }

  @override
  Future<Set<String>> getReachableNodes(String node) async {
    return _reachableMap[node] ?? {};
  }
}
```

### 3.4 增量更新算法

**问题描述**:
图变化时如何高效更新可达性矩阵。

**算法描述**:
基于受影响节点的局部更新。

**伪代码**:
```
function incrementalUpdate(matrix, edge):
    u, v = edge.source, edge.target

    // 如果边已存在，无需更新
    if matrix.isReachable(u, v):
        return

    // 更新矩阵
    for source in matrix.getNodes():
        if matrix.isReachable(source, u):
            for target in matrix.getReachableNodes(v):
                matrix.setReachable(source, target)

function deleteEdge(matrix, edge):
    u, v = edge.source, edge.target

    // 检查是否有替代路径
    if hasAlternativePath(matrix, u, v):
        return

    // 需要重新计算受影响的节点对
    affected = findAffectedPairs(matrix, u, v)

    for (source, target) in affected:
        if not hasPath(matrix, source, target):
            matrix.setUnreachable(source, target)
```

**实现**:

```dart
class IncrementalReachabilityUpdater {
  final IReachabilityMatrix _matrix;
  final Graph _graph;

  IncrementalReachabilityUpdater(this._matrix, this._graph);

  /// 插入边
  Future<void> insertEdge(String u, String v) async {
    // 检查边是否已存在
    if (await _matrix.isReachable(u, v)) {
      return;
    }

    // 更新可达性
    final nodes = _graph.nodes.map((n) => n.id).toSet();

    for (final source in nodes) {
      if (await _matrix.isReachable(source, u)) {
        final reachableFromV = await _matrix.getReachableNodes(v);

        for (final target in reachableFromV) {
          await _setReachable(source, target);
        }
      }
    }
  }

  /// 删除边
  Future<void> deleteEdge(String u, String v) async {
    // 检查是否有替代路径
    if (await _hasAlternativePath(u, v)) {
      return;
    }

    // 找到受影响的节点对
    final affected = await _findAffectedPairs(u, v);

    for (final pair in affected) {
      final source = pair.$1;
      final target = pair.$2;

      // 检查是否有其他路径
      if (!await _hasPath(source, target)) {
        await _setUnreachable(source, target);
      }
    }
  }

  /// 检查是否有替代路径
  Future<bool> _hasAlternativePath(String u, String v) async {
    // 使用 BFS 检查（不使用删除的边）
    final visited = <String>{};
    final queue = <String>[u];

    visited.add(u);

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);

      if (current == v) {
        return true;
      }

      final neighbors = _graph.getNeighbors(current);
      for (final neighbor in neighbors) {
        // 跳过直接边 (u, v)
        if (current == u && neighbor == v) {
          continue;
        }

        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          queue.add(neighbor);
        }
      }
    }

    return false;
  }

  /// 找到受影响的节点对
  Future<Set<(String, String)>> _findAffectedPairs(
    String u,
    String v,
  ) async {
    final affected = <(String, String)>{};

    final nodes = _graph.nodes.map((n) => n.id).toSet();

    for (final source in nodes) {
      if (await _matrix.isReachable(source, u)) {
        final reachableFromV = await _matrix.getReachableNodes(v);

        for (final target in reachableFromV) {
          affected.add((source, target));
        }
      }
    }

    return affected;
  }

  /// 检查是否有路径
  Future<bool> _hasPath(String u, String v) async {
    return await _matrix.isReachable(u, v);
  }

  Future<void> _setReachable(String u, String v) async {
    // 具体实现取决于矩阵存储结构
    // ...
  }

  Future<void> _setUnreachable(String u, String v) async {
    // 具体实现取决于矩阵存储结构
    // ...
  }
}
```

## 4. 存储优化

### 4.1 压缩位图

**策略**:
- 使用位图存储布尔值
- 使用 Roaring Bitmap 压缩稀疏位图
- 分块存储以提高缓存局部性

**实现**:

```dart
class CompressedBitmap {
  final List<RoaringBitmap> _bitmaps;
  final int _chunkSize;

  CompressedBitmap({
    int chunkSize = 65536,
  })  : _chunkSize = chunkSize,
        _bitmaps = [];

  void set(int index) {
    final chunkIndex = index ~/ _chunkSize;
    final bitIndex = index % _chunkSize;

    _ensureCapacity(chunkIndex);
    _bitmaps[chunkIndex].set(bitIndex);
  }

  bool get(int index) {
    final chunkIndex = index ~/ _chunkSize;
    final bitIndex = index % _chunkSize;

    if (chunkIndex >= _bitmaps.length) {
      return false;
    }

    return _bitmaps[chunkIndex].get(bitIndex);
  }

  void _ensureCapacity(int index) {
    while (_bitmaps.length <= index) {
      _bitmaps.add(RoaringBitmap());
    }
  }

  /// 获取内存使用
  int get memoryUsage {
    return _bitmaps.fold(0, (sum, bitmap) => sum + bitmap.sizeInBytes);
  }
}
```

### 4.2 分层矩阵

**策略**:
- 按节点度数分层
- 高度节点使用稠密存储
- 低度节点使用稀疏存储

**实现**:

```dart
class HierarchicalMatrix {
  late List<String> _highDegreeNodes;
  late List<String> _lowDegreeNodes;
  late Map<String, int> _nodeToIndex;
  late DenseMatrix _denseMatrix;
  late SparseMatrix _sparseMatrix;

  void build(Graph graph, {int threshold = 100}) {
    // 按度数分类节点
    final highDegree = <String>[];
    final lowDegree = <String>[];

    for (final node in graph.nodes) {
      final degree = graph.getDegree(node.id);

      if (degree > threshold) {
        highDegree.add(node.id);
      } else {
        lowDegree.add(node.id);
      }
    }

    _highDegreeNodes = highDegree;
    _lowDegreeNodes = lowDegree;

    // 构建索引
    _nodeToIndex = {};
    for (int i = 0; i < highDegree.length; i++) {
      _nodeToIndex[highDegree[i]] = i;
    }
    for (int i = 0; i < lowDegree.length; i++) {
      _nodeToIndex[lowDegree[i]] = i;
    }

    // 构建矩阵
    _denseMatrix = DenseMatrix(highDegree.length);
    _sparseMatrix = SparseMatrix(lowDegree.length);
  }

  bool isReachable(String u, String v) {
    final uIndex = _nodeToIndex[u];
    final vIndex = _nodeToIndex[v];

    if (uIndex == null || vIndex == null) {
      return false;
    }

    // 判断节点类型
    final uIsHigh = _highDegreeNodes.contains(u);
    final vIsHigh = _highDegreeNodes.contains(v);

    if (uIsHigh && vIsHigh) {
      // 两个都是高度节点，使用稠密矩阵
      return _denseMatrix.get(uIndex, vIndex);
    } else {
      // 至少一个是低度节点，使用稀疏矩阵
      return _sparseMatrix.get(uIndex, vIndex);
    }
  }
}
```

## 5. 查询优化

### 5.1 热点数据缓存

**策略**:
- 缓存频繁查询的节点对
- 使用 LRU 淘汰策略
- 预取相关查询

**实现**:

```dart
class ReachabilityCache {
  final int _maxSize;
  final Map<(String, String), bool> _cache = {};
  final LinkedList<_CacheEntry> _lruList = LinkedList();
  final Map<(String, String), LinkedListNode<_CacheEntry>> _entryMap = {};

  ReachabilityCache({int maxSize = 10000}) : _maxSize = maxSize;

  bool? get(String u, String v) {
    final key = (u, v);
    final node = _entryMap[key];

    if (node == null) {
      return null;
    }

    // 移到链表头部
    _lruList.moveToFront(node);

    return node.value.value;
  }

  void put(String u, String v, bool reachable) {
    final key = (u, v);

    // 如果已存在，更新
    final existing = _entryMap[key];
    if (existing != null) {
      existing.value.value = reachable;
      _lruList.moveToFront(existing);
      return;
    }

    // 检查容量
    if (_cache.length >= _maxSize) {
      // 淘汰最久未使用的条目
      final last = _lruList.last;
      _lruList.remove(last);
      _entryMap.remove(last.key);
      _cache.remove(last.key);
    }

    // 添加新条目
    final entry = _CacheEntry(key, reachable);
    final node = LinkedListNode(entry);
    _lruList.prepend(node);
    _entryMap[key] = node;
    _cache[key] = reachable;
  }

  void clear() {
    _cache.clear();
    _lruList.clear();
    _entryMap.clear();
  }
}

class _CacheEntry extends LinkedListEntry<_CacheEntry> {
  final (String, String) key;
  bool value;

  _CacheEntry(this.key, this.value);
}
```

### 5.2 预取策略

**策略**:
- 预取邻居节点的可达性
- 基于查询模式预测

**实现**:

```dart
class ReachabilityPrefetcher {
  final IReachabilityMatrix _matrix;
  final ReachabilityCache _cache;
  final Graph _graph;

  ReachabilityPrefetcher(this._matrix, this._cache, this._graph);

  /// 预取节点的邻居可达性
  Future<void> prefetch(String node) async {
    final neighbors = _graph.getNeighbors(node);

    // 并行预取所有邻居对
    final futures = <Future<void>>[];

    for (final neighbor in neighbors) {
      futures.add(_prefetchPair(node, neighbor));
      futures.add(_prefetchPair(neighbor, node));
    }

    await Future.wait(futures);
  }

  Future<void> _prefetchPair(String u, String v) async {
    if (_cache.get(u, v) != null) {
      return; // 已缓存
    }

    final reachable = await _matrix.isReachable(u, v);
    _cache.put(u, v, reachable);
  }
}
```

## 6. 性能考虑

### 6.1 概念性性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 可达性查询 | < 1μs | 缓存命中 |
| 可达性查询 | < 10μs | 位图实现 |
| 增量更新 | < 100ms | 单边插入 |
| 重新计算 | < 10s | 10万节点图 |
| 内存占用 | < 1GB | 10万节点图 |

### 6.2 优化方向

1. **并行计算**:
   - 并行 BFS
   - 并行矩阵乘法
   - 多线程更新

2. **近似算法**:
   - 采样
   - 局部可达性
   - 概率数据结构

3. **存储优化**:
   - 压缩
   - 分块
   - 分层

4. **缓存策略**:
   - 热点缓存
   - 预取
   - 淘汰优化

### 6.3 瓶颈分析

**潜在瓶颈**:
- 矩阵计算的计算复杂度
- 大规模图的内存占用
- 增量更新的传播成本

**解决方案**:
- 使用更高效的算法
- 压缩存储
- 增量更新优化
- 分布式计算

## 7. 关键文件清单

```
lib/core/reachability/
├── reachability_matrix.dart        # IReachabilityMatrix 接口
├── matrix_stats.dart                # MatrixStats 定义
├── algorithms/
│   ├── floyd_warshall.dart          # Floyd-Warshall 算法
│   ├── transitive_closure.dart      # 传递闭包算法
│   ├── bfs_forest.dart              # BFS 森林算法
│   └── matrix_multiplication.dart   # 矩阵乘法算法
├── storage/
│   ├── dense_matrix.dart            # 稠密矩阵存储
│   ├── sparse_matrix.dart           # 稀疏矩阵存储
│   ├── bitmap.dart                  # 位图存储
│   ├── compressed_bitmap.dart       # 压缩位图
│   └── hierarchical_matrix.dart     # 分层矩阵
├── incremental/
│   ├── incremental_updater.dart     # 增量更新器
│   ├── edge_insertion.dart          # 边插入处理
│   ├── edge_deletion.dart           # 边删除处理
│   └── affected_pairs.dart          # 受影响节点对计算
├── query/
│   ├── reachability_query.dart      # 可达性查询
│   ├── path_query.dart              # 路径查询
│   └── distance_query.dart          # 距离查询
└── cache/
    ├── reachability_cache.dart      # 缓存管理器
    ├── prefetch_strategy.dart       # 预取策略
    └── eviction_policy.dart         # 淘汰策略
```

## 8. 参考资料

### 可达性算法
- Floyd-Warshall Algorithm - All-Pairs Shortest Paths
- Warshall Algorithm - Transitive Closure
- BFS/DFS - Graph Traversal

### 存储优化
- Compressed Sparse Row (CSR) Format
- Roaring Bitmaps - Compressed Bitmaps
- Hierarchical Matrices - Memory Efficiency

### 增量更新
- Dynamic Transitive Closure - Incremental Updates
- Reachability Queries - Graph Algorithms

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
