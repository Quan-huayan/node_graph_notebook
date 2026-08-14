/// 命令失败契约（03 §四 + architecture.md §8：异常 → 用户反馈映射）。
library;

/// 环校验命中（00 §2.3）：Node 引用图中不得存在环。
///
/// Handler 落盘前抛出；用户文案："此操作会形成循环引用，已阻止"。
class CycleError implements Exception {
  /// 携带环路径（nodeId 序列，首尾同节点）。
  const CycleError(this.cyclePath);

  /// 环路径（nodeId 序列，首尾同节点）。
  final List<String> cyclePath;

  @override
  String toString() =>
      'CycleError: 此操作会形成循环引用，已阻止 '
      '(${cyclePath.join(' → ')})';
}

/// 容器拒绝该 Node schema（architecture.md §8，drop 预判与 Handler
/// 双重校验）。用户文案："此容器无法容纳这种节点"。
class SchemaRejectedError implements Exception {
  /// 携带拒绝方与被拒 Node。
  const SchemaRejectedError(this.containerConceptId, this.nodeId);

  /// 拒绝方 Concept id。
  final String containerConceptId;

  /// 被拒 Node id。
  final String nodeId;

  @override
  String toString() =>
      'SchemaRejectedError: 容器 $containerConceptId '
      '无法容纳节点 $nodeId';
}
