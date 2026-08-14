# 信号架构设计

> 本文档定义了 Node Graph Notebook 的信号架构设计原则与体系。
> 基于 2026-05-06 架构讨论得出。

---

## 一、根本问题：操作只有读/写

系统的根本操作只有两种：

- **写（Write）**：改变状态
- **读（Read）**：访问状态

Command、Event、Query 都不是独立的操作类型，而是对读/写的不同视角和机制。

### 1.1 写的两个视角

```
意图视角（Command）： "请将节点从 Graph 移到 Sidebar"  — 可拒绝、可撤销
事实视角（Event）：   "节点的 Hook 附着已变更"          — 不可拒绝、不可撤回
```

Command 和 Event 是**同一个写操作的两个面**：
- Command 是写的请求面——"我想改变状态"
- Event 是写的可观测面——"状态已经改变"

两者不是独立的信号类型，而是写操作生命周期的两个阶段。

### 1.2 读的两种方式

```
拉取方式（Query）：  "给我当前状态" — 按需获取、同步等待
推送方式（Event）：  "状态变了"     — 被动通知、异步接收
```

Query 和 Event 是**读的两种实现策略**：
- Query 是主动拉取——依赖者按需读取
- Event 是被动通知——状态所有者推送变更信号

### 1.3 Event 的本质

Event 不是第三种操作。Event 是**写的可观测性（Observability of Write）**。

```
没有 Event：写操作是暗操作——状态变了但没人知道
有了 Event：写操作是明操作——状态变了，依赖者可以响应
```

Event 解决的核心问题：**在解耦系统中，如何让读操作知道写操作已经发生？**

```
没有 Event → 读者必须轮询（低效）
有了 Event → 读者被动通知（高效）
```

Event 是轮询的优化，是跨组件状态同步的效率机制。

---

## 二、三种信号的定位

### 2.1 Command — 写意图

```
本质：请求改变状态的意图
时态：将来时——"我要做"
可拒绝：验证失败、权限不足可拒绝
可撤销：意图可以被撤回
有主体：谁发出的意图（用户/AI/系统/插件）
```

**解耦能力**：
- 空间解耦 ✅ — 发送者不知道哪个 Handler 处理
- 类型解耦 ✅ — 新 Handler 可注册
- 时间解耦 ⚠️ — 当前同步执行，可改为异步
- 契约解耦 ❌ — Command 格式是发送者与 Handler 的契约

### 2.2 Event — 写的可观测性

```
本质：状态变更的通知信号
时态：过去时——"已经做了"
不可拒绝：事实无法被拒绝（已经发生了）
不可撤销：事实不可撤回（只能用新事实抵消）
无主体：事实就是事实，不关心谁导致的
```

**解耦能力**：
- 时间解耦 ✅ — 异步通知
- 空间解耦 ✅ — 发布者不知道谁在监听
- 类型解耦 ✅ — 新订阅者可注册
- 契约解耦 ✅ — 订阅者自主解读

Event 是解耦能力最强的信号类型。它是系统中唯一能实现完全解耦的通信机制。

### 2.3 Query — 读请求

```
本质：按需访问当前状态
时态：现在时——"当前是什么"
无副作用：不改变任何状态
可缓存：结果可缓存以提升性能
```

**解耦能力**：
- 时间解耦 ❌ — 同步等待结果
- 空间解耦 ❌ — 调用者知道被调用者
- 类型解耦 ❌ — 调用者知道返回类型
- 契约解耦 ❌ — 返回格式是调用者与响应者的契约

Query 不解耦，这是设计上的取舍——用耦合换取效率。

### 2.4 三者的关系图

```
                    ┌──────────────────────┐
                    │    外部（UI/插件/AI）  │
                    └──────────┬───────────┘
                               │
                    "我想改变状态"
                               │
                    ┌──────────▼───────────┐
                    │      Command          │
                    │   （写意图/中等解耦）   │
                    └──────────┬───────────┘
                               │
                    路由到状态所有者
                               │
                    ┌──────────▼───────────┐
                    │    状态所有者          │
                    │  验证 + 执行 + 持久化  │
                    └──────────┬───────────┘
                               │
                    "状态变了"
                               │
               ┌───────────────┼───────────────┐
               │               │               │
    ┌──────────▼──────┐        │        ┌──────▼──────────┐
    │     Event        │        │        │     Query        │
    │  （写的可观测性） │        │        │  （读请求/无解耦）│
    │  完全解耦        │        │        │                  │
    └──────────┬──────┘        │        └──────┬──────────┘
               │               │               │
    依赖者被动通知      状态所有者直接返回      依赖者主动拉取
               │               │               │
    ┌──────────▼──────┐        │        ┌──────▼──────────┐
    │  依赖者响应      │        │        │  依赖者获取数据  │
    │  BLoC/插件/UI   │        │        │  BLoC/插件/UI   │
    └─────────────────┘        │        └─────────────────┘
                               │
                    ┌──────────▼───────────┐
                    │  状态所有者提供数据    │
                    └──────────────────────┘
```

---

## 三、设计原则

### 原则1：状态归属（State Ownership）

每一块状态有且仅有一个所有者。状态变更只能通过所有者的 API 发起。

```
NodeRepository   owns  NodeState        — 节点数据的唯一权威
GraphRepository  owns  GraphState       — 图数据的唯一权威
UILayoutService  owns  LayoutState      — 布局附着关系的唯一权威
UIBloc           owns  ViewState        — UI 偏好的唯一权威
PluginManager    owns  PluginState      — 插件生命周期的唯一权威
```

**推论**：Event 的生产权属于状态所有者。不是"谁执行了 Command"，而是"谁拥有变更后的状态"。

```
CreateNodeCommand → Handler → NodeRepository.save()
                                ↓
                          NodeRepository 是 NodeState 所有者
                          → NodeRepository 发出 NodeState 变更信号

MoveNodeCommand → Handler → UILayoutService.moveNode()
                                ↓
                          UILayoutService 是 LayoutState 所有者
                          → UILayoutService 发出 LayoutState 变更信号
```

### 原则2：依赖驱动传播（Dependency-Driven Propagation）

信号沿依赖图传播。组件声明"我依赖什么状态"，状态变更时自动通知。

```
GraphBloc   depends on  NodeState, GraphState
SidebarBloc depends on  NodeState
HookRenderer depends on LayoutState
PluginA     depends on  PluginState, NodeState

自动推导：
  NodeState 变更 → 通知 GraphBloc, SidebarBloc, PluginA
  LayoutState 变更 → 通知 HookRenderer
  PluginState 变更 → 通知 PluginA
  ViewState 变更 → 无外部依赖者（本地传播）
```

### 原则3：意图与事实分离（Intent vs Fact Separation）

Command 表达意图（可拒绝），Event 表达事实（不可拒绝）。

```
意图面：Command — "请将节点从 Graph 移到 Sidebar"
事实面：Event   — "节点的 Hook 附着已从 Graph 变为 Sidebar"
```

Event 不携带来源信息。来源是 Process 层的关注点，不是 Domain 层的关注点。

```
✅ Event 携带：什么变了、变成了什么、什么时候变的
❌ Event 不携带：谁导致的、为什么变、接下来该做什么
```

### 原则4：层间可见性（Layered Visibility）

信号向上流动。下层不知道上层的存在。

```
core_data  → 产生数据变更信号（不知道谁在监听）
core       → 消费 core_data 信号 + 产生领域/布局信号（不知道 appframe 在监听）
appframe   → 消费 core 信号 + 产生视图信号（不知道插件在监听）
插件       → 消费 core/appframe 信号 + 产生插件信号
```

### 原则5：可扩展性（Extensibility）

新的状态类型、信号类型、订阅者可以在不修改现有代码的情况下加入。

组件声明式注册：
- 状态所有者声明"我拥有什么状态"
- 依赖者声明"我依赖什么状态"
- 系统自动建立传播路径

### 原则6：Event = 写的可观测性

Event 是写操作的副作用，不是独立操作。

```
每个 Event 必须对应一个 Write 操作
每个 Write 操作应该产生 Event（除非是本地状态变更）
没有 Write 的 Event 是设计错误
没有 Event 的 Write 是暗操作（需要评估是否需要可观测性）
```

### 原则7：BLoC Event ≠ 系统 Event

BLoC 模式中的"Event"是用户意图，等价于系统层面的 Command。

```
BLoC Event（如 NodeCreateEvent）= 用户意图 = 系统 Command
BLoC State（如 NodeState）     = 特性状态 = Query 结果
系统 Event（如 NodeDataChangedEvent）= 状态变更通知 = 写的可观测性
```

两者是不同层级的概念，不应共享通道或命名。

---

## 四、与 BLoC 模式的关系

### 6.1 三层状态管理

```
┌─────────────────────────────────────────────────────────┐
│ 层级1：Widget 局部状态                                    │
│   setState() / ValueNotifier                             │
│   范围：单个 Widget                                       │
│   同步机制：Flutter 重建                                  │
├─────────────────────────────────────────────────────────┤
│ 层级2：BLoC 特性状态                                      │
│   Bloc<Intent, State>                                    │
│   范围：单个特性（Graph、Node、Search）                    │
│   同步机制：BLoC 内部 Intent→State 转换                   │
├─────────────────────────────────────────────────────────┤
│ 层级3：系统全局状态                                        │
│   CQRS + Event                                           │
│   范围：跨特性、跨层、跨插件                                │
│   同步机制：Event 通知 + Query 刷新                        │
└─────────────────────────────────────────────────────────┘
```

### 6.2 BLoC 在信号架构中的角色

BLoC 是层级2的状态管理器，它桥接了层级1（Widget）和层级3（系统全局状态）：

```
Widget → BLoC.add(Intent) → BLoC 处理
                              ├──→ CommandBus.dispatch(Command)  ← 向层级3 发出写意图
                              ├──→ QueryBus.dispatch(Query)      ← 从层级3 读取状态
                              └──→ emit(State)                   ← 向层级1 推送状态
```

BLoC 同时是：
- 系统 Command 的**发起者**（将用户意图转化为 Command）
- 系统 Event 的**消费者**（接收状态变更通知）
- 系统 Query 的**发起者**（获取最新状态）
- Widget 状态的**提供者**（通过 BlocBuilder）

### 6.3 命名规范

为避免 BLoC Event 与系统 Event 的混淆：

```
BLoC 层面：
  Intent  — 用户意图（原 BLoC Event）
  State   — 特性状态（不变）

系统层面：
  Command — 写意图
  Event   — 写的可观测性
  Query   — 读请求
```

BLoC 的命名应从 `Bloc<Event, State>` 改为 `Bloc<Intent, State>`，
内部方法从 `on<NodeCreateEvent>` 改为 `on<CreateNodeIntent>`。
