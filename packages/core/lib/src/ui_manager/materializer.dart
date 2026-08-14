/// 物化策略（02 §3.3 / 01-B"Node → Hook 物化时机 | UI 管理器"）。
///
/// 物化：UI 管理器按视口/容器驱动，按需实例化。Hook 数量 ≈ 可视窗口，
/// ≠ 节点数——10⁶ 节点不可能物化 10⁶ 个 Hook。物化时读到的是新数据，
/// 多数陈旧状态根本不会发生（00 §4.4-4 的推论）。
///
/// M3 呈现层实现本接口（Flutter 物化器在 appframe，见 04 §三）。
library;

import 'package:core_data/core_data.dart';

/// 物化策略：nodeId → Hook 的按需实例化。
abstract class Materializer {
  /// 为 [nodeId] 在 [containerHook] 下物化 Hook（呈现形态由
  /// ConceptRegistry.findFor + context.kind 决定）。
  ///
  /// [kind] 为容器 kind（M3 落地回填：子 Hook 的 HookContext.kind
  /// 追溯链由物化调用方维护）。[containerHook] 为 null = 根容器。
  Hook? materialize(String nodeId, Hook? containerHook, String kind);

  /// 回收 hookId 对应的 Hook（离开视口/容器关闭时）。
  void recycle(String hookId);
}
