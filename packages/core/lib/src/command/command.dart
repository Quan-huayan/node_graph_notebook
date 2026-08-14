/// 写通道契约（03 §四）：Command 是纯 DTO，业务逻辑全部在 Handler。
library;

/// Command —— 纯 DTO，无 execute()（00 不变量 4.4-2）。
///
/// T 为命令类型标记（区分同类命令的不同载荷形态）。
abstract class Command<T> {
  /// const 子类化支持（DTO 不可变）。
  const Command();

  /// 命令名（调试 / 日志）。
  String get name;

  /// 载荷（纯数据）。
  Map<String, dynamic> get payload;
}

/// 增量粒度（02 §3.4 三层）——WriteResult 的载荷，决定失效后的动作：
/// structure → 树重挂；data → 重绘；ui → 外观直写。
enum ChangeKind {
  /// 结构变更：树重挂（受影响 Hook 子树）。
  structure,

  /// 数据变更：重绘（dirty Hook）。
  data,

  /// 外观变更：UIStateStore 直写。
  ui,
}

/// 写命令的 Handler 返回 WriteResult（03 §四）：
///
/// - [affectedNodeIds] → 写后通知路由（UI 管理器失效广播）
/// - [changeKind] → 增量粒度（树重挂 / 重绘 / 外观）
/// - [inverse] → 对偶命令（撤销契约：Handler 必须声明对偶命令
///   或显式声明不可撤销——任何"撤销没反应"的写操作都是设计缺陷）
abstract class WriteResult {
  /// 受影响 Node 集合（失效广播路由）。
  Set<String> get affectedNodeIds;

  /// 增量粒度。
  ChangeKind get changeKind;

  /// 对偶命令；null = 不可撤销（实现层 UndoMiddleware 维护逆命令栈）。
  Command? get inverse;
}

/// 写命令处理器（写操作的唯一执行者，01-D）：
///
/// 1. 业务逻辑（改 Graph / 改 UIStateStore）
/// 2. 环校验（落盘前，00 §2.3；抛 CycleError）
/// 3. 返回 WriteResult
abstract class CommandHandler<C extends Command, R extends WriteResult> {
  /// 执行命令，返回 WriteResult。
  Future<R> handle(C command);

  /// 命令路由键（实现类声明，如 `=> CreateNodeCommand`）。
  ///
  /// Dart 泛型方法类型参数运行时不可反查，故由 Handler 显式声明
  /// （实现层落地决策，M3 回填）。
  Type get commandType;
}
