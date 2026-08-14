# 03 — 交互与信号

> 前置：[[00-philosophy]]（不变量唯一出处）| [[01-responsibilities]] | [[02-model-presentation]]
> 本文定义交互（拖拽事务、飞行壳层、drop 语义判定）与信号（写：Command→Handler；读：主动/被动）。

---

## 一、拖拽事务

**拖拽 = 前端图结构变更。结果通过写操作表达。**（00 不变量 4.2 三档判据）

四阶段，视觉事务（承旧设计 8.1，修订如下）：

```
Phase 1 Drag Start   开启视觉事务
  - 拖拽影像脱离源 Hook
  - 源 Hook 显示空位占位符
  - 不产生任何 Command（03 档，会话态）

Phase 2 Drag Move    实时预览
  - 影像接近目标容器 → 外壳属性形态渐变（位置/尺寸/圆角/透明度，可插值）
  - 目标容器显示预览位置
  - 内容在 morphProgress > 0.5 时淡入淡出切换（不可插值部分）

Phase 3 Drop         提交事务
  - 目标容器判定语义（§三）→ ①数据命令 / ②UIStateStore 写 / 拒绝
  - 飞行壳层过渡动画（§二）完成后销毁
  - 失败 → Phase 4

Phase 4 Cancel       回滚事务
  - 拖拽影像弹回源位置（动画）
  - 不产生任何 Command，无持久化副作用
```

## 二、飞行壳层（FlightShell）

**问题**：提交瞬间，前端图结构变更导致 Hook 树重建（02 §3.4）——正在过渡的节点所属的树消失了。拖拽影像在提交前活在旧树，提交后要进新树。

**解法**：飞行壳层 = 独立于 Hook 树的过渡渲染层，在全局 overlay 中渲染。

- **前提**：Hook 渲染位置无关（02 §3.1）——能被渲染进任意 RenderContext（含 overlay）。位置无关写死在 Hook 契约里，壳层只是它的推论。
- 提交：`FlightShell` 承接拖拽影像 → 渐变到目标 Hook 的预览位置 → 动画完成销毁
- 失败：`FlightShell` 把影像弹回源位置 → 销毁
- 壳层不接触数据层：不读 metadata、不发命令，纯渲染

## 三、drop 语义判定

**判定者 = 目标容器**（01-C 承诺）。拖拽交互层在 drop 时询问目标容器："接收这个 Node 意味着什么？"

判定规则 = 00 三档判据（00 不变量 4.2）：

| 场景 | 判定 | 通道 |
|---|---|---|
| 侧边栏重排（移动改变"笔记本是什么"） | ① 数据命令 | 改 Graph references（folder 的 children 变更） |
| 画布拖动（纯外观） | ② UIStateStore | `position.graph.<hookId>` 写 |
| 把 A 拖入 A 的后代（撞环） | 拒绝 | drop 预判，Phase 4 回滚 |
| 容器 schema 不兼容（容器 Concept 拒绝该 Node schema） | 拒绝 | drop 预判，Phase 4 回滚 |

**推论**：侧边栏拖拽 = 数据命令 → 改 folder references → 被动读 → 侧边栏、画布所有相关 Hook 重渲染（02 §3.4）。画布拖动 = UIStateStore 写，无数据变更。

---

## 四、写：Command → Handler

```dart
/// Command 是纯 DTO，无 execute()（00 不变量 4.4-2）。
abstract class Command<T> {
  String get name;
  Map<String, dynamic> get payload;
}

/// 写命令的 Handler 返回 WriteResult：
/// affectedNodeIds → 写后通知路由（UI 管理器失效广播）
/// changeKind → 增量粒度（02 §3.4 三层：structure 树重挂 / data 重绘 / ui 外观）
/// inverse → 对偶命令（撤销契约，见下）
abstract class WriteResult {
  Set<String> get affectedNodeIds;
  ChangeKind get changeKind;
  Command? get inverse;   // null = 不可撤销（实现层 UndoMiddleware 维护逆命令栈）
}

abstract class CommandHandler<C extends Command, R extends WriteResult> {
  Future<R> handle(C command);
}

/// 写后通知器：CommandBus 完成写命令后，把 WriteResult 交给注册的通知器。
/// 单播桥（UI 管理器）+ 插件观察订阅——不是 EventBus：
/// 无事件对象、无优先级、无广播语义，只有"写完成"这一个信号。
abstract class WriteNotifier {
  void attach(void Function(WriteResult) listener);
  void detach(void Function(WriteResult) listener);
}

abstract class CommandBus {
  void register<C extends Command, R extends WriteResult>(CommandHandler<C, R> handler);
  Future<R> dispatch<C extends Command, R>(C command);
}
```

**Handler 的职责**（写操作的唯一执行者，01-D）：

1. 业务逻辑（改 Graph / 改 UIStateStore）
2. **环校验**（落盘前，受影响子图增量 acyclicity，00 §2.3；抛 `CycleError` + 用户可读文案）
3. 返回 WriteResult（affectedNodeIds + changeKind + 可撤销性）

**Hook 不直接写**（00 不变量 4.4-1）。用户交互 → Hook 发出意图 → CommandBus → Handler → WriteResult → WriteNotifier → UI 管理器失效路由。

**撤销契约（产品级需求，不是实现细节）**：写命令 Handler 必须声明 `inverse`（对偶命令）或显式声明不可撤销。实现层的 UndoMiddleware 维护逆命令栈（栈上限实现层定），撤销 = 出栈并 dispatch 对偶命令。**任何"撤销没反应"的写操作都是设计缺陷。**

**长任务契约**：布局重算、AI 分析等是长任务 Handler——不得阻塞 UI 线程（执行位置归实现层：后台 isolate / 分帧），完成结果通过写路径落盘（自然触发写后通知）。长任务不引入新机制，复用写路径。

**中间件**：日志、事务等可在实现层以管道附加（04 资产盘点已带走实现），但**撤销的契约在抽象层**（inverse），中间件只是执行者。

---

## 五、读：主动读与被动读

### 5.1 主动读

Hook 需要数据时，直接读自己 Node.metadata——同步、直接，不经过总线（02 §3.1 边界 ✅）。

### 5.2 被动读

```
Handler 修改 Node 数据
  → CommandBus 完成 → WriteNotifier 交给 UI 管理器
  → UI 管理器路由（nodeId → hookId 索引，只达已物化 Hook）
  → Concept 反应（重读自己 Node.metadata → 重渲染）
```

- **路由 = UI 管理器**（02 §3.5）：索引、广播、物化协调
- **反应 = Concept**：通知后重读 → 重渲染，由 Concept 决定具体反应（重绘/子树重挂/忽略）
- 通知按 nodeId 路由，不整树广播；未物化 Hook 无反应成本（02 §3.4）
- **载荷 = WriteResult**：affectedNodeIds + changeKind 决定增量粒度（02 §3.4 三层）
- **插件观察契约**：插件可订阅 WriteNotifier（如 AI 插件响应节点变化），但订阅必须实现 `Disposable` 并在 onUnload 关闭——**硬规则，代码审查强制执行**（Plugon 的 disposeOwner 不管理订阅）

---

## 六、职责回填（01 执法规则 1）

新增概念：`FlightShell`（独立过渡渲染层，位置无关渲染的推论）、`CycleError`（环校验失败异常）、`WriteResult` / `WriteNotifier`（写后通知契约，替代旧 EventBus 的"命令自动发事件"）、撤销契约（inverse 对偶命令）、长任务契约（复用写路径）。**修正记录**：旧 bus 体系（EventBus/QueryBus/EventSubscriptionManager/执行引擎）删除后，职责承接者全部补齐——通知载荷、订阅清理、批量读、撤销、长任务。无 F 区遗留变更。
