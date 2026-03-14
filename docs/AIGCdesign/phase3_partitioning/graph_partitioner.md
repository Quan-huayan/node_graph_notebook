# 图分区器设计文档

## 1. 概述

### 1.1 职责
图分区器是大规模图数据管理的核心组件，负责：
- 将大型图分割成多个可管理的子图
- 优化分区质量以减少跨分区边数
- 支持动态图结构的增量分区
- 提供多种分区算法适应不同场景
- 平衡各分区的节点和边数量

### 1.2 目标
- **性能**: 分区操作时间复杂度可控，支持大规模图
- **质量**: 最小化跨分区边，最大化分区内部连接
- **均衡性**: 各分区负载均衡，避免热点
- **可扩展性**: 支持增量分区和动态调整
- **灵活性**: 提供多种算法选择，适应不同图特征

### 1.3 关键挑战
- **算法复杂度**: 图分区通常是 NP 难问题
- **内存效率**: 大规模图可能无法完全加载到内存
- **动态性**: 图结构变化时如何高效更新分区
- **多目标优化**: 平衡分区质量、均衡性和性能
- **局部性**: 保持相关节点在同一分区

## 2. 架构设计

### 2.1 组件结构

```
GraphPartitioner
    │
    ├── Partition Algorithms (分区算法)
    │   ├── METIS Algorithm (多层图分区)
    │   ├── Kernighan-Lin Algorithm (二分优化)
    │   ├── Label Propagation (标签传播)
    │   └── Community Detection (社区发现)
    │
    ├── Partition Manager (分区管理器)
    │   ├── Partition Assignment (分区分配)
    │   ├── Partition Mapping (分区映射)
    │   └── Partition Metadata (分区元数据)
    │
    ├── Quality Metrics (质量度量)
    │   ├── Edge Cut (边割)
    │   ├── Balance Ratio (均衡比率)
    │   └── Modularity (模块度)
    │
    └── Incremental Updater (增量更新器)
        ├── Delta Detection (变化检测)
        ├── Local Rebalancing (局部重平衡)
        └── Partition Migration (分区迁移)
```

### 2.2 接口定义

#### Partition 定义

```dart
/// 分区标识符
class PartitionId {
  final int value;
  const PartitionId(this.value);

  @override
  bool operator ==(Object other) =>
      other is PartitionId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// 分区信息
class Partition {
  /// 分区 ID
  final PartitionId id;

  /// 节点集合
  final Set<String> nodeIds;

  /// 内部边数量
  final int internalEdges;

  /// 外部边数量（跨分区边）
  final int externalEdges;

  /// 分区权重（用于负载均衡）
  final double weight;

  Partition({
    required this.id,
    required this.nodeIds,
    this.internalEdges = 0,
    this.externalEdges = 0,
    this.weight = 1.0,
  });

  /// 获取节点数量
  int get nodeCount => nodeIds.length;

  /// 获取总边数
  int get totalEdges => internalEdges + externalEdges;

  /// 获取边割率
  double get edgeCutRatio =>
      totalEdges > 0 ? externalEdges / totalEdges : 0.0;

  /// 复制分区
  Partition copyWith({
    PartitionId? id,
    Set<String>? nodeIds,
    int? internalEdges,
    int? externalEdges,
    double? weight,
  }) {
    return Partition(
      id: id ?? this.id,
      nodeIds: nodeIds ?? this.nodeIds,
      internalEdges: internalEdges ?? this.internalEdges,
      externalEdges: externalEdges ?? this.externalEdges,
      weight: weight ?? this.weight,
    );
  }
}
```

#### PartitionResult 定义

```dart
/// 分区结果
class PartitionResult {
  /// 分区映射：节点 ID -> 分区 ID
  final Map<String, PartitionId> assignment;

  /// 所有分区
  final Map<PartitionId, Partition> partitions;

  /// 分区质量指标
  final PartitionMetrics metrics;

  /// 分区算法信息
  final PartitionAlgorithm algorithm;

  /// 执行时间
  final Duration executionTime;

  PartitionResult({
    required this.assignment,
    required this.partitions,
    required this.metrics,
    required this.algorithm,
    required this.executionTime,
  });

  /// 获取节点所属分区
  PartitionId? getPartition(String nodeId) => assignment[nodeId];

  /// 获取分区列表
  List<Partition> get partitionList => partitions.values.toList();

  /// 获取最优分区（边割最小）
  Partition get bestPartition {
    return partitionList
        .reduce((a, b) => a.edgeCutRatio < b.edgeCutRatio ? a : b);
  }
}
```

#### PartitionMetrics 定义

```dart
/// 分区质量指标
class PartitionMetrics {
  /// 边割：跨分区边的数量
  final int edgeCut;

  /// 边割率：跨分区边占总边的比例
  final double edgeCutRatio;

  /// 均衡度：各分区节点数的标准差
  final double balanceScore;

  /// 模块度：衡量社区结构质量
  final double modularity;

  /// 最大分区节点数
  final int maxPartitionSize;

  /// 最小分区节点数
  final int minPartitionSize;

  /// 平均分区节点数
  final double avgPartitionSize;

  PartitionMetrics({
    required this.edgeCut,
    required this.edgeCutRatio,
    required this.balanceScore,
    required this.modularity,
    required this.maxPartitionSize,
    required this.minPartitionSize,
    required this.avgPartitionSize,
  });

  /// 计算综合质量分数（越高越好）
  double get qualityScore {
    // 归一化指标
    final normalizedEdgeCut = 1.0 - edgeCutRatio;
    final normalizedBalance = 1.0 - balanceScore;
    final normalizedModularity = modularity;

    // 加权平均
    return normalizedEdgeCut * 0.4 +
           normalizedBalance * 0.3 +
           normalizedModularity * 0.3;
  }
}
```

#### IGraphPartitioner 接口

```dart
/// 图分区器接口
abstract class IGraphPartitioner {
  /// 分区图
  ///
  /// [graph] - 要分区的图
  /// [numPartitions] - 分区数量
  /// [algorithm] - 分区算法
  /// [options] - 分区选项
  Future<PartitionResult> partition(
    Graph graph,
    int numPartitions, {
    PartitionAlgorithm algorithm = PartitionAlgorithm.metis,
    PartitionOptions? options,
  });

  /// 增量更新分区
  ///
  /// [currentResult] - 当前分区结果
  /// [changes] - 图变化
  Future<PartitionResult> updatePartition(
    PartitionResult currentResult,
    GraphChanges changes,
  });

  /// 重新平衡分区
  ///
  /// [currentResult] - 当前分区结果
  /// [strategy] - 重平衡策略
  Future<PartitionResult> rebalance(
    PartitionResult currentResult, {
    RebalanceStrategy strategy = RebalanceStrategy.light,
  });

  /// 获取支持的算法列表
  List<PartitionAlgorithm> get supportedAlgorithms;

  /// 获取推荐算法
  PartitionAlgorithm recommendAlgorithm(Graph graph);
}
```

#### PartitionAlgorithm 枚举

```dart
/// 分区算法类型
enum PartitionAlgorithm {
  /// METIS 多层图分区
  metis,

  /// Kernighan-Lin 二分算法
  kernighanLin,

  /// 标签传播算法
  labelPropagation,

  /// Louvain 社区发现
  louvain,

  /// 谱二分算法
  spectral,

  /// 随机分区
  random,
}
```

#### PartitionOptions 定义

```dart
/// 分区选项
class PartitionOptions {
  /// 最大迭代次数
  final int maxIterations;

  /// 收敛阈值
  final double convergenceThreshold;

  /// 是否允许不平衡
  final double imbalanceTolerance;

  /// 节点权重计算方式
  final NodeWeightStrategy weightStrategy;

  /// 是否使用加速结构
  final bool useAcceleration;

  /// 自定义节点权重
  final Map<String, double>? customWeights;

  PartitionOptions({
    this.maxIterations = 100,
    this.convergenceThreshold = 0.001,
    this.imbalanceTolerance = 0.05,
    this.weightStrategy = NodeWeightStrategy.uniform,
    this.useAcceleration = true,
    this.customWeights,
  });
}

/// 节点权重策略
enum NodeWeightStrategy {
  /// 统一权重
  uniform,

  /// 基于度数
  degree,

  /// 自定义权重
  custom,
}
```

## 3. 核心算法

### 3.1 METIS 多层图分区算法

**问题描述**:
如何高效地将大型图分割成 k 个均衡的子图，同时最小化边割。

**算法描述**:
METIS 使用多层收缩方法：
1. **粗化阶段**: 逐步收缩图以减少节点数
2. **初始分区**: 在最小图上进行分区
3. **细化阶段**: 将分区投影回原图并优化

**伪代码**:
```
function metisPartition(graph, k):
    // === 阶段1: 粗化 ===
    graphs = [graph]
    currentGraph = graph

    while currentGraph.nodeCount > targetSize:
        nextGraph = coarsenGraph(currentGraph)
        graphs.add(nextGraph)
        currentGraph = nextGraph

    // === 阶段2: 初始分区 ===
    partition = initialPartition(currentGraph, k)

    // === 阶段3: 细化 ===
    for i = range(len(graphs) - 1, 0, -1):
        currentGraph = graphs[i]
        partition = projectPartition(partition, currentGraph)
        partition = refinePartition(currentGraph, partition)

    return partition

function coarsenGraph(graph):
    // 使用匹配算法合并节点
    matching = findMaximalMatching(graph)
    coarsened = createCoarseGraph(graph, matching)
    return coarsened

function findMaximalMatching(graph):
    matching = {}
    visited = set()

    for node in graph.nodes:
        if node in visited:
            continue

        // 找到未访问的邻居
        for neighbor in graph.neighbors(node):
            if neighbor not in visited:
                matching[node] = neighbor
                visited.add(node)
                visited.add(neighbor)
                break

    return matching

function refinePartition(graph, partition):
    // 使用 Kernighan-Lin 局部优化
    improved = true
    iteration = 0

    while improved and iteration < maxIterations:
        improved = false
        iteration += 1

        // 计算所有节点的增益
        gains = computeGains(graph, partition)

        // 选择增益最大的节点对交换
        for (node1, node2) in sortedPairs(gains):
            if swapNodes(partition, node1, node2):
                improved = true
                break

    return partition

function computeGains(graph, partition):
    gains = Map<Pair<Node, Node>, int>

    for partition1 in partition.partitions:
        for node1 in partition1.nodes:
            for partition2 in partition.partitions:
                if partition2 == partition1:
                    continue

                for node2 in partition2.nodes:
                    // 计算交换后的边割变化
                    gain = computeEdgeCutDifference(
                        graph, partition, node1, node2
                    )
                    gains[(node1, node2)] = gain

    return gains
```

**复杂度分析**:
- 时间复杂度: O(|E| + |V| log |V|)
- 空间复杂度: O(|E| + |V|)

**实现**:

```dart
class METISPartitioner implements IGraphPartitioner {
  @override
  Future<PartitionResult> partition(
    Graph graph,
    int numPartitions, {
    PartitionAlgorithm algorithm = PartitionAlgorithm.metis,
    PartitionOptions? options,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. 粗化阶段
    final coarseningStack = <Graph>[];
    Graph currentGraph = graph;

    while (currentGraph.nodes.length > _getTargetSize(graph)) {
      final coarsened = await _coarsenGraph(currentGraph);
      coarseningStack.add(currentGraph);
      currentGraph = coarsened;
    }

    // 2. 初始分区
    var assignment = await _initialPartition(currentGraph, numPartitions);

    // 3. 细化阶段
    for (int i = coarseningStack.length - 1; i >= 0; i--) {
      currentGraph = coarseningStack[i];
      assignment = await _projectAssignment(assignment, currentGraph);
      assignment = await _refinePartition(currentGraph, assignment);
    }

    // 4. 构建结果
    final partitions = await _buildPartitions(graph, assignment);
    final metrics = await _computeMetrics(graph, partitions);

    stopwatch.stop();

    return PartitionResult(
      assignment: assignment,
      partitions: partitions,
      metrics: metrics,
      algorithm: PartitionAlgorithm.metis,
      executionTime: stopwatch.elapsed,
    );
  }

  /// 粗化图
  Future<Graph> _coarsenGraph(Graph graph) async {
    final matching = await _findMaximalMatching(graph);
    return _createCoarseGraph(graph, matching);
  }

  /// 找到最大匹配
  Future<Map<String, String?>> _findMaximalMatching(Graph graph) async {
    final matching = <String, String?>{};
    final visited = <String>{};

    for (final node in graph.nodes) {
      if (visited.contains(node.id)) continue;

      // 找到未访问的邻居
      final neighbors = graph.getNeighbors(node.id);
      String? matchedNeighbor;

      for (final neighbor in neighbors) {
        if (!visited.contains(neighbor)) {
          matchedNeighbor = neighbor;
          break;
        }
      }

      if (matchedNeighbor != null) {
        matching[node.id] = matchedNeighbor;
        visited.add(node.id);
        visited.add(matchedNeighbor);
      } else {
        matching[node.id] = null;
      }
    }

    return matching;
  }

  /// 初始分区
  Future<Map<String, PartitionId>> _initialPartition(
    Graph graph,
    int numPartitions,
  ) async {
    final assignment = <String, PartitionId>{};
    final nodes = graph.nodes.toList();

    // 简单的轮询分配
    for (int i = 0; i < nodes.length; i++) {
      final partitionId = PartitionId(i % numPartitions);
      assignment[nodes[i].id] = partitionId;
    }

    return assignment;
  }

  /// 细化分区
  Future<Map<String, PartitionId>> _refinePartition(
    Graph graph,
    Map<String, PartitionId> assignment,
  ) async {
    bool improved = true;
    int iteration = 0;
    const maxIterations = 100;

    while (improved && iteration < maxIterations) {
      improved = false;
      iteration++;

      // 计算所有节点的增益
      final gains = await _computeGains(graph, assignment);

      // 选择增益最大的节点对交换
      final sortedGains = gains.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sortedGains) {
        final node1 = entry.key.$1;
        final node2 = entry.key.$2;

        if (await _trySwap(graph, assignment, node1, node2)) {
          improved = true;
          break;
        }
      }
    }

    return assignment;
  }

  /// 计算节点交换的增益
  Future<Map<(String, String), int>> _computeGains(
    Graph graph,
    Map<String, PartitionId> assignment,
  ) async {
    final gains = <(String, String), int>{};

    for (final node1 in assignment.keys) {
      for (final node2 in assignment.keys) {
        if (node1 == node2) continue;

        final part1 = assignment[node1]!;
        final part2 = assignment[node2]!;

        if (part1 == part2) continue;

        // 计算交换后的边割变化
        final gain = await _computeGain(
          graph, assignment, node1, node2,
        );

        gains[(node1, node2)] = gain;
      }
    }

    return gains;
  }

  /// 计算单个交换的增益
  Future<int> _computeGain(
    Graph graph,
    Map<String, PartitionId> assignment,
    String node1,
    String node2,
  ) async {
    final part1 = assignment[node1]!;
    final part2 = assignment[node2]!;

    // 计算当前边割
    final currentCut = await _computeNodeEdgeCut(
      graph, assignment, node1,
    ) + await _computeNodeEdgeCut(
      graph, assignment, node2,
    );

    // 交换分区
    final swapped = Map<String, PartitionId>.from(assignment);
    swapped[node1] = part2;
    swapped[node2] = part1;

    // 计算交换后的边割
    final newCut = await _computeNodeEdgeCut(
      graph, swapped, node1,
    ) + await _computeNodeEdgeCut(
      graph, swapped, node2,
    );

    // 增益 = 当前边割 - 新边割
    return currentCut - newCut;
  }

  /// 计算节点的边割
  Future<int> _computeNodeEdgeCut(
    Graph graph,
    Map<String, PartitionId> assignment,
    String node,
  ) async {
    final nodePartition = assignment[node]!;
    int cut = 0;

    final neighbors = graph.getNeighbors(node);
    for (final neighbor in neighbors) {
      final neighborPartition = assignment[neighbor];
      if (neighborPartition != null && neighborPartition != nodePartition) {
        cut++;
      }
    }

    return cut;
  }

  /// 尝试交换两个节点
  Future<bool> _trySwap(
    Graph graph,
    Map<String, PartitionId> assignment,
    String node1,
    String node2,
  ) async {
    final part1 = assignment[node1]!;
    final part2 = assignment[node2]!;

    final beforeCut = await _computeGain(
      graph, assignment, node1, node2,
    );

    if (beforeCut > 0) {
      assignment[node1] = part2;
      assignment[node2] = part1;
      return true;
    }

    return false;
  }

  int _getTargetSize(Graph graph) {
    // 目标大小：原始图大小的 1/10
    return (graph.nodes.length / 10).ceil();
  }

  // ... 其他辅助方法
}
```

### 3.2 Kernighan-Lin 二分算法

**问题描述**:
如何优化已有的二分区，减少边割。

**算法描述**:
Kernighan-Lin 通过迭代交换节点对来优化分区。

**伪代码**:
```
function kernighanLin(graph, initialPartition):
    partition = initialPartition
    improved = true

    while improved:
        improved = false
        bestGain = 0
        bestSwap = null

        // 计算所有可能交换的增益
        for node1 in partition.sideA:
            for node2 in partition.sideB:
                gain = computeSwapGain(graph, partition, node1, node2)

                if gain > bestGain:
                    bestGain = gain
                    bestSwap = (node1, node2)

        // 执行最佳交换
        if bestSwap != null and bestGain > 0:
            partition.swap(bestSwap.node1, bestSwap.node2)
            improved = true

    return partition

function computeSwapGain(graph, partition, node1, node2):
    // 计算交换前的外部边数
    before = 0
    for neighbor in graph.neighbors(node1):
        if partition.getSide(neighbor) != partition.getSide(node1):
            before += 1

    for neighbor in graph.neighbors(node2):
        if partition.getSide(neighbor) != partition.getSide(node2):
            before += 1

    // 计算交换后的外部边数
    after = 0
    for neighbor in graph.neighbors(node1):
        if partition.getSide(neighbor) == partition.getSide(node2):
            after += 1

    for neighbor in graph.neighbors(node2):
        if partition.getSide(neighbor) == partition.getSide(node1):
            after += 1

    return before - after
```

**复杂度分析**:
- 时间复杂度: O(|V|²) 每次迭代
- 空间复杂度: O(|V|)

### 3.3 标签传播算法

**问题描述**:
如何快速发现图中的社区结构。

**算法描述**:
节点根据邻居的标签更新自己的标签。

**伪代码**:
```
function labelPropagation(graph, numCommunities):
    // 初始化：每个节点唯一的标签
    labels = {node: node.id for node in graph.nodes}

    changed = true
    iteration = 0

    while changed and iteration < maxIterations:
        changed = false
        iteration += 1

        // 随机遍历节点
        shuffledNodes = shuffle(graph.nodes)

        for node in shuffledNodes:
            // 统计邻居标签
            labelCounts = countNeighborLabels(graph, labels, node)

            // 选择最常见的标签
            if labelCounts.isNotEmpty:
                newLabel = max(labelCounts, key=labelCounts.get)

                if labels[node] != newLabel:
                    labels[node] = newLabel
                    changed = true

    // 合并小社区
    return mergeSmallCommunities(labels, numCommunities)

function countNeighborLabels(graph, labels, node):
    counts = Map<String, int>()

    for neighbor in graph.neighbors(node):
        label = labels[neighbor]
        counts[label] = counts.get(label, 0) + 1

    return counts
```

**复杂度分析**:
- 时间复杂度: O(|E| * k)，k 为迭代次数
- 空间复杂度: O(|V|)

### 3.4 Louvain 社区发现算法

**问题描述**:
如何通过最大化模块度来发现社区结构。

**算法描述**:
迭代优化模块度函数。

**伪代码**:
```
function louvain(graph):
    // 初始化：每个节点一个社区
    communities = {node: node.id for node in graph.nodes}

    improved = true
    iteration = 0

    while improved:
        improved = false
        iteration += 1

        // 第一阶段：局部移动
        for node in graph.nodes:
            currentCommunity = communities[node]
            bestCommunity = currentCommunity
            bestDelta = 0.0

            // 尝试移动到邻居社区
            neighborCommunities = getNeighborCommunities(
                graph, communities, node
            )

            for community in neighborCommunities:
                delta = computeModularityDelta(
                    graph, communities, node, community
                )

                if delta > bestDelta:
                    bestDelta = delta
                    bestCommunity = community

            if bestCommunity != currentCommunity:
                communities[node] = bestCommunity
                improved = true

        // 第二阶段：社区聚合
        if not improved:
            // 构建超图
            superGraph = buildSuperGraph(graph, communities)
            graph = superGraph
            communities = {node: node.id for node in graph.nodes}
            improved = True

    return communities

function computeModularityDelta(graph, communities, node, community):
    // 计算移动节点到社区的模块度变化
    currentCommunity = communities[node]

    // 计算当前模块度
    currentMod = computeModularity(graph, communities)

    // 临时移动节点
    communities[node] = community

    // 计算新模块度
    newMod = computeModularity(graph, communities)

    // 恢复
    communities[node] = currentCommunity

    return newMod - currentMod
```

**复杂度分析**:
- 时间复杂度: O(|E| log |V|)
- 空间复杂度: O(|E| + |V|)

## 4. 增量分区

### 4.1 变化检测

**策略**:
- 检测新增/删除节点
- 检测新增/删除边
- 识别受影响的分区

**实现**:

```dart
class IncrementalPartitionUpdater {
  /// 更新分区
  Future<PartitionResult> update(
    PartitionResult current,
    GraphChanges changes,
  ) async {
    // 1. 检测变化
    final affectedPartitions = _detectAffectedPartitions(current, changes);

    // 2. 处理删除的节点
    final updated = await _handleDeletions(current, changes);

    // 3. 处理新增的节点
    final withAdditions = await _handleAdditions(updated, changes);

    // 4. 局部重平衡
    final rebalanced = await _localRebalance(withAdditions, affectedPartitions);

    // 5. 更新指标
    final metrics = await _computeMetrics(changes.graph, rebalanced);

    return PartitionResult(
      assignment: rebalanced,
      partitions: await _buildPartitions(changes.graph, rebalanced),
      metrics: metrics,
      algorithm: current.algorithm,
      executionTime: Duration.zero,
    );
  }

  /// 检测受影响的分区
  Set<PartitionId> _detectAffectedPartitions(
    PartitionResult current,
    GraphChanges changes,
  ) {
    final affected = <PartitionId>{};

    // 检查新增节点
    for (final node in changes.addedNodes) {
      // 找到邻居所在的分区
      final neighbors = changes.graph.getNeighbors(node.id);
      for (final neighbor in neighbors) {
        final partition = current.getPartition(neighbor);
        if (partition != null) {
          affected.add(partition);
        }
      }
    }

    // 检查新增边
    for (final edge in changes.addedEdges) {
      final sourcePartition = current.getPartition(edge.source);
      final targetPartition = current.getPartition(edge.target);

      if (sourcePartition != null) affected.add(sourcePartition);
      if (targetPartition != null) affected.add(targetPartition);
    }

    return affected;
  }

  /// 局部重平衡
  Future<Map<String, PartitionId>> _localRebalance(
    Map<String, PartitionId> assignment,
    Set<PartitionId> affectedPartitions,
  ) async {
    // 只对受影响的分区进行重平衡
    // 使用轻量级的 Kernighan-Lin 优化

    final affectedNodes = assignment.entries
        .where((entry) => affectedPartitions.contains(entry.value))
        .map((entry) => entry.key)
        .toSet();

    // 局部优化
    // ... 实现细节

    return assignment;
  }
}
```

### 4.2 分区迁移

**策略**:
- 识别过载分区
- 选择候选节点迁移
- 更新分区映射

## 5. 性能考虑

### 5.1 概念性性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 分区时间 (METIS) | < 10s | 10万节点图 |
| 分区时间 (Label Propagation) | < 1s | 10万节点图 |
| 增量更新延迟 | < 100ms | 1%节点变化 |
| 边割率 | < 10% | 跨分区边比例 |
| 均衡度 | > 0.9 | 分区大小均衡 |

### 5.2 优化方向

1. **并行化**:
   - 并行粗化
   - 并行细化
   - 并行增益计算

2. **近似算法**:
   - 早期终止
   - 采样
   - 局部搜索

3. **缓存**:
   - 增益缓存
   - 邻居缓存
   - 分区缓存

4. **增量更新**:
   - 局部重分区
   - 差异计算
   - 延迟更新

### 5.3 瓶颈分析

**潜在瓶颈**:
- 图粗化阶段的匹配计算
- 细化阶段的增益计算
- 大规模图的内存占用

**解决方案**:
- 使用高效的数据结构
- 并行化关键步骤
- 流式处理大规模图

## 6. 关键文件清单

```
lib/core/partitioning/
├── graph_partitioner.dart          # IGraphPartitioner 接口
├── partition.dart                   # Partition 和 PartitionResult
├── partition_metrics.dart           # PartitionMetrics
├── algorithms/
│   ├── metis_partitioner.dart       # METIS 算法
│   ├── kernighan_lin.dart           # Kernighan-Lin 算法
│   ├── label_propagation.dart       # 标签传播算法
│   ├── louvain.dart                 # Louvain 算法
│   └── spectral.dart                # 谱二分算法
├── incremental/
│   ├── incremental_updater.dart     # 增量更新器
│   ├── change_detector.dart         # 变化检测
│   └── local_rebalancer.dart        # 局部重平衡
├── quality/
│   ├── edge_cut.dart                # 边割计算
│   ├── balance.dart                 # 均衡度计算
│   └── modularity.dart              # 模块度计算
└── utils/
    ├── graph_coarsener.dart         # 图粗化工具
    ├── matcher.dart                 # 匹配算法
    └── gain_calculator.dart         # 增益计算
```

## 7. 参考资料

### 图分区算法
- METIS - Family of Multilevel Partitioning Algorithms
- Kernighan-Lin Algorithm - Graph Partitioning
- Label Propagation Algorithm - Community Detection
- Louvain Method - Community Detection

### 相关论文
- "A Fast and High Quality Multilevel Scheme for Partitioning Irregular Graphs" - Karypis & Kumar
- "Fast unfolding of communities in large networks" - Blondel et al.
- "Near Linear Time Algorithm to Detect Community Structures in Large-Scale Networks" - Raghavan et al.

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
