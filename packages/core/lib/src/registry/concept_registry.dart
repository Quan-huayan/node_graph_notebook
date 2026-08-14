/// ConceptRegistry —— 查询侧接口（04 §1.4）。
///
/// Concept 的**注册/注销归 plugon 扩展点机制**（removeOwner 自动清理）；
/// 本接口定义查询侧契约：全序匹配优先序 + 兜底（00 不变量 4.3）。
///
/// M5 重构：由具体类升格为接口——StaticConceptRegistry（注入列表）
/// 与 PluginConceptRegistry（扩展点实时派生）两实现可互换，
/// UI 管理器/物化器/拖拽控制器依赖本接口。
library;

import 'package:core_data/core_data.dart';

/// Concept 匹配查询器接口。
///
/// 匹配优先序（02 §1.3）：
/// 1. 对全部已注册 Concept 执行 validate()
/// 2. 命中多个 → 按特异性排序（required 约束多者胜）
/// 3. 平局 → 注册序（先注册者胜）
/// 4. 无命中 → 兜底 Concept（永不空洞，永不崩溃）
abstract class ConceptRegistry {
  /// 无命中 → 兜底（永不 null、永不抛；架构 §3 失败行为）。
  Concept findFor(Node node);

  /// 返回 metadataSchema 声明了 [key] 的 Concept（注册序）。
  List<Concept> findByMetadata(String key, dynamic value);

  /// 兜底 Concept（供 UI 管理器降级渲染查询）。
  Concept get fallback;
}
