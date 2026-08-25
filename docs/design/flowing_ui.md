# Flowing UI 设计 v2（改进方案）

> 版本：v2.0（2026-08-15）
> 状态：设计文档；替代 2026-05 的《Flowing UI 设计》旧稿。
> 前置：`docs/rewrite/00-philosophy.md`（不变量唯一出处）、`02-model-presentation.md`、`03-interaction-signals.md`、`04-glue-engineering.md`、`architecture.md`。
> 本文只定义 Flowing UI 的改进设计；00 中的不变量不在此重复定义。

---

## 0. 摘要

**Flowing UI = 保持 Node 身份不变的"解释切换"：同一个 Node 在不同容器/kind 下被重新解释；流动就是这些解释之间的连续过渡。** 它不是一个独立 UI 框架，而是 rewrite 架构之上的一条交互/渲染纪律。v2 相对旧稿最重要的思想修正：**知识是图，但 UI 不是图——UI 是知识图在解释空间中的投影；"流动"不是节点搬家，而是换一种解释。**

- **Node 是身份**：笔记、关系（contain/connect/chat）、工具栏按钮、AI 面板、设置条目、搜索面板都是 Node；流动全程 id 不变、不复制。
- **Hook 是解释**：Sidebar/Graph/Toolbar 都是容器 Node 的 Hook；同一个 Node 在不同 kind 下渲染为不同形态。
- **容器是问题**：容器问"你在这里意味着什么"，`Concept.askDropSemantics` 回答；实际坐标/预览/失败反馈由容器视图提供。
- **Flow 是过渡**：拖拽只是 Flow 的一种输入方式；打开、搜索、AI、撤销同样是身份在解释间过渡。拖拽事务四阶段（开始 → 预览 → 提交/回滚）统一由 `DragController` 管理，飞行影像统一由 `FlightShell` 承载。

本版相对旧稿的关键修订：

1. 烧掉旧概念：`NodeTemplate`、`NodeAttachment`、`UIHookNode`、`Role`/`Act`、`RelationshipNode`、统一约束求解器（00 删除清单已裁决）。
2. 以 `Concept + HookContext.kind` 取代 Role/Act：形态由容器 kind 决定，不再引入可组合角色系统。
3. 以三档判据取代"所有拖拽都是 MoveNodeCommand"：同一手势按目标语义走数据命令、UIStateStore 直写或拒绝。
4. 补上统一事务：`DragController`/`FlightShell` 升级为宿主级共享服务，所有拖拽源/目标走同一条提交路径；消灭 FolderView 手动 fly/bounce 的双影像竞态与 Canvas/Toolbar 绕过事务的问题。
5. 明确坐标与语义分离：`askDropSemantics` 保持薄（Lua 可实现），坐标落点由交互层的 `UIMovePlacement` 提供。
6. 明确布局边界：v2 不实现通用约束求解器；画布用"UIStateStore 位置 + 布局命令 + CustomPaint 覆盖层"，侧边栏用 Flutter 原生树布局。
7. 把形态渐变、多容器窗口化、失败反馈/撤销补齐列为 P0/P1 实施项。
8. 用四个实测症状（AI Tab 拖不出、拖不进 AI Tab、一个 AI 一个 Tab、画布删卡误删工具栏按钮）确立解释生命周期纪律 R1-R4：每个 Expose 必须有 Unexpose；投影 drop 必须委托 pointsTo；身份删除与解释移除分离；Tab 按角色聚合。

---

## 0.1 思想本身的改进：从"布局是图"到"解释连续过渡"

旧思想的原话是"UI 布局本身就是一个图结构"。这个表述有三个副作用：

1. **它把知识图和 UI 图混为一谈。** 图在数据层（Node + references）；UI 是投影，多数时候表现为树或容器树。把布局强行说成图，是旧稿 Role/Act、`ui-contain` 等复杂机制的来源。
2. **它把"流动"绑定在拖拽上。** 打开节点、搜索命中、AI 改写关系、撤销重做，都是同一个 Node 换了一种被解释的方式；拖拽只是最直观的一种触发器。
3. **它把 Node 当成被搬运的物体。** "节点在 Hook 间流动"暗示唯一位置和物理移动，但 Flowing UI 真正的价值是：同一身份可以同时存在于多个解释中，也可以只改变解释而不改变身份。

v2 的思想内核改为：

```
知识是图，但 UI 不是图。
UI 是知识图在解释空间中的投影。
Flowing UI = 同一身份在不同解释之间连续过渡。

Node     = 身份（id 不变，数据是它的事实）
Hook     = 解释（在某个容器/kind 下，这个 Node 被呈现成什么）
Container= 问题（"你在这里意味着什么？"）
Flow     = 换一种解释，而不是复制或搬运节点
```

**流动三定律**（本文件新增，作为 Flowing UI 思想的收敛点）：

- **L1 身份守恒**：Flow 的输入输出是同一个 `nodeId`；不复制数据、不重建身份。形态可变，身份不可变。
- **L2 解释有主**：每个解释的 owner 是 `Concept × HookContext.kind`；容器负责提问（drop/布局语义），Concept 负责回答（schema/验证/createHook）。来源 Node 可以"提议"，但不能自封解释。
- **L3 过渡可逆**：每个 Flow 必须有明确的前解释与后解释；拒绝/失败回前解释（回弹），成功进入后解释（飞行）。语义上若不可逆，必须显式声明（`inverse == null`），不得默认不可撤销。

这三条不是替换 00 不变量，而是把 00 的投影不变式、三档判据、撤销契约翻译成 Flowing UI 的语言。后续协议都从这三条推导。

---

## 1. 为什么修订旧稿

旧稿（2026-05）有三个与现行架构不再兼容的假设：

| 旧稿假设 | 现行架构裁决 | 后果 |
|---|---|---|
| UI 布局是任意图结构，边由 `RelationshipNode` 承载 | 后端图 = Node references；前端 = Hook 投影树；`contain`/`connect`/`chat` 都是 L1 Node | 旧 `ui-contain`/`source`/`target` 关系枚举作废 |
| `NodeTemplate` + 可组合 `Role`/`Act` 驱动渲染 | `Concept`（代码层 schema）+ `HookContext.kind` 驱动渲染 | 旧角色匹配、act 组合规则作废 |
| 统一约束求解布局协议 | 画布位置 = UIStateStore；布局 = 显式算法命令；侧边栏 = Flutter 布局 | 约束求解降级为非目标 |
| `NodeAttachment`/`UIHookNode`/`CoordinateSystem` 基础设施 | `HookIndex`/`WindowManager`/`UIManager` + Flutter 坐标变换 | 旧核心类已被删除清单烧掉 |

保留的 Flowing UI 内核不变：

- Node 即身份、Hook 即解释、容器即问题、Flow 即过渡（流动三定律见 §0.1）。
- 拖拽是视觉事务，不是瞬时 CRUD。
- 提交瞬间 Hook 树可能重建，过渡影像必须活在独立 overlay 层。
- 同一个数据实体在不同容器中变形，全程无数据副本。

---

## 2. 现状基线（代码事实）

以下均已落地，是本设计的起点：

| 能力 | 实现 | 位置 |
|---|---|---|
| Node/Concept/Graph 模型 | 统一 Node，Concept 结构匹配，L1 关系实例 | `packages/core_data/lib/src/models/` |
| Hook 契约（位置无关） | `Hook.render(RenderContext)`，HookContext.kind 决定形态 | `packages/core_data/lib/src/models/hook.dart` |
| drop 语义三选一 | `DataMove` / `UIMove` / `RejectDrop` | `packages/core_data/lib/src/models/drop_semantics.dart` |
| 容器语义推导 | `Concept.childNodeIdsOf`（folder contain 反查等） | `packages/core_data/lib/src/models/concept.dart` |
| 物化/窗口化/失效 | `WindowedUIManager`、`HookIndex`、`WindowManagerImpl` | `packages/core/lib/src/ui_manager/` |
| Flutter 渲染目标 | `FlutterRenderContext`（sink + host + onDragStart） | `packages/appframe/lib/src/render/flutter_render_context.dart` |
| Hook 渲染宿主 | `HookView`（hookFor → materializeIfAbsent → render） | `packages/appframe/lib/src/ui/hook_view.dart` |
| 拖拽事务 | `DragController` 四阶段 + `DropOutcome` | `packages/appframe/lib/src/interaction/drag_controller.dart` |
| 飞行壳层 | `FlightShell`（present/fly/bounce/abort，OverlayEntry 自清理） | `packages/appframe/lib/src/interaction/flight_shell.dart` |
| 宿主共享事务 | `HostRuntime` 已注册 `dragController`/`flightShell` 单例 | `packages/appframe/lib/src/host/host_runtime.dart` |
| 三向拖拽 | 侧边栏/画布/工具栏/搜索结果 | `packages/node_folder`、`packages/node_graph`、`packages/appframe`、`packages/node_search` |
| 语义分发 | 语义服务家族：`SidebarDropSemantics` / `ToolbarDropSemantics` / `CanvasCardDropSemantics`（宿主缺省 null + 插件 last-wins；M8 移除组合根回调） | `appframe`（drag_controller.dart）+ 插件（node_ai 等） |

**当前成熟度**：机制层完整，交互层 70%——"能拖"已成立，但事务/视觉/失败反馈在四类目标上不统一（见 §6 差距审计）。

---

## 3. 概念模型

### 3.1 一个身份，多种解释

```
后端图 G = (Node, references)
    Node：笔记 / folder / canvas / ai / toolbar / contain / connect / chat …
    references：有序 slot → targetId；边本身也是 Node（L1 及以上）

前端投影 H = F(G, ConceptRegistry, UIStateStore)
    Hook = Node 在 kind 容器下的视图面（解释）
    容器 kind：sidebar-root / sidebar / graph / open / toolbar-root /
              toolbar / sidebar-panel / settings …
```

- **后端图是权威**：结构只存 Graph；画布位置/相机等外观只存 UIStateStore。
- **前端图是投影**：永远不持久化 Hook 树；每次从 G + 匹配 + 容器语义推导。
- **一个 Node 可以同时有多个 Hook**：同一笔记可同时是侧边栏行（`kind='sidebar'`）、画布卡片体（`kind='graph'`）、打开对话框中的编辑器（`kind='open'`）。

### 3.2 形态由 kind 决定，不由 Node 决定

旧稿的 Role/Act 被 `HookContext.kind` 取代：

| 旧稿 | v2 |
|---|---|
| 文件夹在 Sidebar 扮演 `list-item` | `FolderHook.render(context.kind == 'sidebar')` 渲染 `FolderView` |
| 文件夹在 Graph 扮演 `graph-node` | `FolderHook.render(context.kind == 'graph')` 渲染 `FolderCardView` |
| 容器角色 | 容器语义 = `Concept.askDropSemantics` + `childNodeIdsOf` |
| act 组合规则 | 不做通用组合；需要新形态 = Concept 的 Hook 增加一个 kind 分支 |

**纪律**：kind 是容器上下文，不写入 Node.metadata（它是前端投影的一部分）；新增 kind 必须先在本文件或 02/03 文档中登记语义。

### 3.3 流动 = 目标容器重新解释 Node

同一个 drop 手势，语义由目标容器决定（00 三档判据）：

| 目标 | 语义 | 通道 |
|---|---|---|
| folder / 侧边栏根 | "成为列表项/子项" | ① `MoveNodesCommand` / `SidebarDropSemantics` 覆盖 |
| canvas 空白 | "成为图节点" | ② `position.graph.<nodeId>` 直写 |
| canvas 卡片附近 | "建立连接" | ① `ConnectNodesCommand`（宿主先做 AI 等语义分发） |
| AI 节点 | "变成一段对话的素材" | ① `DropIntoAICommand` |
| 工具栏 | "变成按钮" | ① `CreateToolbarButtonCommand` |
| 侧边栏根 + AI 节点 | "钉成 AI 面板" | ① `CreateAIPanelCommand` |
| 撞环 / schema 不兼容 / 自身 | 拒绝 | `CycleError` / `RejectDrop`，Phase 4 回弹 |

### 3.3.1 解释状态上的三对生成元（修订：初版“四动作表”作废）

> **设计自检**：本文件上一版把 `Reparent / Bind / Project / Expose` 平级列为生成元，这是有问题的。其一，`Reparent` 只是 `Bind` 在 parent 槽上的特化，不是独立生成元；其二，五个动作只有正向、没有同级的逆向，数学上不是一个封闭的动作集。四个实测症状（AI Tab 拖不出、拖不进、一个 AI 一个 Tab、画布删卡误删工具栏按钮）正是这个不封闭在 UI 上漏出来的。本节修订为：**三对互逆生成元 + 产品宏**；`Reject` 是恒等边界，不算生成元。

先人话：流动状态只涉及三类可变坐标——**关系边、外观键、派生指针**。每一类都必须成对出现：能建立就能撤销，能投影就能取消投影，能具现就能取消具现。产品上说的 Reparent/Bind/Project/Expose 是这些生成元复合出来的宏。

再把语言收紧。记：

```
N  = Node id 集合
R  ⊆ N × Slots × N    三元组 (a, s, b) 表示 a.references[s] == b
A  : N → Data         title / content / metadata（节点自己的事实）
S  : Key ⇀ Value      UIStateStore（部分映射；S[k] = ⊥ 表示无键）
Σ  = (N, R, A, S)     总状态空间

记号：S ⊕ {k ↦ v} 表示只新增/覆盖 k 这一个键、其余键不变的 UIStateStore。
```

一次关于节点 `n` 的 Flow 是 `Σ` 上的参数化部分变换 `(N,R,A,S) → (N',R',A',S')`，且恒满足 **L1 身份守恒**：`n ∈ N ∩ N'`。

**三对互逆生成元**（`op⁻¹` 与 `op` 同级存在）：

| 生成元 | 逆 | 数学定义（参数省略非法边界） | 人话 |
|---|---|---|---|
| **Bind** `PutRel(r,s,t)` | **Unbind** `DropRel(r,s,t)` | `PutRel`：`r` 不存在则先创建关系脚手架节点 `r`，再写/覆盖三元组 `(r,s,t)`；`DropRel`：删除 `(r,s,t)`，若 `r` 不再承载任何三元组则回收 `r`。 | 建立/撤销一条关系边；`n` 自己的事实 `A(n)` 不动。 |
| **Project** `PutView(k,v)` | **Unproject** `DropView(k)` | `PutView`：`S' = S ⊕ {k ↦ v}`，其中 `k ∈ ViewKeys_n = {position.graph.n, style.graph.n}`；`DropView`：`S' = S \ {k}`。 | 给 `n` 写/删一个画布解释键；图完全不动，所以可与其他解释共存。 |
| **Expose** `Expose(b,n)` | **Unexpose** `Unexpose(b)` | `Expose`：取 `b ∉ N`，`N'=N∪{b}`，`A'(b)` 含 `pointsTo(b)=n`，其余不变；`Unexpose`：删除 `b` 及其 `A(b)`，其余不变。 | 创建/移除一个指向 `n` 的派生 UI 节点；`n` 保持原状。 |
| **Reject** | 自身 | `(N',R',A',S')=(N,R,A,S)`。 | 恒等边界，不是生成元；合法状态下不允许"半吊子过渡"。 |

**产品宏**（用户可见动作 = 生成元复合，但必须作为单个事务原子执行）：

| 宏 | 分解 | 逆宏 |
|---|---|---|
| **Reparent**（folder → folder） | 对 contain 实例 `r`（有 `(r,child,n)`）执行 `DropRel(r,parent,p) · PutRel(r,parent,p')`；若 `n` 原无 contain，则为新建 contain 的 `PutRel` 组。 | 另一个 Reparent 回原父 |
| **Bind**（笔记 → AI / 卡片连线） | 对 chat/connect 实例 `r` 执行一组 `PutRel`（如 `{ai: aiNode, source: n}` 或 `{from: a, to: b}`）。 | 删除/恢复该关系实例的逆命令 |
| **Project**（节点 → 画布） | `PutView(position.graph.n, (x,y))`，必要时与 `PutView(style.graph.n, …)` 同事务。 | `DropView(position.graph.n)`（Unproject） |
| **Expose**（笔记 → 工具栏；AI → 侧边栏工作区） | `Expose(b,n)`，`b` 的形态由 `A(b)` 决定。 | `Unexpose(b)` |

当前实现映射：`Reparent → MoveNodesCommand`；`Bind → DropIntoAICommand / ConnectNodesCommand`；`Project → UIMove + position.graph.<id>`；`Expose → CreateToolbarButtonCommand / CreateAIPanelCommand`（AI 面板目标态改为单例 `ai-workspace`，见 F8）；`Reject → CycleError / RejectDrop`。**映射到宏，而不是直接映射到生成元；逆宏必须是同级的命令对偶，而不是借 `DeleteNode` 顶替。**

说明：`pointsTo(b)=n` 是抽象指针——工具栏按钮用 `metadata.target`，AI 面板用 references 归属；为保持本节动作定义最小，统一记为 `A(b)` 的语义字段，不再区分两种物理编码。

共现性表是 Flowing UI 的"交通规则"：Reparent 回答"我现在属于哪里"，Project/Expose 回答"我还被投影到哪里"。同一 Node 同时属于一个 folder、出现在画布、被钉在工具栏，是完全合法且应当被鼓励的状态——这正是"无数据副本"优于传统文件系统的地方。Reparent 是排他宏（一个子节点一个父容器），所以必须原子执行；Project/Expose 是共存宏，因此可以独立增删。

### 3.3.1.1 生成能力：三对生成元在哪个空间上完备？

令 `G = {PutRel, DropRel, PutView, DropView, Expose, Unexpose, Reject}` 的所有合法参数实例构成的集合，`G*` 为复合生成的变换半群。`G` 本身**按对互逆**：每个生成元在合法解释状态上都有同级的局部逆。

**参数域约束**（否则定理 1 不成立）：`PutRel/DropRel` 只允许作用于关系脚手架 `r`，且操作的三元组满足 `a = n ∨ b = n`，或 `r` 已有其他槽指向 `n`（例如 Reparent 时改写 contain 的 parent 槽）；`PutView/DropView` 只允许 `ViewKeys_n`；`Expose/Unexpose` 只允许 `pointsTo(b)=n`。即所有生成元都锚定在 `n` 的解释坐标上。

定义 `n` 的**解释投影**：

```
RelCluster_n(R) = { (a,s,b) ∈ R | a = n ∨ b = n ∨ ∃s₀: (a,s₀,n) ∈ R }
View_n(G,S)     = ( A(n),
                    RelCluster_n(R),
                    S[ViewKeys_n],
                    { b ∈ N | pointsTo(b) = n } 及其 A(b) )
```

**定理 1（边界：不生成全状态空间）**：对任意 `τ ∈ G*`，`τ` 只可能改变 `View_n` 内的坐标；`View_n` 之外的 `N、R、A、S` 全部保持不变。因此 `G*` 不是 `Σ` 上全变换半群的生成元集。

**人话**：这组动作只负责"`n` 被怎么解释"；它们永远不改 `n` 自己的标题/内容/metadata，永远不删 `n` 本身，也永远不写 `camera.*` 之类与 `n` 无关的外观键。改标题、删身份、挪相机属于其他域的命令——这不是缺陷，是职责边界。

**定理 2（完备性：在解释子空间上可传递）**：在固定的节点宇宙和 Concept schema 允许的合法状态范围内，把状态空间限制到 `View_n`。`G*` 在合法 `View_n` 上是**传递的**：任意两个合法解释状态都可由有穷个生成元复合到达（先对旧状态施加相应逆生成元清空不要的坐标，再施加正向生成元构建目标状态）。因此 `G` 是合法 `View_n` 的**完备生成元集**，无需像初版那样事后追加 `Unbind/Unproject/Unexpose`——它们本就该在生成元集合里。

**路径合法性注**：纯生成元意义上的"传递"允许中间脚手架态（例如先清空再重建会短暂出现无父/无投影状态）；产品上要求每步合法的过渡由**命令层宏的原子性**保证——`Reparent` 一个命令完成，不暴露"先摘旧父、尚未挂新父"的中间帧。

**人话**：在"`n` 可以被怎么解释"这个小世界里，三对生成元就能走到任何合法解释状态。产品宏（Reparent/Bind/Project/Expose）负责把若干生成元包成原子事务和可撤销命令；`DeleteNode` 属于身份域，绝不进入解释域来顶替逆生成元。

### 3.3.1.2 四个实测症状：缺失的反向动作如何变成用户可见 bug

以下四个问题在数学上是同一件事：**初版 3.3.1 把用户可见的正向宏当成封闭生成元表，没有把逆向生成元纳入同级动作集；实现缺逆操作后，UI 又拿身份删除（`DeleteNode`）冒充解释移除。** 修订后的三对生成元（§3.3.1）已把逆操作内建，本节四个症状是那次设计错误的现场证据。每个症状都给出"代码事实 → 数学诊断 → 目标设计"。

**症状 1：AI 节点拖到侧边栏后无法拖出。**

- 代码事实：`SidebarDropSemantics` 把"AI 节点 → 侧边栏"解释为 `CreateAIPanelCommand`，落盘一个派生面板节点 `ai-panel-* = {sidebar: root, ai: aiNode}`；`SidebarTabsView` 把它枚举成 Tab，但 `AIPanelView` 没有关闭、拖出或删除入口；`CreateAIPanelResult.inverse` 还是 `null`。AI 节点本身一直是 L0，从未改变。
- 数学诊断：这是只有 `Expose`、没有 `Unexpose`。用户拖不动的不是 `n`，而是 `pointsTo(b)=n` 的派生节点 `b`。
- 目标设计：补 `RemoveAIPanelCommand`（对偶于 `CreateAIPanelCommand`）；Tab 提供关闭/取消固定动作；`SidebarDropSemantics` 只允许 `targetContainerId == 侧边栏根` 时生成面板命令，否则落入默认 folder 语义，禁止生成 `sidebar=folderA` 的幽灵面板。

**症状 2：不能把节点拖到 AI Tab 页构成连接。**

- 代码事实：`DropIntoAICommand` 接在"画布卡片 → 画布 AI 卡片"的 `CanvasCardDropSemantics` 语义服务上（M8：插件 last-wins 覆盖，非组合根回调）；`AIPanelView` 是普通会话列表，没有 `DragTarget`；`AIPanelConcept.askDropSemantics` 又是默认拒绝。
- 数学诊断：Expose 出来的投影没有继承 `pointsTo` 目标的容器语义。Tab 是 AI 节点的一张"脸"，但 drop 判定发生在 Tab（代理）上，而不是背后的身份节点上。
- 目标设计：投影容器规则——**投影可以接收 drop，但语义必须委托**：`AIPanelView` 包 `DragTarget<String>`，drop 后解析 `references.ai`，对真正的 `aiNode` 执行 `DropIntoAICommand`。

**症状 3：一个 AI 节点一个 Tab，很奇怪。**

- 代码事实：面板节点是 `{ai: aiNodeId}` 的 L1 实例；`SidebarTabsView` 又规定"每个 `references.sidebar == root` 的节点 = 一个 Tab"，于是 N 个 AI 节点必然产生 N 个 AI Tab。
- 数学诊断：Tab 建模成了实例而不是角色。文件夹 Tab、搜索 Tab 都是按 `kind` 聚合的角色；AI Tab 却按节点实例分裂。
- 目标设计：侧边栏 AI Tab 改为**单例工作区**：`ai-workspace = {sidebar: root}`（每个侧边栏根至多一个）；`AIPanelView` 内部枚举所有 `kind=='ai'` 节点及其 chat 实例。把 AI 节点拖到侧边栏根 = 确保工作区存在并定位/高亮该 AI，不再生长新 Tab。旧数据中的 `ai-panel-*` 迁移为进入该工作区的列表项（或惰性兼容渲染）。

**症状 4：画布里的按钮删掉，工具栏上的按钮也消失了。**

- 代码事实：`toolbar-*` 是同一个身份节点；它一旦拥有 `position.graph.toolbar-*`，就同时有两个解释——工具栏 Hook 渲染为 IconButton，画布 Hook 渲染为 NodeCard。`NodeCard` 右键"删除"永远执行全局 `DeleteNodeCommand`，于是身份消失，两个解释一起消失。
- 数学诊断：用户想要的是 `Unproject(n)`（删除 `position.graph.n` 和 `style.graph.n`），UI 给的是身份删除。从投影模型看行为"一致"，从交互模型看动作作用域错误。
- 目标设计：画布卡片菜单拆成两级——**从画布移除** = `Unproject`（只删位置/样式键）；**删除节点** = `DeleteNodeCommand`，且文案明确"该节点的所有视图会一起消失"。任何多解释节点都不允许把身份删除作为当前视图的唯一默认删除。

由四个症状得到四条实现纪律：

- **R1 每个 Expose 必须有 Unexpose**：能钉上就能取消固定。
- **R2 投影 drop 必须委托 `pointsTo`**：投影不是新容器，只是身份节点的代理。
- **R3 身份删除与解释移除必须分离**：`DeleteNode` 只属于身份域；`Unbind/Unproject/Unexpose` 属于解释域。
- **R4 Tab 按角色（kind）聚合，不按实例分裂**：实例在 Tab 内部以列表/选择器呈现。

### 3.3.2 Flow 不止拖拽（思想层细化）

拖拽是 Flow 的手动触发器，不是 Flow 本身。以下都应当被当作同一种"解释过渡"来设计：

- **打开**：Node 从容器形态过渡到 `kind='open'` 临时容器。
- **搜索**：Node 从知识图投影到查询结果流；把结果拖回 folder/canvas/toolbar 是再次过渡。
- **AI**：AI 改 references/content 后，写后通知驱动所有相关 Hook 重新解释。
- **撤销/重做**：逆命令使 Node 回到前一种解释，是反向 Flow。
- **Lua/命令/未来的脚本**：任何写路径都在改变解释；不应只有拖拽拥有过渡视觉。

因此 v2 保留 `DragController` 作为手势前端，但不把 Flow 定义在 DragController 里。写路径是权威（00 不变量 4.4），视觉层只是对写路径的解释变化做动画。

### 3.4 Hook Tree 的权威推导规则（修订）

现状中 `Hook.references` 多数实现返回空 Map，真正的子级来自 `Concept.childNodeIdsOf`。v2 明确如下语义，消除旧稿"references 即递归结构"的歧义：

1. **静态子 Hook**：`Hook.references` 只承载编译期可知的固定子 Hook；**返回空 Map 是合法实现**。
2. **动态子级**：容器 Concept 覆写 `childNodeIdsOf(node, graph)`（folder = contain 反查；toolbar-root = ToolbarConcept 扫描；settings = references 反查）。
3. **物化顺序**：`Materializer.materialize` 先按 `childNodeIdsOf` 递归，缺省再按 `references.values` 展开。
4. **widget 侧**：容器视图负责把动态子级渲染为 `HookView`（父 Hook 驱动递归，不代替子 Hook 渲染）。

---

## 4. 改进后的核心协议

### 4.1 统一拖拽事务（P0）

目标：全应用只有一个事务实例，所有拖拽源/目标走同一条提交路径。

```dart
/// appframe：DropRequest —— 一次 drop 的完整上下文。
class DropRequest {
  const DropRequest({
    required this.draggedNodeId,
    required this.targetContainerHook,
    required this.from,          // overlay 全局坐标：影像起点
    required this.to,            // overlay 全局坐标：落点
    required this.flightChild,   // FlightShell 使用的影像
    this.localPoint,             // 目标容器本地坐标（预览/精确定位）
    this.uiMovePlacement,        // UIMove 的精确外观值（见 4.2）
    this.moveCommandFactory,     // 本次 drop 按目标路由的命令工厂
  });

  final String draggedNodeId;
  final Hook targetContainerHook;
  final Offset from;
  final Offset to;
  final Widget flightChild;
  final Offset? localPoint;
  final UIMovePlacement? uiMovePlacement;
  final MoveCommandFactory? moveCommandFactory;
}

/// 交互层把目标本地坐标翻译成 UIMove 外观值。
typedef UIMovePlacement = Map<String, dynamic> Function(Offset localPoint);

/// DragController 目标签名：由 onDrop 的散参改为 DropRequest。
Future<DropOutcome> onDrop(DropRequest request);
```

`DragController` 固定时序（承 `architecture.md` §5.3，补上视觉收尾）：

```
1. 读取 container / dragged；任一不存在 → rollback(request) + Reject
2. concept = ConceptRegistry.findFor(container)
3. semantics = concept.askDropSemantics(dragged)
4. switch semantics:
     DataMove → 环预判 → factory(command) → dispatch
               → FlightShell.present(from→to)
     UIMove  → uiMovePlacement != null
                 ? uiStateStore.set(key, uiMovePlacement(localPoint))
                 : uiStateStore.set(key, semantics.value)
               → FlightShell.present(from→to)
     Reject  → FlightShell.bounce(to→from)
5. 任何出口必须 _resetSession()；CycleError/IO/未知异常都必须
   bounce + 返回可读 DropOutcome（禁止向 async DragTarget 泄漏异常）
```

**调用方纪律**：

- 拖拽源：只做 `Draggable`；在 `onDragStarted` 调 `host.dragController.recordDragStart(global)`，在 `onDragUpdate` 调 `host.dragController.dragMove(global)`；**不得**自建 `DragController` 或 `FlightShell`。
- 拖拽目标：只做 `DragTarget`；在 `onAcceptWithDetails` 构造 `DropRequest` 并调 `host.dragController.onDrop`；**不得**先 `fly` 再按结果 `bounce`（这是双影像竞态根源）。
- `FlightShell` 是宿主单例，旧影像被新影像替换时旧回调因 identity 校验自动失效。

### 4.2 语义与坐标分离（P0）

`Concept.askDropSemantics(Node)` 必须保持薄（Lua 能实现），**不携带屏幕坐标**。坐标由交互层补：

- `DataMove`：命令工厂已按目标容器路由（folder → `MoveNodesCommand`；AI → `DropIntoAICommand`）。
- `UIMove`：`DropRequest.uiMovePlacement` 把目标本地坐标翻译成 UIStateStore 值。`CanvasConcept.askDropSemantics` 继续返回 `UIMove` 占位语义；`GraphCanvas` 提供 `uiMovePlacement`，写真实 `{x, y}`。
- 既不在 Concept 里引入 `Offset`，也不让 canvas 再绕过 `DragController` 自行 `uiStateStore.set`。

这样 Canvas 保留其内聚的相机/世界坐标知识，但事务、失败回弹、会话清理回到壳层。

### 4.3 形态渐变（P1）

旧稿的 morphing 收敛为一个可实施的壳层机制：

```dart
/// 可插值外壳属性（位置/尺寸/圆角/透明度/高程/底色）。
class FlowingAppearance {
  final Offset position;
  final Size size;
  final double cornerRadius;
  final double opacity;
  final double elevation;
  final Color? color;

  static FlowingAppearance lerp(
    FlowingAppearance a, FlowingAppearance b, double t);
}

/// Phase 2 事件：位置 + 候选目标 + 归一化进度。
class DragMoveEvent {
  final String draggedNodeId;
  final Offset globalPosition;
  final String? targetContainerNodeId;
  final double morphProgress;   // clamp(distance / threshold, 0, 1)
}
```

规则：

1. 拖拽源提供 `sourceAppearance(node)`；目标 `DragTarget.onMove` 报告 `targetAppearance(node, localPoint)`。
2. `DragController` 选择最近候选目标，计算 `morphProgress`（默认阈值 96px），通过 `onDragMove` 回调宿主。
3. overlay 影像的外壳在 `source → target` 间 lerp；内部内容不可插值，在 `morphProgress > 0.5` 时交叉淡入淡出。
4. 目标容器在 Phase 2 渲染插入槽（行间隙/网格空位/工具栏按钮位）；源容器渲染占位符（当前 `childWhenDragging` 的 0.4 透明卡升级为轮廓占位）。
5. 失败回弹反向播放同一 lerp，时间 200ms；成功飞入 280ms。
6. `MediaQuery.disableAnimations` 或减少动态效果设置开启时，跳过 morph，只保留 120ms 淡入淡出。

**实施边界**：Phase 2 只做"外壳渐变 + 目标槽 + 源占位"；不实现旧稿任意 Role 形态的通用变形。

### 4.4 容器渲染与覆盖层（P1）

容器渲染协议统一为三阶段，替代旧稿的约束求解渲染流：

```
1. 枚举子级      Concept.childNodeIdsOf(node, graph)
2. 布局子级      Flutter 布局（侧边栏/设置）或 UIStateStore 位置（画布）
3. 覆盖层        container 绘制连接/树线等派生视觉（GraphCanvas CustomPaint）
```

- 画布连接线 = `GraphCanvas` 从 `ConnectionConcept` 实例 + 两端 `position.graph.*` 推导的**容器级派生视觉**，不物化连接 Hook（10⁶ 优化项：连接 Hook 化）。
- 侧边栏树线/缩进 = `FolderView` 的 Flutter 布局，不进入 UIStateStore。
- 通用约束求解器明确 **v2 不做**；未来若需要，以 `LayoutPolicy` 接口插入每个容器，而不是替换现有布局。

### 4.5 多容器窗口化（P1）

现状 `WindowedUIManager` 只有单一 `_rootHook` 和单一 `_rootKind`；画布自己维护可见集。v2 目标：

```dart
class ViewportWindow {
  final String rootNodeId;
  final String kind;         // graph / sidebar / settings …
  final ValueRect rect;
}

// UIManager 目标签名（保持旧 onViewportChanged(ValueRect) 兼容）：
void onViewportChangedFor(ViewportWindow window);
```

1. `WindowManager` 登记多个根容器 Hook；每个根有独立 kind。
2. 画布相机变化推送 `ViewportWindow(canvas, 'graph', rect)`；侧边栏滚动/窗口 resize 推送 `ViewportWindow(root, 'sidebar', rect)`。
3. `QuadTreeViewportQuery` 负责 graph 的成员位置查询；侧边栏用节点顺序 + 可见行估计（或惰性 HookView 列表化）。
4. 离开视口的 Hook 由 `UIManager.recycle` 回收（当前回收只在对话框关闭场景有调用方）；保留 LRU 上限由实现层定。
5. 兼容策略：未登记的窗口仍走当前 `materializeIfAbsent` widget 驱动物化，保证渐进迁移。

### 4.6 反馈、撤销与可访问性（P0/P1）

- **统一反馈**：任何 drop 出口由 `DragController` 返回 `DropOutcome`；目标视图只负责展示 SnackBar。拒绝/失败文案走 `I18nService`，禁止 `debugPrint` 静默（工具栏现状整改）。
- **撤销矩阵**：
  - `MoveNodesCommand`/`ConnectNodesCommand`/`CreateNodeCommand`/`UpdateNodeCommand`/`DeleteNodeCommand` 已有 inverse。
  - `CreateToolbarButtonCommand`（新建按钮）应补 inverse = `DeleteNodeCommand(buttonId)`；已存在按钮仅更新 tooltip 时补 inverse = 原 metadata 更新命令。
  - `CreateAIPanelCommand` 新建面板应补 inverse = `DeleteNodeCommand(panelId)`。
  - `UIMove` 按 00 判据②直写，**不进 CommandBus/撤销栈**；v2 不做外观移动撤销，产品验收不宣称该能力。
- **可访问性**：拖拽不是唯一通道——侧边栏删除/移动、画布右键菜单、工具栏按钮均可不用拖拽完成同一任务；Esc 取消拖拽会话；键盘操作清单见 `docs/COMMAND_LINE_GUIDE.md`（快捷键）与后续 settings 的减少动态效果开关。

---

### 4.7 FlowHint：让所有写路径共享过渡语义（P1）

按 §3.3.2，Flow 不绑定拖拽。机制层的最小改进是给 `WriteResult` 增加一个可选的过渡提示（纯数据，不进 Command 载荷）：

```dart
/// core：解释过渡提示。Presentation 层据此决定是否/如何做过渡视觉。
class FlowHint {
  const FlowHint({
    required this.nodeId,
    this.fromKind,
    this.toKind,
    this.cause = 'command',   // drag / open / search / ai / undo / command …
  });

  final String nodeId;
  final String? fromKind;
  final String? toKind;
  final String cause;
}

abstract class WriteResult {
  Set<String> get affectedNodeIds;
  ChangeKind get changeKind;
  Command? get inverse;
  FlowHint? get flowHint => null;   // 默认无提示，不破坏既有实现
}
```

规则：

- **只有改变解释归属的命令**（MoveNodes/DropIntoAI/CreateAIPanel/CreateToolbarButton 等）返回 `flowHint`；普通标题修改不返回。
- **拖拽路径**：`DragController` 仍负责 overlay 影像（from/to 坐标来自手势）；`flowHint` 只做结果记录与调试。
- **非拖拽路径**（AI、Lua、撤销、未来"移动到…"命令）：无手势坐标时，呈现层在目标容器内做轻量 `AnimatedSwitcher`/尺寸过渡，不强制造一个 overlay。
- `flowHint` 是提示不是机制：UIManager 不依赖它路由，失效路由仍只认 `affectedNodeIds + changeKind`。这保持 L2"写路径是权威，视觉是解释"。

这一条把"Flowing"从 DragController 的私有视觉升级为所有写路径可共享的过渡语义。

---

## 5. 流动矩阵（v2 目标态）

| # | 源 | 目标 | 流动作 | 语义 | 执行 | 备注 |
|---|---|---|---|---|---|---|
| F1 | 侧边栏笔记行 | folder / 根 | Reparent | ① 数据命令 | `MoveNodesCommand` | 撞环预判 + Handler 双保险；成功飞行、失败回弹 |
| F2 | 侧边栏 folder | 另一 folder | Reparent | ① 数据命令 | `MoveNodesCommand` | 目标不能是自身或后代 |
| F3 | 搜索结果行 | folder | Reparent | ① 数据命令 | `MoveNodesCommand` | 与 F1 同路径 |
| F4 | 侧边栏笔记 / 搜索结果 | 画布空白 | Project | ② 外观直写 | `position.graph.<id>` | `UIMovePlacement` 换算场景坐标 |
| F5 | 画布卡片 | 画布空白 | Project | ② 外观直写 | `position.graph.<id>` | 卡片拖动即时预览，drop 才落盘 |
| F6 | 画布卡片 | 另一卡片附近 | Bind | ① 数据命令 | `ConnectNodesCommand` | `CanvasCardDropSemantics` 服务先判定（插件 last-wins：AI 目标 = 数据命令）；未消费 → 默认连接；命中容差 + 就近判定 |
| F7 | 侧边栏笔记 / 搜索结果 | 工具栏 | Expose | ① 数据命令 | `CreateToolbarButtonCommand` | 源节点零变更；幂等 |
| F8 | AI 节点 | 侧边栏根 | Expose（角色单例） | ① 数据命令 | `EnsureAIWorkspaceCommand`（目标态，替代逐 AI 面板） | 每个侧边栏根至多一个 `ai-workspace`；AI 节点保持 L0 |
| F9 | 笔记 / 搜索结果 | 画布 AI 卡片 | Bind | ① 数据命令 | `DropIntoAICommand` | node_ai 的 `CanvasCardDropSemantics` last-wins 判定（M8，非组合根） |
| F10 | 任意 | 自身/后代/不兼容容器 | Reject | 拒绝 | `CycleError` / `RejectDrop` | Phase 4 回弹，零持久化副作用 |
| F11 | AI Tab 关闭/取消固定 | 侧边栏根 | Unexpose | ① 数据命令 | `RemoveAIWorkspaceCommand`（目标态） | 删除的是工作区投影，不删任何 AI 节点 |
| F12 | 画布卡片菜单"从画布移除" | 画布 | Unproject | ② UIStateStore 移除 | `position.graph.<id>` / `style.graph.<id>` | 同一身份在文件夹/工具栏等视图保持存在 |
| F13 | 任意节点 | AI Tab 内容区 | Bind（委托） | ① 数据命令 | `DropIntoAICommand` | `AIPanelView` 解析工作区当前 AI 节点后分发 |

不变量：F1/F3/F6/F7/F8/F9/F11/F13 只改 Graph；F4/F5/F12 只改 UIStateStore；F10 零副作用。

---

## 6. 差距审计与优先级

### P0 —— 事务不统一（先修，否则 Flowing UI 只有形没有神）

| # | 差距 | 现状证据 | 设计动作 |
|---|---|---|---|
| G1 | 不是所有 drop 都经过共享事务 | `FolderView` 自建 `DragController`/`FlightShell` 并先 `fly` 后 `bounce`；`GraphCanvas._resolveDrop` 自行写状态/发命令；`ToolbarActionsRow` 直接 dispatch，失败只 `debugPrint` | 全部迁移到 `host.dragController.onDrop(DropRequest)`；`FolderView` 删除本地控制器 |
| G2 | `dragStart`/`dragMove` 无真实接线 | 共享控制器已存在，但只有 `FolderView` 旧实例使用部分 API；搜索结果/画布/工具栏未喂 Phase 1/2 | 所有 Draggable 源接入 `recordDragStart` + `dragMove`；目标 `DragTarget.onMove` 上报候选 |
| G3 | UIMove 坐标绕过语义判定 | `CanvasConcept.askDropSemantics` 返回占位坐标，真实落点由 `GraphCanvas` 自行写 | 引入 `UIMovePlacement`，canvas 只提供坐标翻译，提交仍走 DragController |
| G4 | 失败反馈不统一 | 工具栏失败 debugPrint；Folder 成功/失败文案逻辑在视图内 | DragController 统一返回 `DropOutcome`；目标视图统一 SnackBar 文案 |
| G5 | Hook Tree 契约与实现不一致 | `Hook.references` 几乎全空，树枚举实际靠 `childNodeIdsOf` | 按 §3.4 修订契约解释；容器视图统一经 `childNodeIdsOf` 枚举 |

### P0 —— 解释生命周期不完整（§3.3.1.2 的四个实测症状）

| # | 差距 | 现状证据 | 设计动作 |
|---|---|---|---|
| G12 | `Expose` 没有 `Unexpose` | `AIPanelView` 无关闭/拖出/删除入口；`CreateAIPanelResult.inverse == null`；面板无法移除 | `RemoveAIPanelCommand`/工作区取消固定 + inverse 闭环；Tab 关闭动作 |
| G13 | 投影不继承 `pointsTo` 容器的 drop 语义 | `AIPanelView` 无 `DragTarget`；`AIPanelConcept.askDropSemantics` 默认拒绝 | R2：投影 `DragTarget` 解析目标 AI 节点后委托 `DropIntoAICommand` |
| G14 | 侧边栏 Tab 按实例建模 | `SidebarTabsView` 每个 `references.sidebar==root` 节点一个 Tab；N 个 AI 节点 = N 个 AI Tab | R4：AI Tab 单例 `ai-workspace`，内容内枚举 AI 节点与会话；旧 `ai-panel-*` 迁移 |
| G15 | 解释移除与身份删除混用 | `NodeCard._delete` 恒为 `DeleteNodeCommand`；删除画布上的 toolbar 按钮导致工具栏按钮同时消失 | R3：画布菜单拆分"从画布移除"（Unproject）与"删除节点"（身份删除） |

### P1 —— 体验完整性

| # | 差距 | 设计动作 |
|---|---|---|
| G6 | 无形态渐变、无目标插入槽、无源占位 | §4.3 落地 |
| G7 | 搜索/AI 面板等源未记录拖拽起点 | `FlowingDragSource` 包装器统一处理 |
| G8 | 窗口化只有画布半接线，回收无调用方 | §4.5 多容器窗口 |
| G9 | 工具栏按钮/AI 面板创建不可撤销 | §4.6 补 inverse |
| G10 | 连接线全量 `graph.getAll()` 扫描、连接未 Hook 化 | 10⁶ 优化项，随 §4.5 一并处理 |
| G11 | Flow 仍与拖拽耦合；AI/Lua/撤销等非拖拽写路径没有过渡语义 | 按 §4.7 给关键 WriteResult 补 `flowHint` |

### P2 —— 性能与非目标

| 项 | 结论 |
|---|---|
| 通用约束求解器 | v2 不做；按容器 `LayoutPolicy` 预留 |
| Flame 渲染栈 / LOD 四级 / 视锥裁剪 | 维持 `architecture.md` 的 [计划] 状态 |
| 多窗口/停靠布局 | 不做；当前侧边栏固定宽度问题另行 UX 决策 |
| 环允许（hyperset） | 不做（00 §2.3 v1） |

---

## 7. 实施计划

### Phase A：统一事务 + 解释生命周期（P0，建议先做）

1. `DragController.onDrop` 改为接收 `DropRequest`（保留旧签名做 deprecated 转发，测试不破坏）。
2. `FolderView` 迁移到 `host.serviceProvider.get<DragController>()` + `get<FlightShell>()`，删除手动 fly/bounce。
3. `ToolbarActionsRow` 迁移到统一事务：成功飞行、失败回弹 + SnackBar。
4. `GraphCanvas` 拆出 `CanvasDropPlacement`（命中判定、连接 vs 移动、场景坐标换算），把 `UIMove` 坐标交给 DragController；画布内即时预览保留。
5. `NoteRowView`/`FolderView`/搜索行为源统一接入共享控制器。
6. `NodeCard` 菜单拆分：`从画布移除` = 删 `position.graph.*`/`style.graph.*`（Unproject）；`删除节点` = `DeleteNodeCommand`，确认文案明示"所有视图一起删除"。
7. `AIPanelView` 包 `DragTarget<String>`：drop 解析当前 AI 节点后委托 `DropIntoAICommand`（R2）。
8. 补 `RemoveAIPanelCommand`（或取消固定的等价命令），Tab 增加关闭/拖出入口；`CreateAIPanelResult.inverse` 补齐（R1）。
9. `SidebarDropSemantics` 增加目标校验：只有 `targetContainerId == 侧边栏根` 才生成 AI 面板命令；否则回退 folder 语义，禁止幽灵面板。
10. 新增测试：
   - `appframe/test/drop_request_test.dart`：DropRequest 全分支（DataMove/UIMove/Reject/Cycle/节点不存在）。
   - `node_folder/test/folder_drop_unified_test.dart`：无双重影像，失败回弹只一次。
   - `node_graph/test/canvas_drop_unified_test.dart`：canvas 落点写入仍走 DragController，位置键正确。
   - `node_graph/test/node_card_scope_test.dart`：从画布移除只删 UIStateStore 键；删除节点才删 Graph。
   - `node_ai/test/ai_panel_lifecycle_test.dart`：面板可移除、AI 节点保持 L0；非根目标不生成面板。
   - `node_ai/test/ai_panel_drop_test.dart`：拖笔记到 AI Tab = `DropIntoAICommand`，聊天会话建立。
   - `appframe/test/toolbar_drop_test.dart` 扩展：失败可见反馈。

**验收**：grep 无视图自建 `DragController(`；所有 `onAcceptWithDetails` 均指向共享控制器；F1-F13 至少 10 条端到端测试；四个实测症状各有回归测试。

### Phase B：形态渐变与反馈（P1）

1. 落地 `FlowingAppearance`/`DragMoveEvent`。
2. 目标 `DragTarget.onMove` 上报候选，源 `Draggable.onDragUpdate` 喂位置。
3. `FlightShell` 支持 morph child + 减少动态效果直通。
4. 补 G7/G9/G11：撤销测试覆盖工具栏按钮/AI 面板；MoveNodes/DropIntoAI 等关键 `WriteResult` 返回 `flowHint`。
5. **AI Tab 工作区化（R4）**：引入单例 `ai-workspace`（`references.sidebar == root`，无逐 AI 面板）；`AIPanelView` 内部枚举 AI 节点与会话；旧 `ai-panel-*` 数据迁移/惰性兼容；`SidebarDropSemantics` 与 F8/F11/F13 同步到工作区模型。
6. 测试：morph progress 阈值、内容 0.5 交叉切换、reduced motion、Esc 取消、非拖拽命令的 flowHint 契约、多 AI 节点只产生一个 AI Tab。

### Phase C：多容器窗口化（P1）

1. `WindowManager`/`UIManager` 扩展 `ViewportWindow`。
2. 画布推送改为带 root/kind；侧边栏首版接 HookView 列表虚拟化。
3. 离视口回收 + 测试（回收后重进视口可重新物化）。
4. 10⁶ 指标仍按 `architecture.md` [计划] 管理，不在本阶段宣称达标。

### Phase D：性能与非目标（P2，仅记录）

- 连接 Hook 化、QuadTree 增量索引、LOD、Flame 评估；实施时先回填 `architecture.md`，不在本文件另立目标。

---

## 8. 验收清单

- [ ] 所有流动路径的语义三档无歧义：同一拖拽源在 folder/canvas/toolbar/AI 四类目标产生正确通道。
- [ ] 三对互逆生成元（Bind/Unbind、Project/Unproject、Expose/Unexpose）与四个产品宏（Reparent/Bind/Project/Expose）的映射、共现性符合 §3.3.1，无隐性"移动即独占"。
- [ ] 四个实测症状关闭：AI Tab 可取消固定；节点可拖入 AI Tab 建立会话；多 AI 节点只有一个 AI Tab；画布移除不误删其他视图。
- [ ] R1-R4 全部落地：Expose 有 Unexpose；投影 drop 委托 pointsTo；身份删除与解释移除分离；Tab 按角色聚合。
- [ ] 拖拽失败永远可见：撞环、schema 不兼容、命令失败均有用户可读反馈和回弹。
- [ ] 视觉事务单实例：快速连续拖拽不产生双影像、不串场、会话态必清理。
- [ ] 前端结构零持久化：所有 drop 后扫描 Graph 与 UIStateStore，结构/外观边界不变。
- [ ] 无数据副本：杀手演示（笔记 → folder → canvas → AI 对话）全程单 Node id。
- [ ] 撤销契约：所有 ① 档 drop 均可撤销或显式声明不可撤销。
- [ ] 非拖拽流：至少 MoveNodes/DropIntoAI 的 `WriteResult` 携带 `flowHint`，呈现层可据此过渡。
- [ ] `dart analyze` 零 error/warning；相关包测试全绿；`tool/check_imports.dart` 通过。

---

## 附录 A：组件职责表

| 组件 | 包/文件 | Flowing UI 职责 |
|---|---|---|
| `Concept` | `packages/core_data/lib/src/models/concept.dart` | schema + createHook + askDropSemantics + childNodeIdsOf |
| `DropSemantics` | `packages/core_data/lib/src/models/drop_semantics.dart` | 三档判定值对象 |
| `WriteResult` / `FlowHint` | `packages/core/lib/src/command/command.dart` | 写后通知载荷；可选解释过渡提示 |
| `Hook` / `HookContext` | `packages/core_data/lib/src/models/hook.dart` | 视图面、位置无关渲染 |
| `UIManager` | `packages/core/lib/src/ui_manager/` | 物化、窗口化、失效路由 |
| `DragController` | `packages/appframe/lib/src/interaction/drag_controller.dart` | 四阶段事务、语义执行、失败编排 |
| `FlightShell` | `packages/appframe/lib/src/interaction/flight_shell.dart` | overlay 过渡影像 |
| `FlutterRenderContext` | `packages/appframe/lib/src/render/flutter_render_context.dart` | Flutter 渲染 sink + 语义分发通道 |
| `HookView` | `packages/appframe/lib/src/ui/hook_view.dart` | Hook 渲染宿主 |
| 容器视图 | `folder_view.dart` / `canvas_widget.dart` / `toolbar_actions_row.dart` | 拖拽目标、预览、坐标翻译 |
| 侧边栏 Tab | `packages/node_folder/lib/src/sidebar_tabs_view.dart` | 角色级 Tab 聚合；实例在 Tab 内部呈现 |
| AI 面板 | `packages/node_ai/lib/src/ai_panel_concept.dart` | 工作区单例；投影 drop 委托 pointsTo；Unexpose 入口 |
| 卡片壳 | `packages/node_graph/lib/src/node_card.dart` | 画布卡片拖拽源/连接目标；菜单区分 Unproject 与身份删除 |
| 语义服务 | `SidebarDropSemantics` / `ToolbarDropSemantics` / `CanvasCardDropSemantics`（M8：三族同构，宿主缺省 + 插件 last-wins） | 插件语义覆盖 |
