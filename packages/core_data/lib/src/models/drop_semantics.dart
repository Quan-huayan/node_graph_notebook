/// DropSemantics —— drop 语义判定结果（03 §三 / 01-C）。
///
/// 判定者 = 目标容器（容器 Concept 的 askDropSemantics）。
/// 三档判据（00 不变量 4.2）：
/// - [DataMove]：① 数据命令（改 Graph references）
/// - [UIMove]：② UIStateStore 写（纯外观）
/// - [RejectDrop]：拒绝（drop 预判，Phase 4 回滚）
library;

/// drop 语义判定结果（sealed：判定者只能返回三选一）。
sealed class DropSemantics {
  const DropSemantics();
}

/// ① 数据命令：接收 = 改 Graph references。
class DataMove extends DropSemantics {
  /// 落盘前由容器语义推导的新引用边（from → to）。
  const DataMove(this.newReferences);

  /// 新引用边（slot → targetId），写命令载荷。
  final Map<String, String> newReferences;
}

/// ② UIStateStore 写：接收 = 外观状态直写（画布拖动等）。
class UIMove extends DropSemantics {
  /// 外观直写（键 + 值）。
  const UIMove(this.key, this.value);

  /// 键带容器上下文（02 §2.3 键方案）。
  final String key;

  /// 外观值。
  final dynamic value;
}

/// 拒绝（撞环预判 / 容器 schema 不兼容）。
class RejectDrop extends DropSemantics {
  /// 携带拒绝原因。
  const RejectDrop(this.reason);

  /// 拒绝原因（用户可读文案）。
  final String reason;
}
