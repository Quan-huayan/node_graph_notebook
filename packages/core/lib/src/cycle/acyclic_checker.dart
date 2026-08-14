/// 环校验（00 §2.3 / 02 §1.4）：Node 引用图中不得存在环
/// （沿 references 可达自身）。
///
/// 执行点：写命令的 Handler，落盘前对受影响子图做增量 acyclicity 检查。
/// 失败表现：命令拒绝，抛 CycleError（用户文案："此操作会形成循环引用，已阻止"）。
library;

import 'package:core_data/core_data.dart';

/// 增量环校验器。
///
/// 只检查受影响区域：新引用边 + 其可达闭包内做 DFS 找回边，
/// O(受影响区域)（02 §1.4）。
class AcyclicChecker {
  /// 无状态检查器（可全局共享）。
  const AcyclicChecker();

  /// 检查 [affectedRefs]（新引用边集合，from → targets）加入 [graph]
  /// 后是否形成环。
  ///
  /// M3 落地修正：单节点可同时变更多条引用边（重排场景），
  /// 故值为 Set（M1 的 `Map<String,String>` 无法表达）。
  /// 返回环路径（nodeId 序列，首尾同节点）；无环返回 null。
  List<String>? check({
    required Map<String, Set<String>> affectedRefs,
    required Graph graph,
  }) {
    for (final entry in affectedRefs.entries) {
      final from = entry.key;
      for (final to in entry.value) {
        if (from == to) {
          // 自引用 = 最直接的环。
          return <String>[from, from];
        }
        // 若 to 沿 references（含新边）可达 from，则 from→to→…→from 成环。
        final path = _findPathTo(
          from: to,
          target: from,
          graph: graph,
          newRefs: affectedRefs,
        );
        if (path != null) {
          return <String>[from, ...path];
        }
      }
    }
    return null;
  }

  /// 从 [from] 出发沿 references 走，寻找到达 [target] 的路径。
  ///
  /// 遍历时同时考虑 [newRefs]（本次新增边）。返回路径（不含 [from]，
  /// 含 [target]）；不可达返回 null。
  List<String>? _findPathTo({
    required String from,
    required String target,
    required Graph graph,
    required Map<String, Set<String>> newRefs,
  }) {
    // DFS 显式栈，返回路径；visited 防重复扩展。
    final stack = <String>[from];
    final path = <String>[from];
    final visited = <String>{from};
    while (stack.isNotEmpty) {
      final current = stack.last;
      if (current == target) {
        return List<String>.of(path);
      }
      final next = _nextTarget(
        current,
        graph: graph,
        newRefs: newRefs,
        visited: visited,
      );
      if (next == null) {
        stack.removeLast();
        path.removeLast();
      } else {
        stack.add(next);
        path.add(next);
        visited.add(next);
      }
    }
    return null;
  }

  /// 当前节点未访问过的下一个引用目标；无则 null。
  String? _nextTarget(
    String nodeId, {
    required Graph graph,
    required Map<String, Set<String>> newRefs,
    required Set<String> visited,
  }) {
    // 新边优先（本次变更），再走已落盘结构。
    final newTargets = newRefs[nodeId];
    if (newTargets != null) {
      for (final target in newTargets) {
        if (!visited.contains(target)) {
          return target;
        }
      }
    }
    final node = graph.get(nodeId);
    if (node == null) {
      return null;
    }
    for (final target in node.references.values) {
      if (!visited.contains(target)) {
        return target;
      }
    }
    return null;
  }
}
