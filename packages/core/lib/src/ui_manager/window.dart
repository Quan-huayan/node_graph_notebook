/// 窗口化策略（02 §3.3，10⁶ 前提）。
///
/// Hook 数量 ≈ 可视窗口，≠ 节点数。窗口化保证每帧渲染 Hook 数
/// ≤ 视口内 Hook 数 + dirty 集合，与全库规模无关（architecture.md §7）。
///
/// M3 呈现层实现本接口。
library;

import 'package:core_data/core_data.dart';

/// 窗口化管理：物化登记与回收（architecture.md §3 核心类）。
abstract class WindowManager {
  /// 是否已物化（视口物化时序 §5.1 的判据）。
  ///
  /// [kind] 提供时按 kind 感知判定（同一节点可在 sidebar/graph/open
  /// 多容器各有一个 Hook）；省略 = 任意 kind 已物化（向后兼容）。
  bool isMaterialized(String nodeId, {String? kind});

  /// 物化登记：把 [hook] 挂到 [containerHook] 下（§5.1 时序 attach）。
  ///
  /// [kind] 为容器 kind——子 Hook 的 HookContext.kind 追溯链
  /// （02 §3.2：kind 来源 = 容器 Hook；M3 落地回填）。
  /// [containerHook] 为 null = 根容器（启动 §4 第 10 步）。
  void attach(Hook hook, Hook? containerHook, String kind);

  /// 回收非物化 Hook → 静默 no-op（架构 §3 失败行为）。
  void recycle(String hookId);
}
