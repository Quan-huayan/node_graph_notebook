/// 布局算法（M7.3）：力导向（增量引擎全量模式）/ 网格 / 树状。
///
/// 输入节点列表 + 当前位置 + 邻接表 → 输出 nodeId → 新位置映射。
/// 纯计算，零存储写（写路径归 ApplyLayoutHandler）。
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:core_data/core_data.dart';

import 'layout_engine.dart';

/// 布局算法类型。
enum LayoutAlgorithm {
  /// 力导向（增量引擎全量模式——markChanged 全部节点）。
  force,

  /// 网格（确定性，仿可见性对话框槽位）。
  grid,

  /// 树状（BFS 分层：无入度节点为根，层间垂直、层内水平分布）。
  tree,
}

/// 布局算法入口。
class LayoutAlgorithms {
  /// 计算布局（节点全部覆盖；无位置节点从 (0,0) 起步）。
  static Map<String, Offset> compute(
    LayoutAlgorithm algorithm,
    List<Node> nodes,
    Map<String, Offset> currentPositions,
    AdjacencyMap adjacency,
  ) {
    switch (algorithm) {
      case LayoutAlgorithm.force:
        return forceDirected(nodes, currentPositions, adjacency);
      case LayoutAlgorithm.grid:
        return grid(nodes);
      case LayoutAlgorithm.tree:
        return tree(nodes, adjacency);
    }
  }

  /// 力导向（增量引擎全量模式：全部节点标记变化 → 一次增量布局）。
  static Map<String, Offset> forceDirected(
    List<Node> nodes,
    Map<String, Offset> currentPositions,
    AdjacencyMap adjacency,
  ) {
    final engine = IncrementalLayoutEngine();
    engine.initializeLayout(nodes, currentPositions, adjacency);
    engine.markChanged(nodes.map((n) => n.id).toList());
    engine.performIncrementalLayout(nodes, adjacency);
    return engine.getAllPositions();
  }

  /// 网格布局（确定性：行宽 = ceil(√n)，间距 240x160）。
  static Map<String, Offset> grid(List<Node> nodes) {
    final ids = nodes.map((n) => n.id).toList();
    final columns = math.max(1, math.sqrt(ids.length).ceil());
    const spacing = Offset(240, 160);
    final result = <String, Offset>{};
    for (var i = 0; i < ids.length; i++) {
      result[ids[i]] = Offset(
        (i % columns) * spacing.dx,
        (i ~/ columns) * spacing.dy,
      );
    }
    return result;
  }

  /// 树状布局（BFS 分层：无入度节点为根；层间 160 垂直间距、
  /// 层内 240 水平间距并居中）。
  static Map<String, Offset> tree(List<Node> nodes, AdjacencyMap adjacency) {
    final ids = nodes.map((n) => n.id).toSet();
    // 入度集合（邻接表指向方）；无入度 = 根候选。
    final hasIncoming = <String>{};
    adjacency.forEach((from, neighbors) {
      hasIncoming.addAll(neighbors);
    });
    final roots = ids.where((id) => !hasIncoming.contains(id)).toList()..sort();
    // 分层 BFS（确定序：邻居排序入队）。
    final queue = Queue<String>();
    final levelOf = <String, int>{};
    final visited = <String>{};
    void seed(String id) {
      if (visited.contains(id)) {
        return;
      }
      queue.add(id);
      levelOf[id] = 0;
      visited.add(id);
    }

    void bfs() {
      while (queue.isNotEmpty) {
        final nodeId = queue.removeFirst();
        final level = levelOf[nodeId]!;
        final neighbors = (adjacency[nodeId] ?? const <String>[]).toList()
          ..sort();
        for (final neighbor in neighbors) {
          if (!visited.contains(neighbor)) {
            visited.add(neighbor);
            levelOf[neighbor] = level + 1;
            queue.add(neighbor);
          }
        }
      }
    }

    for (final root in roots) {
      seed(root);
    }
    bfs();
    // **分量兜底**：BFS 后仍未访问的节点（孤立/环内分量）自为根，
    // 保证全部节点覆盖（无向邻接下无入度集可能为空）。
    final sortedIds = ids.toList()..sort();
    for (final id in sortedIds) {
      if (!visited.contains(id)) {
        seed(id);
        bfs();
      }
    }
    // 层内水平分布（居中）。
    const levelSpacing = 160.0;
    const nodeSpacing = 240.0;
    final byLevel = <int, List<String>>{};
    levelOf.forEach((id, level) {
      byLevel.putIfAbsent(level, () => <String>[]).add(id);
    });
    final result = <String, Offset>{};
    byLevel.forEach((level, idsInLevel) {
      final width = (idsInLevel.length - 1) * nodeSpacing;
      for (var i = 0; i < idsInLevel.length; i++) {
        result[idsInLevel[i]] = Offset(
          -width / 2 + i * nodeSpacing,
          level * levelSpacing,
        );
      }
    });
    return result;
  }
}
