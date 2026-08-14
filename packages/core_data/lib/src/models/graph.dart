/// Graph 契约（02 §1.5）。
library;

import 'node.dart';

/// Graph —— 后端存储的结构面。
///
/// 所有 Node 结构的唯一权威。读侧优化（批量合并、LRU 缓存、
/// 二级索引）归存储实现——QueryBus 的职责由"窗口化物化 + 批量读 +
/// 实现层缓存"承接，不恢复总线抽象（02 §1.5）。
abstract class Graph {
  /// 单点读；不存在返回 null。
  Node? get(String id);

  /// 批量读：物化窗口的读契约（10⁶ 下禁止逐点 N 次随机读）。
  ///
  /// 注：02 §1.5 签名写作 `Node? getMany(...)` 系笔误——
  /// 批量读返回集合；此处按语义落地为 `List<Node>`。
  List<Node> getMany(List<String> ids);

  /// 写入（新增或整体替换；结构变更的唯一权威）。
  void save(Node node);

  /// 删除；不存在为静默 no-op。
  void delete(String id);

  /// 全量遍历（10⁶ 下仅限启动索引/迁移场景，窗口读走 getMany）。
  List<Node> getAll();

  /// 按 metadata 键值查询（二级索引由存储实现保证，02 §2.4）。
  List<Node> getByMetadata(String key, dynamic value);
}
