# 团检测器设计文档

## 1. 概述

### 1.1 职责
团检测器是图分析和社区发现的核心组件，负责：
- 检测图中的极大团（Maximal Cliques）
- 查找最大团（Maximum Clique）
- 发现准团（Near-Cliques）和密集子图
- 计算团的统计信息和质量指标
- 支持增量团检测和动态更新

### 1.2 目标
- **准确性**: 精确检测所有极大团
- **性能**: 在合理时间内处理大规模图
- **灵活性**: 支持多种团定义和变体
- **可扩展性**: 支持并行和分布式处理
- **实用性**: 提供有意义的团质量评估

### 1.3 关键挑战
- **计算复杂度**: 团检测是 NP 完全问题
- **搜索空间**: 可能存在指数级数量的团
- **内存限制**: 存储所有团需要大量内存
- **动态更新**: 图变化时高效更新团集合
- **噪音数据**: 真实图中完美团很少

## 2. 架构设计

### 2.1 组件结构

```
CliqueDetector
    │
    ├── Detection Algorithms (检测算法)
    │   ├── Bron-Kerbosch (枚举极大团)
    │   ├── Tomita Algorithm (优化的 Bron-Kerbosch)
    │   ├── Branch and Bound (最大团搜索)
    │   └── Heuristic Search (启发式搜索)
    │
    ├── Clique Types (团类型)
    │   ├── Maximal Clique (极大团)
    │   ├── Maximum Clique (最大团)
    │   ├── k-Clique (k-团)
    │   └── Near-Clique (准团)
    │
    ├── Quality Metrics (质量指标)
    │   ├── Clique Size (团大小)
    │   ├── Density (密度)
    │   ├── Cohesion (内聚度)
    │   └── Stability (稳定性)
    │
    ├── Pruning Strategies (剪枝策略)
    │   ├── Degree Pruning (度数剪枝)
    │   ├── Color Pruning (着色剪枝)
    │   ├── Core Decomposition (核分解)
    │   └── Triangular Pruning (三角形剪枝)
    │
    └── Incremental Updater (增量更新器)
        ├── Clique Maintenance (团维护)
        ├── Incremental Detection (增量检测)
        └── Delta Computation (差值计算)
```

### 2.2 接口定义

#### Clique 定义

```dart
/// 团标识符
class CliqueId {
  final String value;
  const CliqueId(this.value);

  factory CliqueId.generate() {
    return CliqueId(DateTime.now().millisecondsSinceEpoch.toString());
  }

  @override
  bool operator ==(Object other) =>
      other is CliqueId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// 团信息
class Clique {
  /// 团 ID
  final CliqueId id;

  /// 节点集合
  final Set<String> nodeIds;

  /// 团类型
  final CliqueType type;

  /// 密度（0-1）
  final double density;

  /// 创建时间
  final DateTime createdAt;

  /// 是否是极大团
  final bool isMaximal;

  Clique({
    required this.id,
    required this.nodeIds,
    required this.type,
    required this.density,
    DateTime? createdAt,
    this.isMaximal = false,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 获取团大小
  int get size => nodeIds.length;

  /// 是否包含节点
  bool containsNode(String nodeId) => nodeIds.contains(nodeId);

  /// 计算与另一个团的交集
  Set<String> intersection(Clique other) {
    return nodeIds.intersection(other.nodeIds);
  }

  /// 计算与另一个团的并集
  Set<String> union(Clique other) {
    return nodeIds.union(other.nodeIds);
  }

  /// 复制团
  Clique copyWith({
    CliqueId? id,
    Set<String>? nodeIds,
    CliqueType? type,
    double? density,
    bool? isMaximal,
  }) {
    return Clique(
      id: id ?? this.id,
      nodeIds: nodeIds ?? this.nodeIds,
      type: type ?? this.type,
      density: density ?? this.density,
      createdAt: createdAt,
      isMaximal: isMaximal ?? this.isMaximal,
    );
  }
}
```

#### CliqueType 枚举

```dart
/// 团类型
enum CliqueType {
  /// 极大团（无法再添加节点）
  maximal,

  /// 最大团（图中节点数最多的团）
  maximum,

  /// k-团（大小为 k 的团）
  kClique,

  /// 准团（密度接近 1）
  nearClique,

  /// 密集子图
  denseSubgraph,
}
```

#### CliqueResult 定义

```dart
/// 团检测结果
class CliqueResult {
  /// 所有检测到的团
  final List<Clique> cliques;

  /// 最大团
  final Clique? maximumClique;

  /// 统计信息
  final CliqueStats stats;

  /// 检测算法
  final CliqueAlgorithm algorithm;

  /// 执行时间
  final Duration executionTime;

  CliqueResult({
    required this.cliques,
    this.maximumClique,
    required this.stats,
    required this.algorithm,
    required this.executionTime,
  });

  /// 获取所有极大团
  List<Clique> get maximalCliques =>
      cliques.where((c) => c.isMaximal).toList();

  /// 获取指定大小的团
  List<Clique> getCliquesOfSize(int size) =>
      cliques.where((c) => c.size == size).toList();

  /// 按大小排序的团
  List<Clique> get cliquesBySize {
    final sorted = List<Clique>.from(cliques);
    sorted.sort((a, b) => b.size.compareTo(a.size));
    return sorted;
  }
}
```

#### CliqueStats 定义

```dart
/// 团统计信息
class CliqueStats {
  /// 团总数
  final int totalCliques;

  /// 极大团数量
  final int maximalCliques;

  /// 最大团大小
  final int maximumSize;

  /// 平均团大小
  final double averageSize;

  /// 大小分布
  final Map<int, int> sizeDistribution;

  /// 节点参与团的数量（平均值）
  final double averageCliquePerNode;

  CliqueStats({
    required this.totalCliques,
    required this.maximalCliques,
    required this.maximumSize,
    required this.averageSize,
    required this.sizeDistribution,
    required this.averageCliquePerNode,
  });
}
```

#### ICliqueDetector 接口

```dart
/// 团检测器接口
abstract class ICliqueDetector {
  /// 检测所有极大团
  Future<CliqueResult> detectMaximalCliques(
    Graph graph, {
    CliqueDetectionOptions? options,
  });

  /// 查找最大团
  Future<Clique?> findMaximumClique(
    Graph graph, {
    CliqueDetectionOptions? options,
  });

  /// 查找所有 k-团
  Future<List<Clique>> findKCliques(
    Graph graph,
    int k, {
    CliqueDetectionOptions? options,
  });

  /// 查找准团
  Future<List<Clique>> findNearCliques(
    Graph graph, {
    double minDensity = 0.8,
    int minSize = 3,
    CliqueDetectionOptions? options,
  });

  /// 增量更新团检测
  Future<CliqueResult> incrementalUpdate(
    CliqueResult previous,
    GraphChanges changes,
  );

  /// 获取节点所属的团
  Future<List<Clique>> getCliquesForNode(
    Graph graph,
    String nodeId,
  );

  /// 获取支持的算法
  List<CliqueAlgorithm> get supportedAlgorithms;

  /// 推荐算法
  CliqueAlgorithm recommendAlgorithm(Graph graph);
}
```

#### CliqueAlgorithm 枚举

```dart
/// 团检测算法
enum CliqueAlgorithm {
  /// Bron-Kerbosch 基本算法
  bronKerbosch,

  /// Bron-Kerbosch with Pivot（带轴优化）
  bronKerboschPivot,

  /// Tomita Algorithm（Tomita 算法）
  tomita,

  /// Branch and Bound（分支定界）
  branchAndBound,

  /// Heuristic Search（启发式搜索）
  heuristic,
}
```

#### CliqueDetectionOptions 定义

```dart
/// 团检测选项
class CliqueDetectionOptions {
  /// 最小团大小
  final int minSize;

  /// 最大团大小（0 表示无限制）
  final int maxSize;

  /// 是否只返回极大团
  final bool maximalOnly;

  /// 最大团数量限制（0 表示无限制）
  final int maxCliques;

  /// 是否使用并行处理
  final bool useParallel;

  /// 超时时间
  final Duration? timeout;

  /// 剪枝策略
  final PruningStrategy pruningStrategy;

  CliqueDetectionOptions({
    this.minSize = 3,
    this.maxSize = 0,
    this.maximalOnly = true,
    this.maxCliques = 0,
    this.useParallel = false,
    this.timeout,
    this.pruningStrategy = PruningStrategy.adaptive,
  });
}

/// 剪枝策略
enum PruningStrategy {
  /// 自适应
  adaptive,

  /// 度数剪枝
  degree,

  /// 着色剪枝
  coloring,

  /// 核分解
  core,

  /// 无剪枝
  none,
}
```

## 3. 核心算法

### 3.1 Bron-Kerbosch 算法

**问题描述**:
枚举图中的所有极大团。

**算法描述**:
使用回溯和剪枝的递归算法。

**伪代码**:
```
function bronKerbosch(R, P, X):
    if P is empty and X is empty:
        report R as a maximal clique
        return

    // 选择轴顶点（用于优化）
    u = selectPivot(P ∪ X)

    for v in P \ N(u):
        // 递归调用
        bronKerbosch(R ∪ {v}, P ∩ N(v), X ∩ N(v))

        // 将 v 从 P 移到 X
        P = P \ {v}
        X = X ∪ {v}

function bronKerboschWithPivot(R, P, X):
    if P is empty and X is empty:
        report R as a maximal clique
        return

    // 选择轴顶点
    u = selectPivot(P ∪ X)

    // 遍历 P \ N(u)
    for v in P \ N(u):
        bronKerboschWithPivot(R ∪ {v}, P ∩ N(v), X ∩ N(v))
        P = P \ {v}
        X = X ∪ {v}
```

**复杂度分析**:
- 时间复杂度: O(3^(n/3))，n 为节点数
- 空间复杂度: O(n)

**实现**:

```dart
class BronKerboschDetector implements ICliqueDetector {
  @override
  Future<CliqueResult> detectMaximalCliques(
    Graph graph, {
    CliqueDetectionOptions? options,
  }) async {
    final stopwatch = Stopwatch()..start();
    final opts = options ?? CliqueDetectionOptions();

    final cliques = <Clique>[];
    final nodes = graph.nodes.map((n) => n.id).toSet();

    // 初始化
    final R = <String>{};  // 当前团
    final P = Set<String>.from(nodes);  // 候选节点
    final X = <String>{};  // 已处理节点

    // 递归搜索
    await _bronKerbosch(
      graph,
      R,
      P,
      X,
      cliques,
      opts,
      stopwatch,
    );

    // 计算统计信息
    final stats = await _computeStats(cliques, graph);
    final maximumClique = _findMaximumClique(cliques);

    stopwatch.stop();

    return CliqueResult(
      cliques: cliques,
      maximumClique: maximumClique,
      stats: stats,
      algorithm: CliqueAlgorithm.bronKerbosch,
      executionTime: stopwatch.elapsed,
    );
  }

  Future<void> _bronKerbosch(
    Graph graph,
    Set<String> R,
    Set<String> P,
    Set<String> X,
    List<Clique> cliques,
    CliqueDetectionOptions options,
    Stopwatch stopwatch,
  ) async {
    // 检查超时
    if (options.timeout != null &&
        stopwatch.elapsed > options.timeout!) {
      return;
    }

    // 检查最大团数量限制
    if (options.maxCliques > 0 && cliques.length >= options.maxCliques) {
      return;
    }

    // 终止条件
    if (P.isEmpty && X.isEmpty) {
      // 找到极大团
      if (R.length >= options.minSize) {
        final clique = Clique(
          id: CliqueId.generate(),
          nodeIds: R,
          type: CliqueType.maximal,
          density: await _computeDensity(graph, R),
          isMaximal: true,
        );
        cliques.add(clique);
      }
      return;
    }

    // 选择轴顶点
    final pivot = _selectPivot(P, X, graph);

    // 遍历候选节点
    final candidates = P.difference(graph.getNeighbors(pivot));

    for (final v in candidates) {
      final neighbors = graph.getNeighbors(v);

      await _bronKerbosch(
        graph,
        {...R, v},
        P.intersection(neighbors),
        X.intersection(neighbors),
        cliques,
        options,
        stopwatch,
      );

      P.remove(v);
      X.add(v);
    }
  }

  /// 选择轴顶点
  String _selectPivot(Set<String> P, Set<String> X, Graph graph) {
    // 选择 P ∪ X 中度数最大的顶点
    final union = {...P, ...X};

    String maxNode = '';
    int maxDegree = -1;

    for (final node in union) {
      final degree = graph.getDegree(node);
      if (degree > maxDegree) {
        maxDegree = degree;
        maxNode = node;
      }
    }

    return maxNode;
  }

  /// 计算团密度
  Future<double> _computeDensity(Graph graph, Set<String> nodes) async {
    final n = nodes.length;
    if (n < 2) return 1.0;

    int edgeCount = 0;
    final nodeList = nodes.toList();

    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        if (graph.hasEdge(nodeList[i], nodeList[j])) {
          edgeCount++;
        }
      }
    }

    final maxEdges = n * (n - 1) ~/ 2;
    return maxEdges > 0 ? edgeCount / maxEdges : 0.0;
  }

  /// 计算统计信息
  Future<CliqueStats> _computeStats(List<Clique> cliques, Graph graph) async {
    if (cliques.isEmpty) {
      return CliqueStats(
        totalCliques: 0,
        maximalCliques: 0,
        maximumSize: 0,
        averageSize: 0.0,
        sizeDistribution: {},
        averageCliquePerNode: 0.0,
      );
    }

    final maximalCliques = cliques.where((c) => c.isMaximal).length;
    final sizes = cliques.map((c) => c.size).toList();
    final maximumSize = sizes.reduce((a, b) => a > b ? a : b);
    final averageSize = sizes.reduce((a, b) => a + b) / sizes.length;

    // 大小分布
    final sizeDistribution = <int, int>{};
    for (final size in sizes) {
      sizeDistribution[size] = (sizeDistribution[size] ?? 0) + 1;
    }

    // 节点参与团的平均数量
    final nodeCliqueCount = <String, int>{};
    for (final clique in cliques) {
      for (final node in clique.nodeIds) {
        nodeCliqueCount[node] = (nodeCliqueCount[node] ?? 0) + 1;
      }
    }

    final avgCliquePerNode = nodeCliqueCount.values.isEmpty
        ? 0.0
        : nodeCliqueCount.values.reduce((a, b) => a + b) /
            nodeCliqueCount.values.length;

    return CliqueStats(
      totalCliques: cliques.length,
      maximalCliques: maximalCliques,
      maximumSize: maximumSize,
      averageSize: averageSize,
      sizeDistribution: sizeDistribution,
      averageCliquePerNode: avgCliquePerNode,
    );
  }

  Clique? _findMaximumClique(List<Clique> cliques) {
    if (cliques.isEmpty) return null;

    Clique? maximum;
    int maxSize = 0;

    for (final clique in cliques) {
      if (clique.size > maxSize) {
        maxSize = clique.size;
        maximum = clique;
      }
    }

    return maximum;
  }

  // ... 其他方法实现
}
```

### 3.2 Tomita 算法（优化的 Bron-Kerbosch）

**问题描述**:
优化 Bron-Kerbosch 算法的性能。

**算法描述**:
使用更高效的剪枝策略和顶点排序。

**伪代码**:
```
function tomita(R, P, X):
    if P is empty and X is empty:
        report R as a maximal clique
        return

    // 排序 P 中的顶点
    P = sortVertices(P)

    // 选择轴顶点
    u = selectPivot(P ∪ X)

    for v in P \ N(u) in descending order:
        tomita(R ∪ {v}, P ∩ N(v), X ∩ N(v))
        P = P \ {v}
        X = X ∪ {v}

function sortVertices(P):
    // 按度数降序排序
    return P sorted by degree in descending order
```

**复杂度分析**:
- 时间复杂度: O(3^(n/3))，实际性能优于基本 Bron-Kerbosch
- 空间复杂度: O(n)

### 3.3 分支定界算法（最大团）

**问题描述**:
找到图中最大的团。

**算法描述**:
使用上界估计剪枝子树。

**伪代码**:
```
function branchAndBound(graph):
    bestClique = {}
    maxSize = 0

    // 按度数排序节点
    nodes = sortNodesByDegree(graph)

    // 递归搜索
    for node in nodes:
        currentClique = {node}
        candidates = graph.neighbors(node) ∩ nodes_after(node)

        search(graph, currentClique, candidates, maxSize, bestClique)

    return bestClique

function search(graph, current, candidates, maxSize, bestClique):
    // 计算上界
    upperBound = current.size + candidates.size

    if upperBound <= maxSize:
        return  // 剪枝

    if candidates.isEmpty:
        if current.size > maxSize:
            maxSize = current.size
            bestClique = current
        return

    // 选择候选节点
    while candidates not empty:
        v = selectCandidate(candidates)

        search(
            graph,
            current ∪ {v},
            candidates ∩ graph.neighbors(v),
            maxSize,
            bestClique
        )

        candidates = candidates \ {v}
```

**实现**:

```dart
class BranchAndBoundDetector implements ICliqueDetector {
  @override
  Future<Clique?> findMaximumClique(
    Graph graph, {
    CliqueDetectionOptions? options,
  }) async {
    final opts = options ?? CliqueDetectionOptions();

    // 按度数排序节点
    final nodes = graph.nodes.toList()
      ..sort((a, b) => graph.getDegree(b.id).compareTo(graph.getDegree(a.id)));

    List<String>? bestClique;
    int maxSize = 0;

    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i].id;
      final current = [node];
      final candidates = _getFutureCandidates(graph, nodes, i);

      await _search(
        graph,
        current,
        candidates,
        maxSize,
        bestClique,
        opts,
      );

      if (bestClique != null) {
        maxSize = bestClique!.length;
      }
    }

    if (bestClique == null) return null;

    return Clique(
      id: CliqueId.generate(),
      nodeIds: bestClique.toSet(),
      type: CliqueType.maximum,
      density: await _computeDensity(graph, bestClique.toSet()),
      isMaximal: true,
    );
  }

  Future<void> _search(
    Graph graph,
    List<String> current,
    List<String> candidates,
    int maxSize,
    List<String>? bestClique,
    CliqueDetectionOptions options,
  ) async {
    // 计算上界
    final upperBound = current.length + candidates.length;

    if (upperBound <= maxSize) {
      return; // 剪枝
    }

    if (candidates.isEmpty) {
      if (current.length > maxSize) {
        maxSize = current.length;
        bestClique = List.from(current);
      }
      return;
    }

    // 选择候选节点
    while (candidates.isNotEmpty) {
      final v = candidates.removeAt(0);

      await _search(
        graph,
        [...current, v],
        _intersectWithNeighbors(graph, candidates, v),
        maxSize,
        bestClique,
        options,
      );

      if (bestClique != null) {
        maxSize = bestClique!.length;
      }
    }
  }

  List<String> _getFutureCandidates(Graph graph, List<Node> nodes, int index) {
    final result = <String>[];
    final node = nodes[index];

    for (int i = index + 1; i < nodes.length; i++) {
      if (graph.hasEdge(node.id, nodes[i].id)) {
        result.add(nodes[i].id);
      }
    }

    return result;
  }

  List<String> _intersectWithNeighbors(
    Graph graph,
    List<String> candidates,
    String node,
  ) {
    final neighbors = graph.getNeighbors(node);
    return candidates.where((c) => neighbors.contains(c)).toList();
  }

  Future<double> _computeDensity(Graph graph, Set<String> nodes) async {
    // ... 同 Bron-Kerbosch 实现
    return 1.0;
  }

  // ... 其他方法实现
}
```

### 3.4 准团检测

**问题描述**:
找到密度接近 1 的子图。

**算法描述**:
基于密度阈值的启发式搜索。

**伪代码**:
```
function findNearCliques(graph, minDensity, minSize):
    cliques = []

    for node in graph.nodes:
        // 从节点开始扩展
        clique = {node}
        candidates = graph.neighbors(node)

        while candidates not empty:
            // 计算添加每个候选后的密度
            bestCandidate = null
            bestDensity = 0

            for v in candidates:
                newClique = clique ∪ {v}
                density = computeDensity(graph, newClique)

                if density > bestDensity:
                    bestDensity = density
                    bestCandidate = v

            if bestDensity >= minDensity:
                clique = clique ∪ {bestCandidate}
                candidates = candidates ∩ graph.neighbors(bestCandidate)
            else:
                break

        if clique.size >= minSize:
            cliques.add(clique)

    return deduplicate(cliques)
```

**实现**:

```dart
class NearCliqueDetector {
  Future<List<Clique>> findNearCliques(
    Graph graph, {
    double minDensity = 0.8,
    int minSize = 3,
  }) async {
    final cliques = <Clique>[];

    for (final node in graph.nodes) {
      final clique = await _expandClique(
        graph,
        node.id,
        minDensity,
      );

      if (clique.length >= minSize) {
        cliques.add(Clique(
          id: CliqueId.generate(),
          nodeIds: clique.toSet(),
          type: CliqueType.nearClique,
          density: await _computeDensity(graph, clique),
        ));
      }
    }

    // 去重
    return _deduplicate(cliques);
  }

  Future<List<String>> _expandClique(
    Graph graph,
    String startNode,
    double minDensity,
  ) async {
    var clique = <String>[startNode];
    var candidates = graph.getNeighbors(startNode).toList();

    while (candidates.isNotEmpty) {
      String? bestCandidate;
      double bestDensity = 0.0;

      for (final candidate in candidates) {
        final newClique = {...clique.toSet(), candidate};
        final density = await _computeDensity(graph, newClique);

        if (density > bestDensity) {
          bestDensity = density;
          bestCandidate = candidate;
        }
      }

      if (bestCandidate != null && bestDensity >= minDensity) {
        clique.add(bestCandidate!);
        final neighbors = graph.getNeighbors(bestCandidate);
        candidates = candidates.where((c) => neighbors.contains(c)).toList();
      } else {
        break;
      }
    }

    return clique;
  }

  List<Clique> _deduplicate(List<Clique> cliques) {
    // 去除重复的团
    final unique = <Clique>[];

    for (final clique in cliques) {
      bool isDuplicate = false;

      for (final existing in unique) {
        if (_isSameClique(clique, existing)) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        unique.add(clique);
      }
    }

    return unique;
  }

  bool _isSameClique(Clique a, Clique b) {
    return a.nodeIds.length == b.nodeIds.length &&
        a.nodeIds.difference(b.nodeIds).isEmpty;
  }

  Future<double> _computeDensity(Graph graph, Set<String> nodes) async {
    // ... 同之前的实现
    return 1.0;
  }
}
```

## 4. 剪枝策略

### 4.1 度数剪枝

**策略**:
移除度数小于 k 的节点。

**实现**:

```dart
class DegreePruning {
  Graph prune(Graph graph, int minDegree) {
    var pruned = graph;

    bool changed = true;
    while (changed) {
      changed = false;
      final toRemove = <String>[];

      for (final node in pruned.nodes) {
        if (pruned.getDegree(node.id) < minDegree) {
          toRemove.add(node.id);
          changed = true;
        }
      }

      for (final nodeId in toRemove) {
        pruned = pruned.removeNode(nodeId);
      }
    }

    return pruned;
  }
}
```

### 4.2 着色剪枝

**策略**:
使用图着色估计上界。

**实现**:

```dart
class ColoringPruning {
  /// 计算图的颜色数
  int colorGraph(Graph graph, Set<String> vertices) {
    final colors = <String, int>{};
    int maxColor = 0;

    for (final vertex in vertices) {
      final usedColors = _getUsedColors(graph, vertex, colors, vertices);

      // 找到最小的可用颜色
      int color = 0;
      while (usedColors.contains(color)) {
        color++;
      }

      colors[vertex] = color;
      maxColor = max(maxColor, color);
    }

    return maxColor + 1;
  }

  Set<int> _getUsedColors(
    Graph graph,
    String vertex,
    Map<String, int> colors,
    Set<String> vertices,
  ) {
    final used = <int>{};
    final neighbors = graph.getNeighbors(vertex);

    for (final neighbor in neighbors) {
      if (vertices.contains(neighbor)) {
        final color = colors[neighbor];
        if (color != null) {
          used.add(color);
        }
      }
    }

    return used;
  }
}
```

## 5. 增量更新

### 5.1 团维护

**策略**:
- 新增边：检查是否形成新团
- 删除边：更新受影响的团

**实现**:

```dart
class IncrementalCliqueUpdater {
  /// 处理边插入
  Future<List<Clique>> handleEdgeInsertion(
    List<Clique> existingCliques,
    Graph graph,
    Edge edge,
  ) async {
    final newCliques = <Clique>[];
    final u = edge.source;
    final v = edge.target;

    // 查找同时连接 u 和 v 的团
    for (final clique in existingCliques) {
      if (clique.nodeIds.contains(u) || clique.nodeIds.contains(v)) {
        // 检查是否可以扩展团
        if (await _canExtendClique(graph, clique, edge)) {
          final extended = await _extendClique(graph, clique, edge);
          if (extended != null) {
            newCliques.add(extended);
          }
        }
      }
    }

    return [...existingCliques, ...newCliques];
  }

  Future<bool> _canExtendClique(Graph graph, Clique clique, Edge edge) async {
    // 检查添加边后是否仍然是团
    final nodes = {...clique.nodeIds, edge.source, edge.target};

    for (final node1 in nodes) {
      for (final node2 in nodes) {
        if (node1 != node2 && !graph.hasEdge(node1, node2)) {
          return false;
        }
      }
    }

    return true;
  }

  Future<Clique?> _extendClique(Graph graph, Clique clique, Edge edge) async {
    final nodes = {...clique.nodeIds, edge.source, edge.target};
    final density = await _computeDensity(graph, nodes);

    return Clique(
      id: CliqueId.generate(),
      nodeIds: nodes,
      type: clique.type,
      density: density,
      isMaximal: await _isMaximal(graph, nodes),
    );
  }

  Future<bool> _isMaximal(Graph graph, Set<String> nodes) async {
    // 检查是否可以添加节点
    for (final node in graph.nodes) {
      if (!nodes.contains(node.id)) {
        bool allConnected = true;

        for (final n in nodes) {
          if (!graph.hasEdge(node.id, n)) {
            allConnected = false;
            break;
          }
        }

        if (allConnected) {
          return false; // 可以扩展，不是极大团
        }
      }
    }

    return true;
  }

  Future<double> _computeDensity(Graph graph, Set<String> nodes) async {
    // ... 同之前的实现
    return 1.0;
  }
}
```

## 6. 性能考虑

### 6.1 概念性性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 极大团枚举 | < 10s | 1000节点图 |
| 最大团查找 | < 1s | 1000节点图 |
| k-团检测 | < 5s | k=5, 1000节点 |
| 准团检测 | < 1s | 1000节点图 |
| 内存占用 | < 100MB | 1000节点图 |

### 6.2 优化方向

1. **并行化**:
   - 并行搜索子树
   - 并行密度计算
   - 多线程处理

2. **近似算法**:
   - 采样
   - 局部搜索
   - 启发式方法

3. **索引优化**:
   - 邻居索引
   - 度数索引
   - 三角形索引

4. **早期终止**:
   - 达到目标数量
   - 超时限制
   - 质量阈值

### 6.3 瓶颈分析

**潜在瓶颈**:
- 指数级搜索空间
- 内存限制
- 图密度过高

**解决方案**:
- 剪枝优化
- 并行处理
- 增量更新
- 近似算法

## 7. 关键文件清单

```
lib/core/clique/
├── clique_detector.dart             # ICliqueDetector 接口
├── clique.dart                      # Clique 和 CliqueResult
├── clique_stats.dart                # CliqueStats 定义
├── algorithms/
│   ├── bron_kerbosch.dart           # Bron-Kerbosch 算法
│   ├── tomita.dart                  # Tomita 算法
│   ├── branch_and_bound.dart        # 分支定界算法
│   └── near_clique.dart             # 准团检测
├── pruning/
│   ├── degree_pruning.dart          # 度数剪枝
│   ├── coloring_pruning.dart        # 着色剪枝
│   ├── core_decomposition.dart      # 核分解
│   └── triangular_pruning.dart      # 三角形剪枝
├── incremental/
│   ├── incremental_updater.dart     # 增量更新器
│   ├── edge_insertion.dart          # 边插入处理
│   └── edge_deletion.dart           # 边删除处理
├── quality/
│   ├── density.dart                 # 密度计算
│   ├── cohesion.dart                # 内聚度计算
│   └── stability.dart               # 稳定性计算
└── utils/
    ├── graph_utils.dart             # 图工具函数
    ├── clique_utils.dart            # 团工具函数
    └── deduplicator.dart            # 去重工具
```

## 8. 参考资料

### 团检测算法
- Bron-Kerbosch Algorithm - Maximal Cliques Enumeration
- Tomita Algorithm - Efficient Clique Enumeration
- Branch and Bound - Maximum Clique

### 优化技术
- Graph Coloring - Upper Bound Estimation
- Core Decomposition - Pruning Strategy
- Pivot Selection - Algorithm Optimization

### 相关论文
- "Algorithm 457: Finding All Cliques of an Undirected Graph" - Bron & Kerbosch
- "The Worst-Case Time Complexity for Generating All Maximal Cliques" - Tomita et al.
- "A Fast Algorithm for the Maximum Clique Problem" - Carraghan & Pardalos

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
