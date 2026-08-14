# Flowing UI 设计

> 本文档定义了 Node Graph Notebook 的 Flowing UI 设计理念与体系。
> 基于 2026-05-06 架构讨论得出。
> 相关文档：[信号架构设计](signal_architecture.md)、[信号架构重构方案](../design_refactor/signal_architecture_refactor.md)

---

## 一、Flowing UI 的本质

### 1.1 核心定义

**UI 布局本身就是一个图结构。Flowing UI 的本质是：按图渲染，允许图结构变化。**

传统 UI 框架将布局视为静态的树结构（Widget 树、DOM 树），Flowing UI 将布局视为动态的图结构。节点在图中流动，图结构变化时 UI 自动重渲染。

### 1.2 三大原则

```
节点即内容 — Node 是系统中唯一的内容单元
Hook 即视图 — Hook 是 Node 在 UI 中的表现形态
流动即交互 — 拖拽是节点在 Hook 之间流动的主要交互方式
```

### 1.3 与传统 UI 的区别

```
传统 UI：
  布局 = 静态树结构
  交互 = 事件回调
  变更 = 重建子树

Flowing UI：
  布局 = 动态图结构
  交互 = 节点流动
  变更 = 图拓扑变化 → 自动重渲染
```

---

## 二、All is Node

### 2.1 递归定义

"All is Node" 是一个递归定义：

```
节点是 Node
节点之间的关系是 Node
关系之间的关系也是 Node
... 无限递归
```

图不是"节点+边"的结构，而是"节点+引用"的结构。
"边"只是 RelationshipNode 的一种解读——当某个 Node 的角色是"表示两个其他 Node 之间的关系"时，我们称它为"边"。

### 2.2 NodeReference 是统一引用机制

```
NodeReference 可以指向任何 Node：
  DataNode → DataNode          "节点 A 引用节点 B"
  DataNode → RelationshipNode  "节点 A 是关系 R 的源"
  RelationshipNode → DataNode  "关系 R 指向节点 B"
  RelationshipNode → RelationshipNode  "关系 R1 与关系 R2 冲突"
```

NodeReference 不是"边"——它是指针。
"边"的语义由 RelationshipNode 承载，NodeReference 只是指向 RelationshipNode 的索引。

### 2.3 逻辑模型与物理模型

遵循"避免提前优化"原则，先实现完整的设计理念，再考虑优化。

```
逻辑模型（设计理念 / 开发者 API）：
  关系是 Node — 所有边都是 Node，统一模型
  这是 API 表面，是开发者看到的

物理模型（实现优化 / 系统内部）：
  关系存储在索引结构中 — _nodeToHookIndex、_hookChildrenIndex 等
  这是存储层，是系统内部实现

关键约束：
  物理模型是逻辑模型的派生——索引从关系 Node 计算得出
  逻辑模型是权威数据——关系 Node 是 Single Source of Truth
  索引只是缓存——可以随时从关系 Node 重建
```

---

## 三、Hook is Node

### 3.1 一体两面

Hook 和 Node 是同一个东西的两个面：

```
Hook = Node 的前端（视图层表现）
Node = Hook 的后端（数据层实体）
```

规则：
- Hook 一定有对应的 Node（每个视图区域都有数据支撑）
- Node 不一定有对应的 Hook（数据可以没有视图表现）

### 3.2 推论

```
Sidebar 是一个 Node → Sidebar Hook 是其视图
Graph 是一个 Node → Graph Hook 是其视图
Toolbar 是一个 Node → Toolbar Hook 是其视图
文件夹节点是一个 Node → 文件夹 Hook 是其视图
所有 UI 区域都有对应的 Node 数据
```

### 3.3 前端图与后端图

前端图是后端图的带层级过滤的投影，不是 1:1 映射。

```
后端图：
  顶点：Node（包括 DataNode 和 RelationshipNode）
  边：  NodeReference（从 Node 指向 RelationshipNode 的指针）
  语义：领域关系 + UI 关系统一

前端图：
  顶点：Hook（每个 Hook 对应一个 Node）
  边：  关系 Hook（RelationshipNode 的视图）
  语义：UI 结构（后端图的投影）

层级过滤：
  完全一一对应会让用户眼花缭乱，需要层级展示
  不同 Hook 有不同的默认可见层级
  折叠/展开是层级切换操作
```

### 3.4 RelationshipNode 的统一

所有关系类型都是 RelationshipNode 的 relationshipType 字段：

```
'dependency'  → 领域依赖关系
'contains'    → 领域包含关系
'ui-contain'  → UI 包含关系（Sidebar 包含列表项）
'ui-connect'  → UI 连接关系（Graph 中节点连线）
'source'      → 连线的源端
'target'      → 连线的目标端
'conflicts'   → 关系间冲突（关系之间的关系）
... 插件可定义新类型
```

没有"领域关系"和"UI 关系"的分类——它们都是 RelationshipNode，
只是 relationshipType 不同。前端根据类型选择不同的渲染方式。

---

## 四、Role 模型

### 4.1 角色的本质

**角色（Role）= 节点在特定上下文中可以扮演的身份。**

角色不是节点的固有属性，而是上下文相关的。同一个节点在不同 Hook 中扮演不同的角色。

```
文件夹节点的角色：
  - 在 Sidebar 中扮演 list-item 角色
  - 在 Graph 中扮演 graph-node 角色
  - 在 TabBar 中扮演 tab 角色
  - 自身也可以扮演 container 角色
```

### 4.2 角色匹配

角色匹配是 Node 对 Node 的，不涉及 Hook。

```
容器 Node 的 NodeTemplate 定义：
  offeredRoles = ['list-item', 'tab']  // 我作为容器，提供这些角色给子节点

子 Node 的 NodeTemplate 定义：
  compatibleRoles = ['list-item', 'graph-node', 'container']  // 我可以扮演这些角色

匹配规则：
  容器 Node 提供的角色 ∩ 子 Node 兼容的角色 ≠ ∅ → Accept
```

### 4.3 角色与视图

**视图由包含此节点的 Hook 渲染器根据角色决定。**

```
同一文件夹节点：
  - 扮演 list-item 角色 → Sidebar Hook 渲染为列表项（窄高条形）
  - 扮演 graph-node 角色 → Graph Hook 渲染为图节点（宽矮矩形）
  - 扮演 tab 角色 → TabBar Hook 渲染为标签页

角色决定了：
  - 视图形态（如何渲染）
  - 内禀尺寸（布局约束的输入）
  - 关系类型（与容器建立什么关系）
  - 布局约束（空间约束条件）
```

### 4.4 Act：节点的行为选择

Node 可以"act"为不同的东西——这是节点选择呈现的行为方式。

```
一个 Node 可以 act 为：
  - node       → 表现为数据节点
  - connection → 表现为连接线
  - container  → 表现为容器
  - hider      → 表现为折叠/隐藏器
  - ... 更多行为可扩展
```

Act 的决定权：
```
AI Node → 主动选择 act 什么（有自主决策能力）
普通 Node → 被动接受或由用户决定
用户 → 可以手动决定节点的 act
```

Act 的限制：
```
根本限制：connection act 必须有 source/target reference
上下文限制：父/子节点可能限制可用的 act
数据限制：container act 必须有子节点
```

### 4.5 可组合的 Role 模型

Role 是可组合的，但组合方式不是简单的平级叠加。
不同 Role 在渲染流中的地位不同——需要定义可组合的 Role 模型。

```
一个 Node 可以同时具有多个 Role：
  文件夹 Node = node + container + hider
  连线 Node = connection
  AI Node = node + container + connection + hider（更灵活）

Role 之间有组合规则：
  container + hider 可以共存（折叠的容器）
  container + connection 互斥（容器不能同时是连线）

Role 有前提条件：
  connection → 必须有 source/target reference
  container → 必须有子节点
  hider → 必须有 container（只能隐藏容器中的内容）
```

---

## 五、NodeTemplate 设计

### 5.1 职责定义

NodeTemplate 定义节点的后端本质——它是什么、能做什么、如何与其他节点建立关系。

```
NodeTemplate 定义（后端/数据层）：
  1. 数据结构 — metadata schema + 默认值
  2. 可扮演的角色 — compatibleRoles: ['list-item', 'graph-node', 'container', 'tab']
  3. 容器行为 — 如果扮演 container 角色，offeredRoles: ['list-item', 'tab']
```

**尺寸和关系类型不在 NodeTemplate 中**——它们由前端 Hook 渲染器根据角色决定。

### 5.2 与 Hook 渲染器的关系

```
NodeTemplate（后端）：
  声明"我可以扮演什么角色"

Hook 渲染器（前端）：
  定义"这个角色在我这里意味着什么"
  - 视图形态
  - 内禀尺寸
  - 关系类型
  - 布局约束
```

角色是后端和前端的桥梁。

### 5.3 匹配机制

```
角色匹配为主：
  容器 Node.offeredRoles ∩ 子 Node.compatibleRoles ≠ ∅ → 可 Accept

白名单为辅：
  NodeTemplate.allowedHooks = ['sidebar', 'graph']
  HookRenderer.allowedNodeTypes = ['folder', 'note']
  白名单作为额外约束

双向声明：
  两边都声明提供/需要，确保双方同意
```

---

## 六、渲染流

### 6.1 渲染流的组织

渲染流从图结构推导。Container 是渲染宿主，负责组织其子节点的渲染。

```
对于任何 container 节点，渲染流为：

1. 收集子节点
   遍历 ui-contain 类型的 RelationshipNode，找到所有子节点

2. 按 act 分类
   - node/container → 布局参与者
   - connection → 覆盖层参与者

3. 布局阶段
   布局参与者确定位置和尺寸，产生 LayoutResult

4. 覆盖层阶段
   覆盖层参与者根据 LayoutResult 绘制

5. 递归
   container 类型的子节点递归执行 1-5
```

### 6.2 三个核心问题

**Layer 由谁决定？→ Container（渲染宿主）**

同一个 connection act，不同的 container 渲染方式不同：
```
GraphNode → connection 渲染为覆盖层连线
TreeListView → connection 渲染为缩进树线
ThreeDView → connection 渲染为 3D 管道
```

Container 是渲染宿主，它决定如何渲染子节点的每个 act。
子节点的 act 是"提示"，Container 有最终决定权。

**渲染的数据怎么来？→ 从图结构遍历 + 布局计算结果**

```
1. Container 收集子节点和 RelationshipNode → 数据来源：图结构遍历
2. Container 运行布局算法 → 输入：内禀尺寸 + 约束 → 输出：LayoutResult
3. Container 将 LayoutResult 传递给覆盖层渲染器
4. ConnectionNode 从 LayoutResult 查询 source/target 位置
```

**渲染的结果到哪里去？→ 向上返回尺寸 + 向下传递布局 + 合成绘制**

```
布局结果（LayoutResult）：
  → 向上返回给父 container（父需要知道子的尺寸）
  → 向下传递给覆盖层渲染器（connection 需要节点位置）

绘制结果（PaintOutput）：
  → 在 container 的坐标系中合成
  → 先绘制布局层（节点），再绘制覆盖层（连线）

交互结果（HitTestResult）：
  → 从屏幕坐标反向查找命中的节点
```

### 6.3 具体示例：渲染 Graph 视图

```
图结构：
  GraphNode (container + connection-space)
    ├── R1: GraphNode → FolderNode-A (ui-contain)
    ├── R2: GraphNode → NoteNode-D (ui-contain)
    └── R7: GraphNode → ConnectionNode-F (ui-contain)

  FolderNode-A (node + container)
    ├── R5: FolderNode-A → NoteNode-B (contains)
    └── R6: FolderNode-A → NoteNode-C (contains)

  ConnectionNode-F (connection)
    ├── R3: ConnectionNode-F → FolderNode-A (source)
    └── R4: ConnectionNode-F → NoteNode-D (target)

渲染流：

1. GraphNode 收到约束：BoxConstraints(0≤w≤800, 0≤h≤600)

2. 收集子节点（遍历 ui-contain 关系）：
   - FolderNode-A (act: node+container) → 布局参与者
   - NoteNode-D (act: node) → 布局参与者
   - ConnectionNode-F (act: connection) → 覆盖层参与者

3. 布局阶段：
   a. 询问内禀尺寸：FolderNode-A=200×100, NoteNode-D=150×80
   b. 应用布局算法：FolderNode-A→(100,200), NoteNode-D→(400,300)
   c. 产生 LayoutResult: {A: Rect(100,200,200,100), D: Rect(400,300,150,80)}

4. 覆盖层阶段：
   ConnectionNode-F 查询 LayoutResult：
   source = LayoutResult[A].center = (200, 250)
   target = LayoutResult[D].center = (475, 340)
   绘制从 (200, 250) 到 (475, 340) 的曲线

5. 递归：
   FolderNode-A 如果展开，作为 container 递归渲染 NoteNode-B, NoteNode-C

6. 返回：Size(800, 600) 给 AppNode
```

### 6.4 ConnectionNode 也需要 ui-contain 关系

```
ConnectionNode 必须通过 ui-contain 关系属于某个 container，
否则 container 不知道它的存在，无法渲染它。

ConnectionNode 的双重身份：
  - 既是"连线"（视觉上连接两个节点）→ 通过 source/target 关系
  - 也是"子节点"（属于某个 container）→ 通过 ui-contain 关系

不同的 RelationshipNode 表达不同的语义：
  R7: GraphNode → ConnectionNode-F (ui-contain)  ← 结构关系
  R3: ConnectionNode-F → FolderNode-A (source)    ← 连线语义
  R4: ConnectionNode-F → NoteNode-D (target)      ← 连线语义
```

---

## 七、布局协议

### 7.1 统一约束协议

布局协议不是多种模式的组合，而是**统一的约束求解系统**。

```
布局协议（统一）：
  1. 每个节点声明内禀尺寸（由角色和 Hook 上下文决定）
  2. 每条关系边产生空间约束
  3. 布局算法求解所有约束
  4. 输出：每个节点的最终位置和尺寸
```

不同关系类型产生的不是不同的布局模式，而是不同的约束条件。
不是"切换模式"，而是"约束集合变化，布局自动重算"。

### 7.2 约束来源

```
Containment 关系产生的约束：
  child.width  ≤ parent.width  - padding
  child.height ≤ parent.height - padding
  child.x ≥ parent.x + padding
  child.y ≥ parent.y + padding

Connection 关系产生的约束：
  distance(nodeA, nodeB) ≤ preferredDistance

折叠 Containment 产生的约束：
  group.width  = sum(children.width)  + spacing
  group.height = max(children.height) + padding
```

### 7.3 待澄清

- 约束类型体系的具体定义
- 约束求解算法的选择
- 约束与关系类型的完整映射
- 参考 Flutter 约束模型的具体借鉴方式

---

## 八、流动交互协议

### 8.1 事务性拖拽

拖拽是一个视觉事务：开始 → 实时预览 → 提交/回滚。

```
Phase 1: Drag Start → 开启视觉事务
  - 节点进入"过渡态"（视觉上脱离源 Hook）
  - 源 Hook 显示空位
  - 拖拽影像跟随光标
  - 不产生任何 Command/Event

Phase 2: Drag Move → 实时预览
  - 拖拽影像接近目标 Hook 时，逐渐变形为目标角色形态
  - 目标 Hook 显示预览位置
  - 形态渐变：源角色形态 → 目标角色形态

Phase 3: Drop → 提交事务
  - dispatch(MoveNodeCommand) — 原子操作
  - 动画：拖拽影像滑入目标 Hook 的预览位置
  - 动画完成后恢复正常渲染

Phase 4: Cancel → 回滚事务
  - 动画：拖拽影像弹回源 Hook 的原始位置
  - 不产生任何 Command/Event
  - 动画完成后恢复正常渲染
```

### 8.2 数据层与视图层分离

```
数据层（原子操作）：
  MoveNodeCommand → 节点从 Hook A 分离 + 附着到 Hook B
  → 一个 Command，一个事务，要么全部成功要么全部回滚

视图层（动画效果）：
  节点视觉上从源位置滑动到目标位置
  → 纯 UI 效果，不影响数据模型
  → 类似 Flutter 的 AnimatedContainer
```

### 8.3 形态渐变（Morphing）

拖拽过程中，节点根据距离目标 Hook 的远近逐渐变形为目标角色的形态。

```
远离所有 Hook → 保持源角色形态
接近 Sidebar  → 逐渐变为 list-item 形态
接近 Graph    → 逐渐变为 graph-node 形态

morphProgress = clamp(distance / threshold, 0, 1)
visualState = lerp(sourceRoleAppearance, targetRoleAppearance, morphProgress)
```

渐变属性：
```
可插值（渐变）：位置、尺寸、圆角、透明度、颜色
不可插值（切换）：内部布局结构、交互行为
```

初始实现策略：只渐变外壳属性（位置+尺寸+圆角+透明度），内部内容在 morphProgress > 0.5 时淡入淡出切换。

### 8.4 渲染分配协议

拖拽过程中各参与者的渲染责任：

```
系统层（协调者）：
  - DragController 管理拖拽事务生命周期
  - 协调源 Hook、目标 Hook、全局 Overlay 的渲染
  - 处理坐标转换（全局 ↔ 本地）

源 Hook：
  - 渲染空位占位符
  - 提供 dragFeedback（拖拽影像的源外观）

目标 Hook：
  - 渲染高亮区域
  - 提供 dropPreview（放置预览位置）
  - 提供目标角色形态

全局 Overlay：
  - 渲染拖拽影像（跟随光标）
  - 执行形态渐变动画
```

---

## 九、待澄清问题

### 9.1 Role/Act 模型

- [ ] 可组合 Role 模型的具体定义（组合规则、前提条件、上下文约束）
- [ ] Act 与 Role 的精确关系
- [ ] Role 在渲染流中的完整参与方式

### 9.2 布局

- [ ] 约束类型体系的具体定义
- [ ] 约束求解算法的选择
- [ ] 约束与关系类型的完整映射
- [ ] 参考 Flutter 约束模型的具体借鉴方式
- [ ] 布局信息（位置、尺寸）的存储位置

### 9.3 渲染

- [ ] Flame vs Flutter 的优缺点对比
- [ ] 双框架结合的具体方式
- [ ] Graph 视图的渲染策略
- [ ] 跨框架拖拽的实现

### 9.4 集成

- [ ] HookRenderer 完整接口设计
- [ ] 与现有 UIHookBase 的过渡方案
- [ ] Flowing UI 集成到 appframe 的具体步骤
