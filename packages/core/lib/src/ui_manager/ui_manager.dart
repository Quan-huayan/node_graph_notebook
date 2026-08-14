/// UIManager —— 物化协调 + 失效路由（02 §3.5：路由 = UI 管理器）。
///
/// 职责（01-B 呈现域）：
/// - Node → Hook 物化时机（视口/容器驱动）
/// - nodeId → hookId 索引（HookIndex）
/// - 失效路由：只达已物化 Hook（InvalidationRouter）
/// - 渲染递归调度（Hook Tree 遍历）
///
/// 机制在 core（零 Flutter）；Flutter 壳在 appframe（04 §三 约束 2）。
/// M3 呈现层实现本接口。
library;

import 'package:core_data/core_data.dart';

import '../command/command.dart';
import 'value_rect.dart';

/// 失效事件（M7.1：呈现层订阅——widget 树据此定向重建）。
///
/// 机制层零 Flutter：纯回调（对齐 WriteNotifier.attach/detach 既有模式）。
/// 事件带 nodeIds（不做物化过滤——呈现层自行按 nodeId 过滤，便宜且
/// 语义完整）；ui 变更不发事件（外观直写，无数据失效）。
class InvalidationEvent {
  /// 失效事件。
  const InvalidationEvent({required this.changeKind, required this.nodeIds});

  /// 增量粒度：structure = 树重挂；data = 重绘。
  final ChangeKind changeKind;

  /// 受影响节点集合（呈现层按自身 nodeId 过滤）。
  final Set<String> nodeIds;
}

/// 失效事件监听（attach/detach 生命周期由呈现层管理）。
typedef InvalidationListener = void Function(InvalidationEvent event);

/// UI 管理器契约。
abstract class UIManager {
  /// 视口变化 → 窗口化物化（architecture.md §5.1 时序）。
  void onViewportChanged(ValueRect viewport);

  /// 数据变更（写后通知，architecture.md §5.2）：
  /// hookIds = HookIndex.lookup(nodeId) → 只通知已物化 Hook。
  void onNodeChanged(Set<String> nodeIds);

  /// Concept 集合变化（插件禁用/卸载，§5.4）：
  /// 受影响 Node 重新 findFor → 兜底或重物化。
  void onConceptsChanged();

  /// 写后通知入口（带增量粒度，02 §3.4 三层；M3 回填）：
  /// structure → 树重挂；data → 重绘；ui → 外观直写。
  void onWriteResult(WriteResult result);

  /// 物化 Hook 查询（M7.1，呈现层渲染宿主）：
  /// (nodeId, kind) → 已物化实例；未物化返回 null。
  ///
  /// **kind 感知**：同一节点可多容器多 Hook（sidebar 行 + graph 卡片 +
  /// open 对话框），用 WindowManager.kindOf 区分，不依赖 hookId 字符串。
  Hook? hookFor(String nodeId, String kind);

  /// 按需物化（M7.1，widget 驱动）：hookFor 为空才物化（递归子树）。
  ///
  /// 容器为 null（widget 驱动物化不追踪树形——window 簿记够用；
  /// onConceptsChanged 恢复时以 null 容器重物化，M3 已知简化）。
  Hook? materializeIfAbsent(String nodeId, String kind);

  /// 回收 hookId（M7.1，窗口化：离开视口/容器关闭时）。
  ///
  /// 回收非物化 Hook → 静默 no-op（架构 §3 失败行为）。
  void recycle(String hookId);

  /// 失效事件订阅（呈现层定向重建）。
  void addListener(InvalidationListener listener);

  /// 取消失效事件订阅。
  void removeListener(InvalidationListener listener);
}
