# 分区缓存策略设计文档

## 1. 概述

### 1.1 职责
分区缓存策略是分区图数据管理的核心组件，负责：
- 管理分区数据的缓存加载和卸载
- 优化跨分区查询的性能
- 预测和预取热点分区数据
- 平衡内存使用和查询性能
- 支持多级缓存和缓存一致性

### 1.2 目标
- **命中率**: 最大化缓存命中率，减少磁盘访问
- **延迟**: 最小化查询延迟，提供快速响应
- **内存效率**: 在有限内存下最大化缓存价值
- **一致性**: 保证缓存数据的一致性
- **可扩展性**: 支持分布式缓存和扩展

### 1.3 关键挑战
- **预测困难**: 难以预测未来的访问模式
- **一致性维护**: 多缓存层级的数据一致性
- **内存限制**: 有限内存下的最优分配
- **冷启动**: 系统启动时的缓存预热
- **跨分区查询**: 优化涉及多个分区的查询

## 2. 架构设计

### 2.1 组件结构

```
PartitionCacheStrategy
    │
    ├── Cache Levels (缓存层级)
    │   ├── L1 Cache (内存缓存 - 热数据)
    │   ├── L2 Cache (内存缓存 - 温数据)
    │   ├── L3 Cache (磁盘缓存 - 冷数据)
    │   └── Remote Cache (分布式缓存)
    │
    ├── Eviction Policies (淘汰策略)
    │   ├── LRU (最近最少使用)
    │   ├── LFU (最不经常使用)
    │   ├── ARC (自适应替换缓存)
    │   └── LIRS (低互访率替换)
    │
    ├── Prefetch Strategies (预取策略)
    │   ├── Sequential Prefetch (顺序预取)
    │   ├── Probability-Based (概率预测)
    │   ├── Graph-Based (图结构预测)
    │   └── ML-Based (机器学习预测)
    │
    ├── Consistency Manager (一致性管理器)
    │   ├── Write-Through (写穿透)
    │   ├── Write-Back (写回)
    │   ├── Write-Around (写绕过)
    │   └── Invalidation (失效通知)
    │
    └── Cache Monitor (缓存监控器)
        ├── Hit Rate Monitor (命中率监控)
        ├── Access Pattern Analyzer (访问模式分析)
        └── Performance Metrics (性能指标)
```

### 2.2 接口定义

#### CacheEntry 定义

```dart
/// 缓存条目
class CacheEntry<T> {
  /// 分区 ID
  final PartitionId partitionId;

  /// 缓存数据
  final T data;

  /// 访问次数
  int accessCount;

  /// 最后访问时间
  DateTime lastAccessTime;

  /// 创建时间
  DateTime createdAt;

  /// 数据大小（字节）
  final int size;

  /// 是否已修改
  bool isDirty;

  /// 关联的分区节点
  final Set<String> nodeIds;

  CacheEntry({
    required this.partitionId,
    required this.data,
    required this.size,
    required this.nodeIds,
    DateTime? createdAt,
    this.accessCount = 0,
    DateTime? lastAccessTime,
    this.isDirty = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastAccessTime = lastAccessTime ?? createdAt;

  /// 更新访问信息
  void touch() {
    accessCount++;
    lastAccessTime = DateTime.now();
  }

  /// 获取年龄（毫秒）
  int get age => DateTime.now().difference(createdAt).inMilliseconds;

  /// 获取空闲时间（毫秒）
  int get idleTime => DateTime.now().difference(lastAccessTime).inMilliseconds;

  /// 计算访问频率（次/秒）
  double get accessRate {
    final ageInSeconds = age / 1000.0;
    return ageInSeconds > 0 ? accessCount / ageInSeconds : 0.0;
  }
}
```

#### CacheLevel 定义

```dart
/// 缓存层级
enum CacheLevel {
  /// L1 缓存（热数据）
  l1,

  /// L2 缓存（温数据）
  l2,

  /// L3 缓存（冷数据）
  l3,

  /// 远程缓存
  remote,
}

/// 缓存层级配置
class CacheLevelConfig {
  /// 缓存层级
  final CacheLevel level;

  /// 容量（字节）
  final int capacity;

  /// 淘汰策略
  final EvictionPolicy evictionPolicy;

  /// 是否持久化
  final bool isPersistent;

  /// 预取策略
  final PrefetchStrategy prefetchStrategy;

  CacheLevelConfig({
    required this.level,
    required this.capacity,
    this.evictionPolicy = EvictionPolicy.lru,
    this.isPersistent = false,
    this.prefetchStrategy = PrefetchStrategy.sequential,
  });
}
```

#### IPartitionCache 接口

```dart
/// 分区缓存接口
abstract class IPartitionCache<T> {
  /// 获取缓存数据
  Future<T?> get(PartitionId partitionId);

  /// 放入缓存
  Future<void> put(PartitionId partitionId, T data);

  /// 删除缓存
  Future<void> remove(PartitionId partitionId);

  /// 清空缓存
  Future<void> clear();

  /// 检查缓存是否存在
  Future<bool> contains(PartitionId partitionId);

  /// 获取缓存统计信息
  CacheStats getStats();

  /// 获取缓存大小
  int getSize();

  /// 获取缓存容量
  int getCapacity();

  /// 预热缓存
  Future<void> warmup(List<PartitionId> partitionIds);

  /// 预取分区数据
  Future<void> prefetch(List<PartitionId> partitionIds);

  /// 失效缓存
  Future<void> invalidate(List<PartitionId> partitionIds);

  /// 获取缓存命中率
  double getHitRate();

  /// 获取缓存利用率
  double getUtilization();
}
```

#### EvictionPolicy 枚举

```dart
/// 淘汰策略
enum EvictionPolicy {
  /// 最近最少使用
  lru,

  /// 最不经常使用
  lfu,

  /// 先进先出
  fifo,

  /// 自适应替换缓存
  arc,

  /// 低互访率替换
  lirs,

  /// 最不常用且近期最少使用
  lfru,

  /// 随机淘汰
  random,
}
```

#### PrefetchStrategy 枚举

```dart
/// 预取策略
enum PrefetchStrategy {
  /// 顺序预取
  sequential,

  /// 基于概率
  probability,

  /// 基于图结构
  graphBased,

  /// 基于机器学习
  mlBased,

  /// 自适应
  adaptive,

  /// 无预取
  none,
}
```

#### CacheStats 定义

```dart
/// 缓存统计信息
class CacheStats {
  /// 缓存命中次数
  int hitCount;

  /// 缓存未命中次数
  int missCount;

  /// 总请求数
  int get totalCount => hitCount + missCount;

  /// 命中率
  double get hitRate =>
      totalCount > 0 ? hitCount / totalCount : 0.0;

  /// 未命中率
  double get missRate => 1.0 - hitRate;

  /// 平均访问延迟（微秒）
  double avgAccessLatency;

  /// 淘汰次数
  int evictionCount;

  /// 预取命中次数
  int prefetchHitCount;

  /// 预取未命中次数
  int prefetchMissCount;

  /// 当前缓存项数量
  int currentSize;

  /// 当前缓存大小（字节）
  int currentMemoryUsage;

  /// 淘汰的数据大小（字节）
  int evictedMemorySize;

  CacheStats({
    this.hitCount = 0,
    this.missCount = 0,
    this.avgAccessLatency = 0.0,
    this.evictionCount = 0,
    this.prefetchHitCount = 0,
    this.prefetchMissCount = 0,
    this.currentSize = 0,
    this.currentMemoryUsage = 0,
    this.evictedMemorySize = 0,
  });

  /// 重置统计信息
  void reset() {
    hitCount = 0;
    missCount = 0;
    avgAccessLatency = 0.0;
    evictionCount = 0;
    prefetchHitCount = 0;
    prefetchMissCount = 0;
    evictedMemorySize = 0;
  }

  /// 合并统计信息
  CacheStats merge(CacheStats other) {
    return CacheStats(
      hitCount: hitCount + other.hitCount,
      missCount: missCount + other.missCount,
      avgAccessLatency: (avgAccessLatency + other.avgAccessLatency) / 2,
      evictionCount: evictionCount + other.evictionCount,
      prefetchHitCount: prefetchHitCount + other.prefetchHitCount,
      prefetchMissCount: prefetchMissCount + other.prefetchMissCount,
      currentSize: currentSize,
      currentMemoryUsage: currentMemoryUsage,
      evictedMemorySize: evictedMemorySize + other.evictedMemorySize,
    );
  }
}
```

## 3. 核心算法

### 3.1 LRU (Least Recently Used) 淘汰算法

**问题描述**:
当缓存满时，淘汰最近最少使用的条目。

**算法描述**:
使用双向链表和哈希表实现 O(1) 访问和更新。

**伪代码**:
```
class LRUCache:
    capacity: int
    cache: Map<Key, Value>
    lruList: DoublyLinkedList

    function get(key):
        if key in cache:
            // 移到链表头部
            lruList.moveToFront(key)
            return cache[key]
        else:
            return null

    function put(key, value):
        if key in cache:
            // 更新值并移到头部
            cache[key] = value
            lruList.moveToFront(key)
        else:
            // 检查容量
            if cache.size >= capacity:
                // 淘汰最少使用的项
                lruKey = lruList.removeLast()
                cache.remove(lruKey)

            // 添加新项
            cache[key] = value
            lruList.addToFront(key)
```

**复杂度分析**:
- 时间复杂度: O(1) for get/put
- 空间复杂度: O(capacity)

**实现**:

```dart
class LRUPartitionCache<T> implements IPartitionCache<T> {
  final int _capacity;
  final Map<PartitionId, _CacheNode<T>> _cache = {};
  final LinkedList<_CacheNode<T>> _lruList = LinkedList();
  final Map<PartitionId, LinkedListNode<_CacheNode<T>>> _nodeMap = {};

  CacheStats _stats = CacheStats();

  LRUPartitionCache(this._capacity);

  @override
  Future<T?> get(PartitionId partitionId) async {
    final stopwatch = Stopwatch()..start();

    final node = _nodeMap[partitionId];

    if (node != null) {
      // 命中
      _stats.hitCount++;
      node.value.entry.touch();

      // 移到链表头部
      _lruList.moveToFront(node);

      stopwatch.stop();
      _updateLatency(stopwatch.elapsedMicroseconds);

      return node.value.data;
    } else {
      // 未命中
      _stats.missCount++;
      stopwatch.stop();
      _updateLatency(stopwatch.elapsedMicroseconds);

      return null;
    }
  }

  @override
  Future<void> put(PartitionId partitionId, T data) async {
    final existingNode = _nodeMap[partitionId];

    if (existingNode != null) {
      // 更新现有条目
      existingNode.value.data = data;
      existingNode.value.entry.touch();
      _lruList.moveToFront(existingNode);
    } else {
      // 检查容量
      if (_cache.length >= _capacity) {
        await _evict();
      }

      // 创建新条目
      final entry = CacheEntry(
        partitionId: partitionId,
        data: data,
        size: _estimateSize(data),
        nodeIds: await _extractNodeIds(data),
      );

      final node = _CacheNode(entry);
      _cache[partitionId] = entry;
      final linkedListNode = LinkedListNode(node);
      _nodeMap[partitionId] = linkedListNode;
      _lruList.prepend(linkedListNode);

      _stats.currentSize = _cache.length;
      _stats.currentMemoryUsage = _calculateMemoryUsage();
    }
  }

  @override
  Future<void> remove(PartitionId partitionId) async {
    final node = _nodeMap.remove(partitionId);

    if (node != null) {
      _cache.remove(partitionId);
      _lruList.remove(node);
      _stats.currentSize = _cache.length;
      _stats.currentMemoryUsage = _calculateMemoryUsage();
    }
  }

  @override
  Future<void> clear() async {
    _cache.clear();
    _lruList.clear();
    _nodeMap.clear();
    _stats.currentSize = 0;
    _stats.currentMemoryUsage = 0;
  }

  @override
  Future<bool> contains(PartitionId partitionId) async {
    return _cache.containsKey(partitionId);
  }

  @override
  CacheStats getStats() => _stats;

  @override
  int getSize() => _cache.length;

  @override
  int getCapacity() => _capacity;

  @override
  Future<void> warmup(List<PartitionId> partitionIds) async {
    // 预热通常需要从存储加载数据
    // 这里只是预留接口
    for (final id in partitionIds) {
      if (!await contains(id)) {
        // 标记为预取，但不实际加载
        // 实际加载由外部调用者完成
      }
    }
  }

  @override
  Future<void> prefetch(List<PartitionId> partitionIds) async {
    // 预取逻辑
    for (final id in partitionIds) {
      if (!await contains(id)) {
        // 预取数据
        // 实际加载由外部调用者完成
      }
    }
  }

  @override
  Future<void> invalidate(List<PartitionId> partitionIds) async {
    for (final id in partitionIds) {
      await remove(id);
    }
  }

  @override
  double getHitRate() => _stats.hitRate;

  @override
  double getUtilization() {
    return _capacity > 0 ? _cache.length / _capacity : 0.0;
  }

  /// 淘汰最少使用的条目
  Future<void> _evict() async {
    if (_lruList.isEmpty) return;

    final last = _lruList.last;
    final entry = last.value.entry;

    _stats.evictionCount++;
    _stats.evictedMemorySize += entry.size;

    _cache.remove(entry.partitionId);
    _nodeMap.remove(entry.partitionId);
    _lruList.remove(last);
  }

  /// 估算数据大小
  int _estimateSize(T data) {
    // 简单估算，实际应根据具体类型
    if (data is List) {
      return data.length * 100; // 假设每个元素 100 字节
    }
    return 1000; // 默认 1KB
  }

  /// 提取节点 ID
  Future<Set<String>> _extractNodeIds(T data) async {
    // 根据实际数据类型提取
    return {};
  }

  /// 计算内存使用
  int _calculateMemoryUsage() {
    return _cache.values.fold(0, (sum, entry) => sum + entry.size);
  }

  /// 更新访问延迟
  void _updateLatency(int latencyMicros) {
    final current = _stats.avgAccessLatency;
    final count = _stats.totalCount;
    _stats.avgAccessLatency = (current * (count - 1) + latencyMicros) / count;
  }
}

class _CacheNode<T> extends LinkedListEntry<_CacheNode<T>> {
  final CacheEntry<T> entry;

  _CacheNode(this.entry);
}
```

### 3.2 LFU (Least Frequently Used) 淘汰算法

**问题描述**:
淘汰访问频率最低的条目。

**算法描述**:
使用频率计数器和最小堆。

**伪代码**:
```
class LFUCache:
    capacity: int
    cache: Map<Key, (Value, Frequency)>
    minHeap: MinHeap<(Key, Frequency)>

    function get(key):
        if key in cache:
            value, freq = cache[key]
            cache[key] = (value, freq + 1)
            updateHeap(key, freq + 1)
            return value
        else:
            return null

    function put(key, value):
        if key in cache:
            cache[key] = (value, cache[key].frequency + 1)
            updateHeap(key, cache[key].frequency)
        else:
            if cache.size >= capacity:
                // 淘汰频率最低的项
                (lfuKey, _) = minHeap.extractMin()
                cache.remove(lfuKey)

            cache[key] = (value, 1)
            minHeap.insert((key, 1))
```

**复杂度分析**:
- 时间复杂度: O(log n) for get/put
- 空间复杂度: O(capacity)

### 3.3 ARC (Adaptive Replacement Cache) 淘汰算法

**问题描述**:
自适应地在 LRU 和 LFU 之间平衡。

**算法描述**:
维护两个列表（LRU 和 LFU）并动态调整大小。

**伪代码**:
```
class ARCCache:
    capacity: int
    p: int  # LRU 列表的目标大小

    t1: List  # LRU 列表（最近只访问一次）
    t2: List  # LFU 列表（访问多次）
    b1: List  # LRU 幽灵列表
    b2: List  # LFU 幽灵列表

    function get(key):
        if key in t1:
            t1.remove(key)
            t2.add(key)
            return value
        else if key in t2:
            t2.moveToFront(key)
            return value
        else if key in b1:
            # 在 LRU 幽灵列表中，增加 LRU 大小
            p = min(p + max(delta(b2.size, b1.size), 0), capacity)
            replace(key)
            b1.remove(key)
            t2.add(key)
            return value
        else if key in b2:
            # 在 LFU 幽灵列表中，减少 LRU 大小
            p = max(p - max(delta(b1.size, b2.size), 0), 0)
            replace(key)
            b2.remove(key)
            t2.add(key)
            return value
        else:
            return null

    function put(key, value):
        if t1.size + t2.size >= capacity:
            if t1.size + t2.size == 2 * capacity:
                if b1.size > capacity:
                    b1.removeLRU()
                else:
                    b2.removeLRU()

            replace(key)

        t1.add(key)

    function replace(key):
        if t1.isNotEmpty and (
            t1.size > p or
            (key in b2 and t1.size == p)
        ):
            # 从 t1 淘汰到 b1
            k = t1.removeLRU()
            b1.add(k)
        else:
            # 从 t2 淘汰到 b2
            k = t2.removeLRU()
            b2.add(k)
```

**复杂度分析**:
- 时间复杂度: O(1) for get/put
- 空间复杂度: O(2 * capacity)

### 3.4 基于图结构的预取算法

**问题描述**:
基于图结构预测未来的访问模式。

**算法描述**:
分析节点的邻居和历史访问模式。

**伪代码**:
```
function graphBasedPrefetch(graph, currentNode, cache):
    # 1. 获取邻居节点
    neighbors = graph.getNeighbors(currentNode)

    # 2. 计算邻居的访问概率
    probabilities = {}
    for neighbor in neighbors:
        # 基于历史访问频率
        probabilities[neighbor] = calculateAccessProbability(neighbor)

    # 3. 按概率排序
    sortedNeighbors = sort_by_probability(probabilities)

    # 4. 预取 Top-K
    k = calculatePrefetchCount(cache)
    for i in 0..min(k, sortedNeighbors.length):
        neighbor = sortedNeighbors[i]
        if not cache.contains(neighbor):
            cache.prefetch(neighbor)

function calculateAccessProbability(node):
    # 基于历史访问模式
    historicalAccess = getHistoricalAccess(node)

    # 基于节点重要性（度数）
    degree = graph.getDegree(node)

    # 基于最近访问时间
    recency = getRecency(node)

    # 综合计算
    return alpha * historicalAccess +
           beta * degree +
           gamma * recency
```

**实现**:

```dart
class GraphBasedPrefetcher<T> {
  final IPartitionCache<T> _cache;
  final Graph _graph;
  final AccessHistory _history;

  GraphBasedPrefetcher(
    this._cache,
    this._graph,
    this._history,
  );

  /// 预取邻居分区
  Future<void> prefetchNeighbors(PartitionId currentPartition) async {
    // 获取当前分区的节点
    final nodes = await _getPartitionNodes(currentPartition);

    // 收集所有邻居分区
    final neighborPartitions = <PartitionId>{};

    for (final node in nodes) {
      final neighbors = _graph.getNeighbors(node);

      for (final neighbor in neighbors) {
        final neighborPartition = await _getPartitionId(neighbor);
        if (neighborPartition != null) {
          neighborPartitions.add(neighborPartition);
        }
      }
    }

    // 计算预取优先级
    final priorities = await _calculatePriorities(neighborPartitions);

    // 预取高优先级分区
    final toPrefetch = priorities.entries
        .where((e) => !await _cache.contains(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final k = _calculatePrefetchCount();
    for (int i = 0; i < min(k, toPrefetch.length); i++) {
      await _cache.prefetch([toPrefetch[i].key]);
    }
  }

  /// 计算分区预取优先级
  Future<Map<PartitionId, double>> _calculatePriorities(
    Set<PartitionId> partitions,
  ) async {
    final priorities = <PartitionId, double>{};

    for (final partition in partitions) {
      final nodes = await _getPartitionNodes(partition);

      // 历史访问频率
      final historicalAccess = await _history.getAccessFrequency(partition);

      // 节点重要性（平均度数）
      final avgDegree = await _calculateAverageDegree(nodes);

      // 最近访问时间
      final recency = await _history.getRecency(partition);

      // 综合计算
      priorities[partition] = 0.4 * historicalAccess +
                              0.3 * avgDegree +
                              0.3 * recency;
    }

    return priorities;
  }

  /// 计算预取数量
  int _calculatePrefetchCount() {
    final capacity = _cache.getCapacity();
    final size = _cache.getSize();
    final available = capacity - size;

    // 预取可用空间的 20%
    return max(1, (available * 0.2).floor());
  }

  Future<Set<String>> _getPartitionNodes(PartitionId partitionId) async {
    // 从缓存或存储获取节点
    return {};
  }

  Future<PartitionId?> _getPartitionId(String nodeId) async {
    // 查找节点所属分区
    return null;
  }

  Future<double> _calculateAverageDegree(Set<String> nodes) async {
    if (nodes.isEmpty) return 0.0;

    int totalDegree = 0;
    for (final node in nodes) {
      totalDegree += _graph.getDegree(node);
    }

    return totalDegree / nodes.length;
  }
}
```

## 4. 多级缓存

### 4.1 三级缓存架构

**策略**:
- L1: 热数据，小容量，极快访问
- L2: 温数据，中等容量，快速访问
- L3: 冷数据，大容量，普通访问

**实现**:

```dart
class MultiLevelPartitionCache<T> implements IPartitionCache<T> {
  final IPartitionCache<T> _l1Cache;
  final IPartitionCache<T> _l2Cache;
  final IPartitionCache<T> _l3Cache;

  MultiLevelPartitionCache({
    required IPartitionCache<T> l1,
    required IPartitionCache<T> l2,
    required IPartitionCache<T> l3,
  })  : _l1Cache = l1,
        _l2Cache = l2,
        _l3Cache = l3;

  @override
  Future<T?> get(PartitionId partitionId) async {
    // L1 缓存
    var data = await _l1Cache.get(partitionId);
    if (data != null) {
      return data;
    }

    // L2 缓存
    data = await _l2Cache.get(partitionId);
    if (data != null) {
      // 提升到 L1
      await _l1Cache.put(partitionId, data);
      return data;
    }

    // L3 缓存
    data = await _l3Cache.get(partitionId);
    if (data != null) {
      // 提升到 L2
      await _l2Cache.put(partitionId, data);
      return data;
    }

    return null;
  }

  @override
  Future<void> put(PartitionId partitionId, T data) async {
    // 写入所有层级
    await Future.wait([
      _l1Cache.put(partitionId, data),
      _l2Cache.put(partitionId, data),
      _l3Cache.put(partitionId, data),
    ]);
  }

  @override
  Future<void> remove(PartitionId partitionId) async {
    await Future.wait([
      _l1Cache.remove(partitionId),
      _l2Cache.remove(partitionId),
      _l3Cache.remove(partitionId),
    ]);
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _l1Cache.clear(),
      _l2Cache.clear(),
      _l3Cache.clear(),
    ]);
  }

  @override
  Future<bool> contains(PartitionId partitionId) async {
    return await _l1Cache.contains(partitionId) ||
           await _l2Cache.contains(partitionId) ||
           await _l3Cache.contains(partitionId);
  }

  @override
  CacheStats getStats() {
    final l1Stats = _l1Cache.getStats();
    final l2Stats = _l2Cache.getStats();
    final l3Stats = _l3Cache.getStats();

    return CacheStats(
      hitCount: l1Stats.hitCount + l2Stats.hitCount + l3Stats.hitCount,
      missCount: l1Stats.missCount,
      avgAccessLatency: (l1Stats.avgAccessLatency +
                         l2Stats.avgAccessLatency +
                         l3Stats.avgAccessLatency) / 3,
      evictionCount: l1Stats.evictionCount +
                     l2Stats.evictionCount +
                     l3Stats.evictionCount,
      prefetchHitCount: l1Stats.prefetchHitCount +
                       l2Stats.prefetchHitCount +
                       l3Stats.prefetchHitCount,
      prefetchMissCount: l1Stats.prefetchMissCount +
                        l2Stats.prefetchMissCount +
                        l3Stats.prefetchMissCount,
      currentSize: l1Stats.currentSize +
                   l2Stats.currentSize +
                   l3Stats.currentSize,
      currentMemoryUsage: l1Stats.currentMemoryUsage +
                         l2Stats.currentMemoryUsage +
                         l3Stats.currentMemoryUsage,
    );
  }

  @override
  int getSize() {
    return _l1Cache.getSize() + _l2Cache.getSize() + _l3Cache.getSize();
  }

  @override
  int getCapacity() {
    return _l1Cache.getCapacity() + _l2Cache.getCapacity() + _l3Cache.getCapacity();
  }

  // ... 其他方法实现
}
```

### 4.2 缓存一致性策略

#### Write-Through (写穿透)

```dart
class WriteThroughCache<T> implements IPartitionCache<T> {
  final IPartitionCache<T> _cache;
  final PartitionStorage _storage;

  WriteThroughCache(this._cache, this._storage);

  @override
  Future<void> put(PartitionId partitionId, T data) async {
    // 同时写入缓存和存储
    await Future.wait([
      _cache.put(partitionId, data),
      _storage.write(partitionId, data),
    ]);
  }
}
```

#### Write-Back (写回)

```dart
class WriteBackCache<T> implements IPartitionCache<T> {
  final IPartitionCache<T> _cache;
  final PartitionStorage _storage;
  final Set<PartitionId> _dirtyEntries = {};

  WriteBackCache(this._cache, this._storage);

  @override
  Future<void> put(PartitionId partitionId, T data) async {
    // 只写入缓存，标记为脏
    await _cache.put(partitionId, data);
    _dirtyEntries.add(partitionId);
  }

  /// 刷出脏数据
  Future<void> flush() async {
    final futures = <Future<void>>[];

    for (final partitionId in _dirtyEntries) {
      final data = await _cache.get(partitionId);
      if (data != null) {
        futures.add(_storage.write(partitionId, data));
      }
    }

    await Future.wait(futures);
    _dirtyEntries.clear();
  }
}
```

## 5. 性能监控

### 5.1 访问模式分析

```dart
class AccessPatternAnalyzer {
  final Map<PartitionId, List<DateTime>> _accessHistory = {};
  final Map<PartitionId, int> _accessFrequency = {};

  /// 记录访问
  void recordAccess(PartitionId partitionId) {
    final now = DateTime.now();

    _accessHistory.putIfAbsent(partitionId, () => []).add(now);
    _accessFrequency[partitionId] =
        (_accessFrequency[partitionId] ?? 0) + 1;
  }

  /// 获取访问频率
  int getAccessFrequency(PartitionId partitionId) {
    return _accessFrequency[partitionId] ?? 0;
  }

  /// 获取最近访问时间
  DateTime? getLastAccess(PartitionId partitionId) {
    final history = _accessHistory[partitionId];
    if (history == null || history.isEmpty) return null;
    return history.last;
  }

  /// 获取访问模式
  AccessPattern analyzePattern(PartitionId partitionId) {
    final history = _accessHistory[partitionId];
    if (history == null || history.length < 2) {
      return AccessPattern.unknown;
    }

    // 计算访问间隔
    final intervals = <Duration>[];
    for (int i = 1; i < history.length; i++) {
      intervals.add(history[i].difference(history[i - 1]));
    }

    // 分析间隔模式
    final avgInterval = Duration(
      microseconds: intervals
          .map((d) => d.inMicroseconds)
          .reduce((a, b) => a + b) ~/ intervals.length,
    );

    if (avgInterval.inSeconds < 10) {
      return AccessPattern.hot;
    } else if (avgInterval.inMinutes < 5) {
      return AccessPattern.warm;
    } else {
      return AccessPattern.cold;
    }
  }
}

enum AccessPattern {
  hot,
  warm,
  cold,
  unknown,
}
```

## 6. 性能考虑

### 6.1 概念性性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| L1 缓存命中 | > 80% | 热数据命中率 |
| L2 缓存命中 | > 60% | 温数据命中率 |
| 总缓存命中 | > 90% | 综合命中率 |
| 平均访问延迟 | < 100μs | 缓存访问 |
| 预取命中率 | > 70% | 预取效果 |

### 6.2 优化方向

1. **容量规划**:
   - 合理分配各级缓存容量
   - 动态调整缓存大小
   - 监控内存使用

2. **预取优化**:
   - 提高预取准确性
   - 减少预取开销
   - 自适应预取策略

3. **淘汰策略**:
   - 选择合适的淘汰算法
   - 自适应调整策略
   - 考虑访问模式

4. **并发优化**:
   - 减少锁竞争
   - 并行缓存操作
   - 无锁数据结构

### 6.3 瓶颈分析

**潜在瓶颈**:
- 缓存容量不足
- 预取不准确
- 淘汰策略不当
- 并发访问冲突

**解决方案**:
- 增加缓存容量
- 优化预取算法
- 调整淘汰策略
- 使用无锁结构

## 7. 关键文件清单

```
lib/core/cache/
├── partition_cache.dart               # IPartitionCache 接口
├── cache_entry.dart                   # CacheEntry 定义
├── cache_stats.dart                   # CacheStats 定义
├── policies/
│   ├── lru_policy.dart                # LRU 淘汰策略
│   ├── lfu_policy.dart                # LFU 淘汰策略
│   ├── arc_policy.dart                # ARC 淘汰策略
│   └── lirs_policy.dart               # LIRS 淘汰策略
├── multilevel/
│   ├── multi_level_cache.dart         # 多级缓存
│   ├── l1_cache.dart                  # L1 缓存实现
│   ├── l2_cache.dart                  # L2 缓存实现
│   └── l3_cache.dart                  # L3 缓存实现
├── prefetch/
│   ├── prefetch_strategy.dart         # 预取策略接口
│   ├── sequential_prefetch.dart       # 顺序预取
│   ├── graph_prefetch.dart            # 图结构预取
│   └── ml_prefetch.dart               # 机器学习预取
├── consistency/
│   ├── write_through.dart             # 写穿透策略
│   ├── write_back.dart                # 写回策略
│   └── invalidation.dart              # 失效通知
├── monitoring/
│   ├── cache_monitor.dart             # 缓存监控器
│   ├── access_analyzer.dart           # 访问模式分析
│   └── performance_tracker.dart       # 性能追踪
└── utils/
    ├── cache_utils.dart               # 缓存工具函数
    ├── size_estimator.dart            # 大小估算
    └── memory_calculator.dart         # 内存计算
```

## 8. 参考资料

### 缓存算法
- LRU Cache - Least Recently Used
- LFU Cache - Least Frequently Used
- ARC Cache - Adaptive Replacement Cache
- LIRS Cache - Low Inter-reference Recency Set

### 预取策略
- Sequential Prefetching
- Probability-Based Prefetching
- Graph-Based Prefetching

### 缓存一致性
- Write-Through Caching
- Write-Back Caching
- Cache Invalidation Strategies

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
