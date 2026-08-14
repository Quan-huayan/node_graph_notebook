/// Hook 系统契约（02 §3）：Hook / RenderContext / HookContext。
library;

/// Hook —— Node 的视图面（00 §6）。
///
/// 位置无关渲染：可被渲染进任意 RenderContext——包括全局 overlay。
/// 这是飞行壳层（03 §二）成立的前提。
///
/// 边界（00 不变量 4.3-5 / 4.4）：
/// - ✅ 主动读：读自己 Node.metadata
/// - ✅ 渲染自身（位置无关）
/// - ✅ 通过 references 组织子 Hook
/// - ❌ 读其他 Node 的 metadata
/// - ❌ 创建/修改/删除 Node（写一律走 Command → Handler）
/// - ❌ references 含 Node
abstract class Hook {
  /// const 子类化支持。
  const Hook();

  /// 所呈现 Node 的逻辑身份。
  String get nodeId;

  /// 物化实例身份（同一 Node 可有多个 Hook）。
  String get hookId;

  /// 只含 Hook，不含 Node。Hook.references 即 UI 树结构
  /// （00 删除清单：UIHookNode 替代）。
  Map<String, Hook> get references;

  /// 渲染自身。位置无关：可被渲染进任意 RenderContext。
  void render(RenderContext context);

  /// 失效反应（02 §3.4）：Concept 重读自己 Node.metadata → 重渲染。
  ///
  /// 由 UI 管理器失效广播调用（只达已物化 Hook）。默认 no-op，
  /// 实现方覆写（重读 metadata 后 markDirty）。
  void reloadMetadata() {}

  /// 重绘标记：渲染循环只重绘 dirty Hook（架构 §7 帧预算）。
  bool get dirty => false;

  /// 标记为需要重绘（下一帧渲染循环消费）。
  void markDirty() {}
}

/// 位置无关渲染上下文（02 §3.1）。
abstract class RenderContext {
  /// 为子 Hook 创建子渲染上下文（Hook Tree 递归遍历）。
  RenderContext createChildContext(Hook childHook);
}

/// Hook 创建上下文：呈现形态由 context.kind 决定（01-B）。
///
/// kind 来源：容器 Hook（02 §3.2 信息通道，容器→覆盖层）。
class HookContext {
  /// 创建上下文：容器 kind 决定子 Hook 的呈现形态。
  const HookContext({required this.kind});

  /// 容器 kind——决定子 Hook 的呈现形态与 drop 语义判定（00 §6 容器）。
  final String kind;
}
