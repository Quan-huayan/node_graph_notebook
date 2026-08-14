# 00 — 宪章：All is Node、两层模型与核心不变量

> 本文档是整个设计文档集的地基。
> 本文中的**不变量**是全文档集唯一出处，后续文档（02-04）只引用、不重复定义。
> 本文档是六篇文档中唯一回答"为什么"的文档。

---

## 一、产品动机

**现状的问题**：笔记本的组织方式被树状目录 + 页面层级锁死。知识是图，但工具是树——把两篇笔记的关系、把一个想法变成一段对话、把零散资料重组为一个概念，都被"文件在哪个文件夹里"困住。

**本产品的主张**：知识是图。笔记是节点，关系是节点，AI 是节点，连 UI 本身都是节点（Hook）构成的图。一切流动，一切可以被重组。

**杀手演示**：把一篇笔记拖进 AI 节点——它重新解释自己的形态，变成一段对话。拖进文件夹——它变成列表项。拖上画布——它变成图节点。**同一个数据实体，在不同容器中流动并变形，全程无数据副本。**

**形态渐变拖拽（Flowing UI）**是这个主张的可见载体，是与其他任何笔记工具的差异化：拖拽不是一个"移动操作"，是节点在重新定义自己。

**目标规模**：10⁶ 节点（Obsidian 级仓库）。这不是宣传数字，是架构约束——所有设计在 10⁶ 下必须成立。

**本文档集的目的**：把上述故事变成可实现的工程。故事可以大胆，工程必须收敛——收敛点就是本文的不变量。

---

## 二、核心命题：All is Node

### 2.1 两种实体

系统中有且只有两种实体：

- **Concept = 代码层（schema）**。定义一类 Node 的结构约束（slots、metadataSchema、required）与行为（createInstance、createHook、validate）。写死在 Plugin 里，不存储在数据中。
- **Node = 数据层（instance）**。结构上满足某个 Concept 的 schema 的数据实体。纯数据，无行为。存储于 Graph。

"节点"和"边"不是两种 Node——这是传统图论的二分法。在这里，**边只是恰好引用了一组低层 Node 的 Node**。

### 2.2 Ln 递归定义

```
L0-node：不引用任何 Node。        references = {}
L1-node：只引用 L0-node。        它就是传统认知中的"连接"——但它不是 Edge 类，
                                 它只是一个 Node，恰好 references 的目标都是 L0-node。
L2-node：只引用 L0-node 或 L1-node。
...
Ln-node：只引用 level < n 的 Node。

level(Node) = references 为空 ? 0 : 1 + max(level(target))
```

这是纯粹的递归数据结构，不附加任何语义。L1-node"表示连接"不是因为有一个 Connection 类型——而是前端呈现时，由它的 Concept（schema）把它解释为连接。

### 2.3 环策略（v1）

**环不被允许。** Node 引用图中不得存在环（沿 references 可达自身）。

- **执行点**：写命令的 Handler，在落盘前对受影响子图做 acyclicity 校验。
- **失败表现**：命令拒绝，返回用户可读错误——"此操作会形成循环引用，已阻止"。
- **拖拽相关性**：把文件夹 A 拖入 A 的后代文件夹，是必然撞环的拖拽，在 drop 判定阶段即可预判并拒绝。

**未来（非 v1）**：若底层采用非良基集合（hyperset）模型，环将被允许，level 取递归方程的最小不动点（ℕ∪{∞}，∞ ⟺ 节点不接地）。v1 不做，保持"阻止"的简单语义。

### 2.4 level 的定位

**level 不存在于数据模型中**：不存储、不是 Node 属性、不是 Graph 的职责。

level 是布局算法的启发式输入，按需近似计算，允许 ∞（纯环节点按顶层处理）。任何布局层不得要求数据层提供 level。

---

## 三、两层模型：逻辑层与物理层

### 3.1 逻辑层：Node

Node 是逻辑身份：id、title、references、metadata、内容引用。它是结构层，是引用关系的载体，是 Concept 作用的对象。

### 3.2 物理层：文件

**内容 = 文件，任意类型**：markdown 笔记、代码、数据文件、3D 模型、二进制。整个数据目录就是一棵文件树，可以直接被编辑器、git、脚本管理——产品数据不锁死在私有格式里。

- 内容形态：文本（markdown 等主内容）+ **内容类型节点**（代码/数据/3D/二进制——附件不是字段，是被引用的节点，All is Node 推论）
- 物理文件是存储实现的序列化形态（FSTGraph 落盘），**逻辑层接口不暴露文件概念**（§3.4 的彻底落地）
- **节点系统是在文件的基础上引申出来的**：文件是内容的物理载体，Node 是文件之上的结构

### 3.3 git 类比的收敛

"某种形式的 git"必须收敛，否则是修辞：

| 借 | 不借 |
|---|---|
| 文件树组织（数据即目录） | **内容寻址**（blob 哈希做引用——文件一改引用即失效） |
| 内容与结构分离（`.git` 的哲学：结构与内容分开存） | **commit 历史**（v1 不做版本历史） |
| 可 diff、可被外部工具管理 | 分支合并语义 |

### 3.4 物理不污染逻辑（推论）

1. **Node.id 是逻辑身份**（uuid，稳定）；**文件路径是别名**，不是身份。
2. 文件移动、重命名 ≠ Node 失效——别名变化不影响逻辑身份。
3. **物理布局永不上浮为逻辑结构**：目录树结构 ≠ 引用结构。文件的存放位置只是物理安排，references 才是逻辑关系。

---

## 四、核心不变量（唯一出处）

### 4.1 投影不变式

> **Hook 树结构 ≡ F(Graph, ConceptRegistry, UIStateStore)，其中 UIStateStore 不含任何结构性数据。**

- **推论 1：前端结构永不持久化。** 只有两个存储：Graph（数据）+ UIStateStore（外观状态）。树结构不在任何一个里，它是投影。
- **推论 2：任何"需要持久化前端结构"的需求 = 设计错误的检测器。** 要么它真是数据（改 Graph），要么它是伪需求（删掉）。没有第三种。
- **推论 3：Hook.references 每次从后端图 + schema 匹配 + 容器语义推导重建。**

### 4.2 三档操作判据

任何用户操作，按语义分三档：

| 档 | 语义 | 通道 | 例子 |
|---|---|---|---|
| ① | 改变"笔记本是什么" | 数据命令 → 改 Graph | 重排目录、建立引用、改标题 |
| ② | 改变"看起来怎么样"且需跨会话保留 | UIStateStore 写 | 画布位置、展开状态、相机 |
| ③ | 会话态 | 什么都不写 | 选中、拖拽中、滚动 |

**判据**：如果一个操作重启后会"失忆"，而用户期望它被记住——它是①，不是②。

**推论**：侧边栏拖拽（重排目录）= ①数据命令，改的是 folder 的 references；画布拖动 = ②，写 UIStateStore。同一个手势，语义由目标容器在 drop 时判定（见 03）。

### 4.3 归属与确定性

1. **Node ↔ Concept 归属 = 纯结构匹配**（references keys ⊆ slots ∧ required 满足 ∧ metadata required 满足），无 instanceOf。
2. **多 schema 同时命中**：特异性优先（required 约束多者胜）→ 注册序平局。
3. **无 schema 命中**：兜底 Concept 渲染为普通笔记——**永不空洞，永不崩溃**。
4. **结构确定性 = 后端图 + 全序优先序**。与插件加载顺序无关（全序吸收），与 UIStateStore 无关（外观不参与结构）。
5. **Node 是纯数据**：不知道自己被哪些 Hook 呈现。一个 Node 可以对应多个 Hook（不同容器中不同形态），Hook 只读自己 Node 的 metadata。

### 4.4 写操作通道

1. **写操作一律走 Command → Handler。** Hook 不直接创建/修改/删除 Node。
2. **Command 是纯 DTO**，无 execute()。业务逻辑全部在 Handler。
3. **环校验是 Handler 的职责**（v1，见 2.3）。
4. 被动读的**通知机制是实现细节**，但**通知的路由归属（UI 管理器）与反应归属（Concept）是架构决策**——见 02。

---

## 五、删除清单

以下概念**不出现在新设计中**：

| 删除 | 替代 |
|---|---|
| `Connection` / `Edge` 类 | L1-node |
| `NodeReference` 类 | `String`（targetId） |
| `RelationshipNode` 子类 | 不存在，所有 Node 是同一个 Node 类 |
| `metadata['instanceOf']` | 纯结构 schema 匹配（4.3） |
| `NodeTemplate` | Concept（代码层 schema） |
| `NodeAttachment` | Hook ↔ Node 由 Concept.createHook() 绑定 |
| `UIHookNode` | Hook.references 即 UI 树结构 |
| `Role` / `Act` 独立系统 | `Concept.createHook(node, context)`（02） |
| `Event` / `EventBus` 抽象 | 被动读契约（4.4），通知机制属实现层 |
| `QueryBus` / `Query` 抽象 | 读取优化，属实现层 |
| `Command.execute()` | Command 是纯 DTO |
| `Node.size` / `Node.color` / `Node.viewMode` | UIStateStore（键带容器上下文） |
| 旧 Hook 扩展点（`HookRegistry`、`main.toolbar`、`sidebar.bottom`…） | 一律转新 Hook：工具栏/侧边栏/状态栏都是容器 Node 的 Hook |
| 旧 Lua API（`registerHook` 等） | Lua 重写为动态 Concept 引擎（脚本化 Concept + Handler + Hook） |

---

## 六、术语表

| 术语 | 定义 |
|---|---|
| **Node** | 数据层实体，结构上满足某 Concept schema 的实例。纯数据，无行为 |
| **Concept** | 代码层 schema：结构约束 + createInstance / createHook / validate。Plugin 提供 |
| **Hook** | Node 的视图面。位置无关渲染，只读自己 Node.metadata，references 只含 Hook |
| **Hook Tree** | 前端图，渲染层次。Hook.references 即递归结构 |
| **容器** | 拥有 context.kind 的 Hook：决定子 Hook 的呈现形态与 drop 语义判定 |
| **兜底 Concept** | 内置通用 schema，无匹配 Node 的降级渲染，保证永不空洞 |
| **文件层** | 物理内容存储，任意类型文件，可被外部工具管理 |
| **UIStateStore** | 外观状态存储（位置/展开/相机/选中），不含结构性数据 |
| **窗口化** | Hook 按视口/容器按需物化与回收（10⁶ 规模的前提） |
| **飞行壳层** | 拖拽提交时跨越旧/新 Hook 树过渡的渲染层（03） |
| **Command / Handler** | 写操作通道：纯 DTO + 业务逻辑执行者 |
| **失效** | 数据变更 → UI 管理器路由 → 已物化 Hook 通知 → Concept 反应重渲染 |

---

## 七、文档地图与冻结条件

```
01 职责矩阵（先行活文档，承诺清单）
00 宪章（本文档，不变量唯一出处）
02 模型与呈现     Node/Concept/Graph + 文件层 + 双存储 + Hook 系统（窗口化/失效）
03 交互与信号     拖拽事务/飞行壳层/drop 判定 + Command→Handler + 主动/被动读
04 组装与工程     ConceptRegistry/Plugin/DI + 生命周期降级 + 资产盘点 + 包结构 + 里程碑
architecture.md   落地层：核心类/时序/存储/渲染循环/任务清单（与 02 同步起草）
```

**写作顺序**：01 → 00 → 02 → 03 → 04 → architecture.md（同步起草）。

**冻结条件（M0 里程碑）**：六篇全部完成 + 01 职责矩阵回填完毕 + 无"属实现层"藏匿决策问题。

**约束**：02-04 不得重复定义本文的不变量；architecture.md 不得引入矩阵之外的概念。
