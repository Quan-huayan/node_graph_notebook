/// 失效路由契约（02 §3.5 / 03 §5.2）。
///
/// 路由 = UI 管理器（索引、广播、物化协调）；反应 = Concept
/// （收到通知后重读 metadata → 重渲染）。
///
/// 本接口是 UIManager 在失效领域的契约面——M3 呈现层实现。
/// 载荷 = WriteResult（affectedNodeIds + changeKind 决定增量粒度）。
library;

/// 失效路由：nodeId 变更 → 只达已物化的 Hook。
abstract class InvalidationRouter {
  /// 数据变更（Handler 写 Graph / UIStateStore 完成后，经 WriteNotifier
  /// 转交）。按 nodeId 路由，不整树广播；未物化 Hook 无反应成本。
  void onNodeChanged(Set<String> nodeIds);

  /// Concept 集合变化（插件禁用/卸载，architecture.md §5.4）：
  /// 受影响 Node 的 findFor 重算 → 兜底或重物化。
  void onConceptsChanged();
}
