# 信号架构重构方案

> 本文档基于 [signal_architecture.md](../design/signal_architecture.md) 的设计原则，
> 分析当前架构的差距并制定重构方案。
> 基于 2026-05-06 架构讨论得出。

---

## 一、当前架构的差距

### 1.1 状态归属违规

| 违规 | 位置 | 问题 |
|------|------|------|
| Service 直接写 Repository | `NodeServiceImpl.createNode()` | Service 不是状态所有者 |
| Repository 暴露写方法 | `GraphRepository.addEdge()/removeEdge()` | 绕过 Command 直接写 |
| AI/Lua 直接操作 Repository | `AIService`、`LuaAPI` | 非状态所有者直接写 |
| Repository 通过 Provider 暴露 | `app.dart` Provider 树 | 任何组件可直接写 |
| UILayoutService 写操作无 Command | `attachNode()/detachNode()/moveNode()` | 外部请求应走 Command |

### 1.2 依赖传播缺失

| 缺失 | 说明 |
|------|------|
| 无声明式依赖注册 | BLoC 手动订阅 eventStream 并过滤 |
| 无自动传播路径 | 信号传播靠硬编码的 `if (event is ...)` 过滤 |
| 依赖关系隐式 | 谁依赖谁只能从代码推断 |

### 1.3 意图与事实混淆

| 违规 | 位置 | 问题 |
|------|------|------|
| Event 无对应 Write | `PluginLoadedEvent` | 没有 Write 操作支撑 |
| Write 无对应 Command | `UILayoutService.attachNode()` | 直接修改状态 |
| undo() 绕过管道 | `CommandBus.undo()` | 跳过验证和审计 |
| publishEvent() 公开 | `CommandBus.publishEvent()` | 允许无 Write 的 Event |
| CommandResult 携带数据 | `CommandResult<T>` | 模糊 Command/Query 边界 |

### 1.4 层间可见性违规

| 违规 | 位置 | 问题 |
|------|------|------|
| Repository 向上暴露 | Provider 树 | 上层直接访问下层 |
| getServiceDirect() | `ServiceRegistry` | 绕过 DI |
| core 依赖 Flutter | `UILayoutService` → `SharedPreferences` | 下层依赖上层框架 |
| core_data 依赖 Flutter | `NodeRepositoryFs` → `Size` | 数据层依赖 UI 框架 |

### 1.5 可扩展性缺失

| 缺失 | 说明 |
|------|------|
| Hook 点硬编码 | `UILayoutService._registerStandardHookPoints()` |
| 插件列表硬编码 | `BuiltinPluginLoader` |
| 信号类型不可扩展 | 添加新 Event 需修改多处代码 |

### 1.6 写可观测性违规

| 违规 | 说明 |
|------|------|
| Event 不是 Write 的副作用 | `PluginLoadedEvent` 无 Write 支撑 |
| Write 不产生 Event | `GraphRepository.addEdge()` 直接写不通知 |
| Event 携带来源信息 | `CommandUndoneEvent` 携带 Command 引用 |
| 两类 Event 混流 | 领域 Event 和基础设施 Event 共享 eventStream |

### 1.7 命名混淆

| 违规 | 说明 |
|------|------|
| BLoC 用 Event 命名意图 | `NodeCreateEvent` 实为用户意图 |
| 两类信号共享通道 | BLoC 意图和系统通知都通过 `CommandBus.eventStream` |

---

## 二、核心矛盾

当前架构的根本矛盾：

> **CommandBus 试图同时承担"意图管道"和"事实通道"两个职责，导致两者都做不好。**

- 作为意图管道：`publishEvent()` 允许绕过意图直接发布事实
- 作为事实通道：`dispatch()` 的命令结果可以携带数据（模糊了 Query 边界）
- 作为两者混合：`eventStream` 混合了领域事实和基础设施通知

---

## 三、重构方向

### 3.1 三通道分离

将 CommandBus 的混合职责拆分为清晰的三个通道：

```
CommandChannel — 写意图管道
  · dispatch(Command) → Handler → 状态所有者.写()
  · 移除 publishEvent() 公开方法
  · 移除 CommandResult 的数据携带能力

EventChannel — 写的可观测性通道
  · 状态所有者.写() 后自动发出 Event
  · Event 沿依赖图传播
  · 完全解耦发布者和订阅者

QueryChannel — 读请求通道
  · dispatch(Query) → Handler → 状态所有者.读()
  · 可缓存、可优化
  · 直接访问，不解耦
```

### 3.2 状态所有者改造

每个状态所有者需要：
1. 只暴露读接口（Query Handler 可访问）
2. 写操作只能通过 Command Handler 触发
3. 写操作完成后自动发出 Event

```
改造前：
  NodeRepository.save(node)  → 任何代码可直接调用
  NodeRepository.delete(id)  → 任何代码可直接调用

改造后：
  NodeRepository.save(node)  → 仅 CreateNodeHandler / UpdateNodeHandler 可调用
  NodeRepository.delete(id)  → 仅 DeleteNodeHandler 可调用
  save/delete 完成后 → 自动发出 NodeStateChangedEvent
```

### 3.3 依赖声明系统

引入 StateRegistry，组件声明式注册依赖：

```
StateRegistry.register(
  owner: NodeRepository,
  stateType: NodeState,
)

StateRegistry.declareDependency(
  dependent: GraphBloc,
  dependsOn: [NodeState, GraphState],
)

自动推导传播路径：
  NodeState 变更 → StateRegistry 通知 GraphBloc, SidebarBloc, ...
```

### 3.4 BLoC 命名重构

```
改造前：Bloc<NodeCreateEvent, NodeState>
改造后：Bloc<CreateNodeIntent, NodeState>

改造前：on<NodeCreateEvent>((event, emit) => ...)
改造后：on<CreateNodeIntent>((intent, emit) => ...)
```

### 3.5 层间依赖清理

```
core_data → 移除 Flutter 依赖（Size → 自定义 Size 类）
core      → 移除 SharedPreferences 依赖（通过接口抽象）
appframe  → 移除直接 Repository 访问（通过 Command/Query）
```

---

## 四、重构优先级

### P0：信号通道分离

1. 从 CommandBus 中提取 EventChannel
2. 移除 `publishEvent()` 公开方法
3. 状态所有者写操作后自动发出 Event
4. CommandResult 改为不携带数据

### P1：状态归属修复

1. Repository 写方法设为内部可见（仅 Handler 可调用）
2. Service/AI/Lua 改为 dispatch Command
3. 移除 Provider 树中的 Repository 暴露

### P2：依赖声明系统

1. 实现 StateRegistry
2. BLoC 声明式注册依赖
3. 自动传播路径推导

### P3：命名与层间清理

1. BLoC Event → Intent 重命名
2. core_data 移除 Flutter 依赖
3. core 移除 SharedPreferences 直接依赖
