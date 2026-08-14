/// 增量力导向布局引擎（M7.3 移植，旧 packages/layout 资产带走）。
///
/// 只重新布局变化的节点及其邻居（影响半径内），而不是全量重排：
/// - 修改 1 节点：全量重排 → 局部重排（~100x）
/// - 更新 1000 节点：~10s → <100ms（100x）
///
/// 算法（力导向增量版）：
/// 1. 检测变化节点（markChanged）
/// 2. BFS 扩展影响区域（≤ influenceRadius 跳）
/// 3. 只对影响区域应用斥力（库仑）+ 引力（胡克弹簧）
/// 4. 其他节点位置保持不变
///
/// 适配（旧 → 新）：旧 `AdjacencyList` 依赖删除，邻接表收敛为
/// `AdjacencyMap`（nodeId → 邻居列表，由调用方从 connect/contain
/// 实例构建）；`Vector2` → `Offset`（零新依赖）。
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:core_data/core_data.dart';

/// 邻接表：nodeId → 邻居 id 列表（无向语义由调用方保证对称）。
typedef AdjacencyMap = Map<String, List<String>>;

/// 布局统计。
class LayoutStats {
  /// 构造统计。
  const LayoutStats({
    required this.totalNodes,
    required this.changedNodes,
    required this.avgVelocity,
  });

  /// 总节点数。
  final int totalNodes;

  /// 标记变化的节点数。
  final int changedNodes;

  /// 平均速度（收敛判定）。
  final double avgVelocity;

  /// 是否收敛（速度很小）。
  bool get isConverged => avgVelocity < 0.1;
}

/// 增量力导向布局引擎。
class IncrementalLayoutEngine {
  /// 注入物理参数（旧资产默认值原样保留）。
  IncrementalLayoutEngine({
    this.repulsion = 800.0,
    this.springLength = 100.0,
    this.springK = 0.05,
    this.damping = 0.85,
    this.maxIterations = 50,
    this.influenceRadius = 2,
  });

  /// 斥力强度。
  final double repulsion;

  /// 弹簧自然长度。
  final double springLength;

  /// 弹簧系数。
  final double springK;

  /// 阻尼系数。
  final double damping;

  /// 最大迭代次数。
  final int maxIterations;

  /// 影响半径（跳数）。
  final int influenceRadius;

  /// 随机数生成器（除零抖动）。
  final math.Random _random = math.Random();

  /// 节点位置：nodeId → Offset。
  final Map<String, Offset> _positions = <String, Offset>{};

  /// 节点速度：nodeId → Offset。
  final Map<String, Offset> _velocities = <String, Offset>{};

  /// 变化的节点集合。
  final Set<String> _changedNodes = <String>{};

  /// 是否已初始化。
  bool get isInitialized => _positions.isNotEmpty;

  /// 初始化布局：[currentPositions] 缺省节点从 (0,0) 起步。
  void initializeLayout(
    List<Node> nodes,
    Map<String, Offset> currentPositions,
    AdjacencyMap adjacency,
  ) {
    _positions.clear();
    _velocities.clear();
    for (final node in nodes) {
      final current = currentPositions[node.id];
      _positions[node.id] = current ?? Offset.zero;
      _velocities[node.id] = Offset.zero;
    }
  }

  /// 标记节点为已变化。
  void markChanged(List<String> nodeIds) {
    _changedNodes.addAll(nodeIds);
  }

  /// 执行增量布局，返回受影响节点列表（变化节点 + 影响半径内邻居）。
  List<String> performIncrementalLayout(
    List<Node> nodes,
    AdjacencyMap adjacency,
  ) {
    if (_changedNodes.isEmpty) {
      return const <String>[];
    }
    final affectedNodes = _determineAffectedNodes(adjacency);
    _changedNodes.clear();
    _applyLayoutForces(affectedNodes, adjacency);
    return affectedNodes.toList();
  }

  /// BFS 扩展影响区域（变化节点 + 影响半径内邻居）。
  Set<String> _determineAffectedNodes(AdjacencyMap adjacency) {
    final affected = <String>{};
    final visited = <String>{};
    final queue = Queue<String>();
    for (final nodeId in _changedNodes) {
      queue.add(nodeId);
      visited.add(nodeId);
    }
    var currentRadius = 0;
    while (queue.isNotEmpty && currentRadius <= influenceRadius) {
      final levelSize = queue.length;
      final isLastLevel = currentRadius == influenceRadius;
      for (var i = 0; i < levelSize; i++) {
        final nodeId = queue.removeFirst();
        affected.add(nodeId);
        if (!isLastLevel) {
          for (final neighborId in adjacency[nodeId] ?? const <String>[]) {
            if (!visited.contains(neighborId)) {
              visited.add(neighborId);
              queue.add(neighborId);
            }
          }
        }
      }
      currentRadius++;
    }
    return affected;
  }

  /// 对影响区域应用布局力（maxIterations 次迭代）。
  void _applyLayoutForces(Set<String> affectedNodes, AdjacencyMap adjacency) {
    for (var iteration = 0; iteration < maxIterations; iteration++) {
      final forces = <String, Offset>{};
      for (final nodeId in affectedNodes) {
        forces[nodeId] = _calculateNodeForce(nodeId, affectedNodes, adjacency);
      }
      for (final nodeId in affectedNodes) {
        final velocity = _velocities[nodeId]!;
        final newVelocity = velocity * damping + forces[nodeId]!;
        _velocities[nodeId] = newVelocity;
        _positions[nodeId] = _positions[nodeId]! + newVelocity;
      }
    }
  }

  /// 计算节点受力（斥力 ∀ affected + 引力 ∀ 连接邻居）。
  Offset _calculateNodeForce(
    String nodeId,
    Set<String> affectedNodes,
    AdjacencyMap adjacency,
  ) {
    final position = _positions[nodeId]!;
    var force = Offset.zero;
    // 1. 库仑斥力（影响区域内所有节点之间）：F = k / r²。
    for (final otherId in affectedNodes) {
      if (nodeId == otherId) {
        continue;
      }
      final direction = position - _positions[otherId]!;
      final distance = direction.distance;
      if (distance < 0.1) {
        // 防除零：随机抖动。
        force +=
            Offset(_random.nextDouble() - 0.5, _random.nextDouble() - 0.5) *
            repulsion;
      } else {
        force += direction / distance * (repulsion / (distance * distance));
      }
    }
    // 2. 胡克引力（连接邻居，仅限影响区域内）：F = k * (r - L)。
    for (final neighborId in adjacency[nodeId] ?? const <String>[]) {
      if (!affectedNodes.contains(neighborId)) {
        continue;
      }
      final direction = _positions[neighborId]! - position;
      final distance = direction.distance;
      if (distance < 0.001) {
        continue;
      }
      force += direction / distance * (distance - springLength) * springK;
    }
    return force;
  }

  /// 节点位置（null = 未初始化/未知）。
  Offset? getPosition(String nodeId) => _positions[nodeId];

  /// 显式设置节点位置。
  void setPosition(String nodeId, Offset position) {
    _positions[nodeId] = position;
  }

  /// 全部位置。
  Map<String, Offset> getAllPositions() => Map<String, Offset>.from(_positions);

  /// 布局统计。
  LayoutStats get stats {
    final totalVelocity = _velocities.values.fold<double>(
      0,
      (sum, v) => sum + v.distance,
    );
    final avgVelocity = _velocities.isEmpty
        ? 0.0
        : totalVelocity / _velocities.length;
    return LayoutStats(
      totalNodes: _positions.length,
      changedNodes: _changedNodes.length,
      avgVelocity: avgVelocity,
    );
  }
}
