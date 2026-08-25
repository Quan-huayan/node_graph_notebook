/// HookIndex —— nodeId → hookId 索引（02 §3.4 / 03 §5.2）。
///
/// 失效路由的 O(1) 基础：10⁶ 节点 × 16B ≈ 16MB，全量内存可承受。
/// 一个 Node 可有多个 Hook（不同容器），故值为 Set。
///
/// 增量粒度的第一层：通知按 nodeId 路由，不整树广播；
/// 未物化节点变更 = 无渲染成本（02 §3.4）。
library;

/// nodeId → hookId 索引。
class HookIndex {
  final Map<String, Set<String>> _index = <String, Set<String>>{};

  /// hookId → nodeId 反查（O(1)，降级重物化用）。
  final Map<String, String> _hookToNode = <String, String>{};

  /// 物化登记：nodeId 下挂载一个 hookId。
  ///
  /// 调用方：UI 管理器（物化时，architecture.md §5.1 时序）。
  void materialize(String hookId, String nodeId) {
    _index.putIfAbsent(nodeId, () => <String>{}).add(hookId);
    _hookToNode[hookId] = nodeId;
  }

  /// 节点变更：仅更新索引行，无渲染（architecture.md §3：
  /// 目标未物化 → 仅更新索引行，无渲染）。
  ///
  /// 索引行本身无需变更（结构不变）；此方法保留路由契约——
  /// 真正的广播由 UI 管理器执行（03 §5.2）。
  ///
  /// @Deprecated（audit core #11）：死方法占位——恒 null 且语义与
  /// UIManager.onNodeChanged 重复，仅因历史契约保留；新代码不得调用。
  @Deprecated('死方法占位（audit core #11）；广播走 UIManager.onNodeChanged')
  void onNodeChanged(String nodeId) => null;

  /// 查询 nodeId 的全部物化 hookId。未物化返回空集（不抛）。
  Set<String> lookup(String nodeId) => _index[nodeId] ?? const <String>{};

  /// 是否已有 hookId 挂在该 nodeId 下。
  bool isMaterialized(String nodeId) => _index.containsKey(nodeId);

  /// 重指向：hookId 从 [fromNodeId] 迁移到 [toNodeId]
  /// （降级渲染，architecture.md §5.4）。
  void repoint(String hookId, String fromNodeId, String toNodeId) {
    _index[fromNodeId]?.remove(hookId);
    if (_index[fromNodeId]?.isEmpty ?? false) {
      _index.remove(fromNodeId);
    }
    materialize(hookId, toNodeId);
  }

  /// 回收：移除 hookId 的全部登记（窗口化回收，02 §3.3）。
  ///
  /// 实现 O(1)：经 `_hookToNode` 反查直接定位 nodeId（audit core #5——
  /// 旧实现全表扫描与文件头 O(1) 声明矛盾）；未登记 → 静默 no-op。
  void recycle(String hookId) {
    final nodeId = _hookToNode.remove(hookId);
    if (nodeId == null) {
      return;
    }
    final hookIds = _index[nodeId];
    if (hookIds != null) {
      hookIds.remove(hookId);
      if (hookIds.isEmpty) {
        _index.remove(nodeId);
      }
    }
  }

  /// 全部已登记 hookId（降级渲染遍历，10⁶ 背书：≈ 视口内 Hook 数）。
  Iterable<String> get hookIds => _hookToNode.keys;

  /// hookId → nodeId 反查（O(1)）；未登记返回 null。
  String? nodeIdOf(String hookId) => _hookToNode[hookId];
}
