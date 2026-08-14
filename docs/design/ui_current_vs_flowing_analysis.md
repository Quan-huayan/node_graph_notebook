# Current UI vs Flowing UI — 完整对比分析

> 本文档逐节对比 `docs/design/flowing_ui.md` 的设计理念与当前代码的实际实现，
> 标注哪些已经实现、哪些更完善、哪些完全未实现。

---

## 总体结论

| 维度 | 当前实现 | Flowing UI 设计 | 差距 |
|------|---------|----------------|------|
| Hook 系统 | ✅ 完善实现 | 仅有骨架描述 | **当前远超设计** |
| 插件架构 | ✅ 完善实现 | 未涉及 | **当前远超设计** |
| 事件系统 | ✅ 完善实现 | 未涉及 | **当前远超设计** |
| CQRS 模式 | ✅ 完善实现 | 未涉及 | **当前远超设计** |
| 布局算法 | ✅ 4种已实现 | 待澄清阶段 | **当前远超设计** |
| 坐标系 | ✅ 4模式+转换 | 未涉及 | **当前远超设计** |
| NodeTemplate | ⚠️ 基础框架 | 详细角色设计 | **设计远超当前** |
| All is Node | ❌ 未实现 | 核心哲学 | **完全未实现** |
| Hook is Node | ❌ 未实现 | 核心哲学 | **完全未实现** |
| Role/Act 模型 | ❌ 未实现 | 核心哲学 | **完全未实现** |
| 约束布局系统 | ❌ 未实现 | 统一约束求解 | **完全未实现** |
| 流动拖拽 | ❌ 未实现 | 事务性协议 | **完全未实现** |
| 渲染流(图->UI) | ❌ 未实现 | 容器→子→布局→覆盖层 | **完全未实现** |

**核心发现：当前实现与 Flowing UI 设计是在两条轨道上发展的。**

- 当前代码走的是 **传统 Flutter Widget 树 + 插件化 Hook 系统** 的路子，优势在插件化、DI、CQRS
- Flowing UI 设计走的是 **图结构驱动 UI 渲染** 的路子，优势在概念统一、灵活布局、节点流动

---

## 逐节对比

---

### 一、Flowing UI 的本质

#### 1.1 "UI 布局本身就是一个图结构"

| Flowing UI 设计 | 当前实现 |
|----------------|---------|
| 布局 = 动态图结构 | 布局 = `UIHookNode` 树（树结构，非图） |
| 变更 = 图拓扑变化 → 自动重渲染 | 变更 = `ChangeNotifier` + `Consumer` 重建 |
| 节点可以出现在任意 Hook | 节点可 `attachNode/detachNode/moveNode` |

**分析**：
- 数据层上，`UILayoutService` 支持节点跨 Hook 流动（`moveNode()`），这符合"流动"理念
- 但 UI 表现层上，当前是传统的 `HookRoleRegistry → Consumer → FlutterRenderer` 渲染管道，没有"图结构驱动 UI"的概念
- `UIHookNode` 是严格的**树**（每个节点一个 parent，子节点列表，无跨引用），不构成图

**结论**：❌ 未实现图结构理念。当前是树结构 + 手动事件通知，不是图结构变化自动重渲染。

#### 1.2 三大原则

| 原则 | 当前实现状态 |
|------|------------|
| 节点即内容 | ❌ 未实现。Node 是 `core_data` 的数据模型，但 UI 区域（Sidebar、Toolbar）没有对应 Node |
| Hook 即视图 | ⚠️ 部分实现。当前 Hook (`HookRoleBase`) 确实是视图，但它对应的是 `HookPointDefinition`（扩展点），不是 Node 的视图 |
| 流动即交互 | ❌ 未实现。当前拖拽只存在于 graph 插件内部的 `node_drag_controller.dart`，不是节点跨 Hook 流动 |

---

### 二、All is Node

#### 2.1 递归定义

| Flowing UI | 当前实现 |
|-----------|---------|
| 图是"节点+引用"的结构 | 图是 `Graph` + `Node` + `Connection` 三个独立模型 |
| "边"是 RelationshipNode | Connection 是独立模型，不是 Node 的子类 |
| 关系之间的关系也是 Node | 不存在此概念 |

**结论**：❌ 完全未实现。当前 `core_data` 中的 `Node`、`Graph`、`Connection` 是三个独立的互不继承的模型类。

#### 2.2 NodeReference

| Flowing UI | 当前实现 |
|-----------|---------|
| NodeReference 可以指向任何 Node | `core_data` 中存在 `NodeReference` 模型 |
| Not just "edges" — universal pointers | 当前仅作为节点间引用使用，不是通用的关系机制 |

**结论**：⚠️ 部分实现。`NodeReference` 存在但使用范围有限，不承担"统一关系机制"的角色。

#### 2.3 逻辑模型与物理模型

| Flowing UI | 当前实现 |
|-----------|---------|
| 逻辑模型：关系是 Node | 不存在 |
| 物理模型：索引从关系 Node 计算 | `_nodeToHookIndex` 等索引存在，但来源不是关系 Node |
| 索引只是缓存，可随时重建 | 索引是实时状态，存在持久化但无重建机制 |

**结论**：❌ 完全未实现。当前无"逻辑模型+物理模型"的分离概念。

---

### 三、Hook is Node

#### 3.1 一体两面

| Flowing UI | 当前实现 |
|-----------|---------|
| Hook = Node 的前端（视图） | `HookRoleBase` 是视图，但它没有对应的 `core_data Node` |
| Node = Hook 的后端（数据） | `UIHookNode` 是布局区域，不是 `core_data` 中的数据 Node |
| Hook 一定有对应的 Node | ❌ 不存在此映射 |

**结论**：❌ 完全未实现。当前的 `HookRoleBase` 和 `Node` 是两个独立的概念体系，没有对应关系。

#### 3.2 推论

| Flowing UI | 当前实现 |
|-----------|---------|
| Sidebar 是一个 Node | ❌ SidebarLayoutHook 没有对应 Node |
| Graph 是一个 Node | ❌ GraphPlugin 没有对应 Node |
| Toolbar 是一个 Node | ❌ 工具栏没有对应 Node |
| 所有 UI 区域都有对应 Node | ❌ 无此概念 |

**结论**：❌ 完全未实现。

#### 3.3 前端图与后端图

| Flowing UI | 当前实现 |
|-----------|---------|
| 前端图是后端图的投影 | 不存在此概念 |
| 带层级过滤的映射 | 不存在此概念 |
| 后端图：顶点=Node, 边=NodeReference | 当前图模型是 AdjacencyList |

**结论**：❌ 完全未实现。当前的前端 UI 树和后端数据结构完全独立，不存在投影关系。

#### 3.4 RelationshipNode 统一

| Flowing UI | 当前实现 |
|-----------|---------|
| 所有关系类型是 RelationshipNode | ❌ Connection 是独立模型 |
| relationshipType 区分语义 | ❌ Connection 没有统一的 type 字段 |
| 'dependency', 'contains', 'ui-contain', 'ui-connect', 'source', 'target' | ❌ 无此枚举 |

**结论**：❌ 完全未实现。

---

### 四、Role 模型

#### 4.1 角色的本质

| Flowing UI | 当前实现 |
|-----------|---------|
| 角色 = 节点在特定上下文中的身份 | ❌ 无此概念 |
| 非固有属性，上下文相关 | ❌ 无此概念 |
| 文件夹节点在不同Hook扮演不同角色 | ❌ 在graph和sidebar中由各自渲染器决定，不是角色驱动 |

**结论**：❌ 完全未实现。

#### 4.2 角色匹配

| Flowing UI | 当前实现 |
|-----------|---------|
| offeredRoles ∩ compatibleRoles ≠ ∅ | ❌ 无此概念 |
| 双向声明的匹配机制 | ❌ 无此概念 |

**结论**：❌ 完全未实现。

#### 4.3 角色与视图

| Flowing UI | 当前实现 |
|-----------|---------|
| 视图由 Hook 渲染器根据角色决定 | ⚠️ 当前渲染器能渲染不同形态，但不是角色驱动的 |
| 角色决定视图形态、尺寸、关系类型、布局约束 | ❌ 角色的概念不存在 |

**结论**：❌ 完全未实现。

#### 4.4 Act：行为选择

| Flowing UI | 当前实现 |
|-----------|---------|
| Node 可以 act 为 node/connection/container/hider | ❌ 无此概念 |
| AI Node 主动选择 act | ❌ 无此概念 |
| connection act 必须有 source/target reference | ❌ 无此概念 |

**结论**：❌ 完全未实现。

#### 4.5 可组合 Role 模型

| Flowing UI | 当前实现 |
|-----------|---------|
| 文件夹 Node = node + container + hider | ❌ 无此概念 |
| Role 组合规则和前提条件 | ❌ 无此概念 |
| container + connection 互斥 | ❌ 无此概念 |

**结论**：❌ 完全未实现。

---

### 五、NodeTemplate 设计

#### 5.1 职责定义

| Flowing UI | 当前实现 |
|-----------|---------|
| 定义数据结构、可扮演角色、容器行为 | `NodeTemplate` 定义了 factory 和 metadata |
| compatibleRoles/offeredRoles | ❌ 不存在 |

**结论**：⚠️ 当前有 `NodeTemplate` 的基础框架（有 `NodeTemplateRegistry`、`id`、`name`、`category`、`factory`、`params`、`metadata`），但缺少 Flowing UI 设计中的角色声明机制。

#### 5.2 与 Hook 渲染器关系

| Flowing UI | 当前实现 |
|-----------|---------|
| NodeTemplate 声明角色 | ❌ 当前不声明 |
| Hook 渲染器根据角色决定渲染 | ❌ 当前无角色概念 |

**结论**：❌ 与 Role 模型相关，完全未实现。

#### 5.3 匹配机制

| Flowing UI | 当前实现 |
|-----------|---------|
| 白名单约束 + 角色匹配 | `NodeTemplate` 无白名单 |
| 双向声明 | ❌ 不存在 |

**结论**：❌ 完全未实现。

---

### 六、渲染流

#### 6.1 Container 为中心的渲染流

| Flowing UI | 当前实现 |
|-----------|---------|
| Container 收集子节点 → 按 act 分类 → 布局 → 覆盖层 → 递归 | ⚠️ `FlutterRenderer._renderDefaultContainer()` 确实递归渲染子节点，但缺乏 act 分类和覆盖层阶段 |
| 渲染流从图结构推导 | ❌ 当前从 Hook 树推导 |

**结论**：⚠️ 渲染的递归结构类似，但数据源和阶段划分不同。

**当前 `FlutterRenderer.render()`**:
```
render(hook, context)
  → 查找 hookPointId 对应的 HookRoleBase
  → 调用 hook.render(hookContext) 或递归默认容器
  → 默认容器递归子节点 + 渲染附加节点
  → 无覆盖层阶段
```

**Flowing UI `渲染流`**:
```
Container.collectChildren()
  → sortByAct() → [layout] + [overlay]
  → layout phase → LayoutResult
  → overlay phase → paints on LayoutResult
  → recurse containers
```

#### 6.2 三个核心问题

| Flowing UI 核心问题 | 当前答案 |
|-------------------|---------|
| Layer 由谁决定？ | 当前由 `HookRoleBase.render()` 自己决定，没有 Container 概念 |
| 渲染数据怎么来？ | 从 `HookContext.data` map 传递 |
| 渲染结果到哪里去？ | 直接返回 Widget/Component，无 LayoutResult 传递机制 |

**结论**：❌ 三个核心问题在 Flowing UI 中已经界定清楚，但当前实现完全不同。

#### 6.3 Graph 视图渲染示例

| Flowing UI | 当前实现 |
|-----------|---------|
| GraphNode 作为 container，GraphNode→FolderNode(ui-contain) | ❌ Graph 视图由 graph 插件提供，不在 Hook 树的渲染中 |
| ConnectionNode 查询 LayoutResult 绘制曲线 | ❌ Connection 曲线在 `connection_renderer.dart` 中直接绘制的，不是从 LayoutResult 查询的 |
| FolderNode 递归 | ❌ folder 的逻辑不参与图渲染的递归 |

**结论**：❌ 实现方式完全不同。当前 graph 渲染由 `graph` 插件的 Flame 组件直接处理，不通过 Hook 树的渲染流。

---

### 七、布局协议

#### 7.1 统一约束求解

| Flowing UI | 当前实现 |
|-----------|---------|
| 统一约束求解系统 | 当前是位置模式（absolute/proportional/sequential/fill）+ 简单计算器 |
| 不是多模式组合 | 当前恰恰是多模式组合 |
| 约束自动重算 | 当前需要手动调用布局计算 |

**结论**：❌ 完全不同的思路。当前是"预定义位置模式 + 简单计算器"，Flowing UI 是"约束求解 + 自动布局"。

#### 7.2 四种实现对比

| 布局方式 | 当前实现 | Flowing UI 设计 |
|---------|---------|----------------|
| 绝对定位 | ✅ `FlameAbsoluteCalculator` | 无直接对应 |
| 顺序排列 | ✅ `FlameSequentialCalculator` | 无直接对应 |
| 流式布局 | ✅ `FlameFlowCalculator` | 无直接对应 |
| 网格布局 | ✅ `FlameGridCalculator` | 无直接对应 |
| 约束求解 | ❌ 无 | ✅ 核心思想 |

**结论**：当前实现了4种经典布局算法，但 Flowing UI 设想的是更高维度的约束求解系统。**当前在这一节更具体可实现**，但**Flowing UI 的约束求解愿景更宏大**。

#### 7.3 待澄清

Flowing UI 中列为"待澄清"的有：

| 待澄清点 | 当前实现状态 |
|---------|------------|
| 约束类型体系 | ❌ 未实现 |
| 约束求解算法选择 | ❌ 未实现 |
| 约束与关系类型映射 | ❌ 未实现 |
| 参考 Flutter 约束模型 | ❌ 未实现 |

**结论**：这些待澄清点当前仍然未实现。

---

### 八、流动交互协议

#### 8.1 事务性拖拽

| Flowing UI | 当前实现 |
|-----------|---------|
| Drag Start → 开启视觉事务 | ❌ 无事务概念 |
| Drag Move → 实时预览 + 形态渐变 | ❌ 无跨 Hook 预览 |
| Drop → dispatch Command + 动画 | ⚠️ graph 插件内有 `MoveNodeCommand`，但不是跨 Hook 的 |
| Cancel → 回滚 + 动画 | ❌ 无回滚 |

**分析**：
- 当前 `graph` 插件有 `node_drag_controller.dart` 和 `drag_feedback.dart`，处理的是图视图**内部的**节点拖拽
- `UILayoutService.moveNode()` 支持跨 Hook 移动的数据操作，但完全没有对应 UI 交互

**结论**：❌ 完全未实现跨 Hook 的事务性拖拽协议。

#### 8.2 数据层与视图层分离

| Flowing UI | 当前实现 |
|-----------|---------|
| MoveNodeCommand 是原子操作 | ✅ `MoveNodeCommand` 在当前 handler 中实现了 `detachNode + attachNode` |
| 视图层是纯动画效果 | ❌ 视图层数据操作和动画没有分离 |

**结论**：⚠️ 数据层已有 Command 机制，但视图层的动画分离未实现。

#### 8.3 形态渐变

| Flowing UI | 当前实现 |
|-----------|---------|
| 拖拽过程中节点渐变形态 | ❌ 不存在 |
| morphProgress = lerp(source, target) | ❌ 不存在 |
| 外壳属性可插值，内部结构切换 | ❌ 不存在 |

**结论**：❌ 完全未实现。

#### 8.4 渲染分配协议

| Flowing UI | 当前实现 |
|-----------|---------|
| 系统层协调者 | ❌ 无 DragController 的跨 Hook 版本 |
| 源 Hook 渲染空位 | ❌ 无此概念 |
| 目标 Hook 渲染预览 | ❌ 无此概念 |
| 全局 Overlay 渲染拖拽影像 | ❌ 无此概念 |

**结论**：❌ 完全未实现。

---

### 九、待澄清问题 — 当前状态对比

| Flowing UI 待澄清 | 当前状态 |
|------------------|---------|
| Role/Act 模型 | ❌ 未实现，仍待澄清 |
| 约束类型体系 | ❌ 未实现，仍待澄清 |
| 约束求解算法 | ❌ 未实现，仍待澄清 |
| 约束与关系映射 | ❌ 未实现，仍待澄清 |
| 布局信息存储位置 | ❌ 未解决（当前存 SharedPreferences） |
| Flame vs Flutter 对比 | ✅ 已有双渲染器架构 |
| 双框架结合方式 | ✅ 已有 RendererBase<T> 抽象 |
| Graph 视图渲染策略 | ✅ 已有 graph 插件的 Flame 渲染 |
| 跨框架拖拽 | ❌ 未实现 |
| HookRenderer 接口 | ⚠️ 有 HookRoleBase 但不匹配 Flowing UI |
| 与现有 Hook 过渡方案 | ❌ 未涉及 |
| 集成到 appframe 步骤 | ❌ 未涉及 |

---

## 当前相比 Flowing UI 更完善的方面

以下方面当前实现比 Flowing UI 设计文档更具体、更完善：

### 1. 插件系统 (PluginManager + ServiceRegistry)

Flowing UI 设计对此只字未提，但当前有一套非常完善的插件架构：

- **`PluginManager`** — 插件生命周期管理（load/enable/disable/unload）
- **`ServiceRegistry`** — 统一的 DI 容器，支持 Provider 集成
- **`PluginContext`** — 给插件的沙盒环境
- **`PluginDependencyResolver`** — 插件依赖解析
- **`PluginCommunication`** — 插件间通信
- 插件注册 CommandHandler、QueryHandler、Bloc、Service 的完整流程
- **当前设计优于 Flowing UI**

### 2. Hook 注册体系 (HookRoleRegistry)

Flowing UI 只简单提到 "HookRenderer"，当前实现远比它完善：

- **`HookPointDefinition`** — 扩展点定义（id, name, description, category）
- **`HookWrapper`** — Hook 运行时包装（含生命周期管理器）
- **`HookLifecycleManager`** — 状态机 (uninitialized → initialized → enabled/disabled → disposed)
- **`HookPriority`** — 优先级数值系统 (0~1000)
- **`HookAPIRegistry`** — 跨 Hook API 调用
- **当前设计优于 Flowing UI**

### 3. CQRS + 事件系统

Flowing UI 未涉及，但当前有完整的实现：

- **`CommandBus`** — 命令分发 + 中间件管道 + 自动事件发布
- **`QueryBus`** — 查询分发 + LRU 缓存
- 6个布局事件（NodeAttachedEvent, NodeDetachedEvent, NodeMovedEvent 等）
- 中间件：Logging、Transaction、Validation、Undo、Performance
- **当前设计优于 Flowing UI**

### 4. 双渲染器架构

Flowing UI 在"待澄清"中列出了"Flame vs Flutter 优缺点对比"，但当前已经实现了：

- **`RendererBase<T>`** — 泛型渲染器接口
- **`FlutterRenderer`** — Widget 输出，与 Hook 注册系统集成
- **`FlameRenderer`** — Component 输出，与布局计算器集成
- **当前设计优于 Flowing UI**

### 5. 四种布局计算器

Flowing UI 在"待澄清"中还在讨论"约束求解算法的选择"，但当前已经有：

- `FlameAbsoluteCalculator` — 绝对坐标
- `FlameSequentialCalculator` — 顺序排列
- `FlameFlowCalculator` — 流式布局（类似 FlexWrap）
- `FlameGridCalculator` — 网格布局
- `FlameLayoutCalculatorRegistry` — 注册表模式
- **当前设计优于 Flowing UI**

### 6. 坐标系统

Flowing UI 未专门定义坐标系统，但当前有完善的：

- `LocalPosition` — 4种模式（absolute/proportional/sequential/fill）
- `GlobalPosition` — 屏幕空间坐标
- `CoordinateSystem` — 静态工具类（localToGlobal/globalToLocal/convertBetweenHooks）
- **当前设计优于 Flowing UI**

### 7. 布局持久化

Flowing UI 未涉及，但当前有：

- 通过 `SharedPreferences` 持久化 `_nodeToHookIndex`
- `clearPersistedLayout()` 清除
- **当前设计优于 Flowing UI**

---

## 当前相比 Flowing UI 完全未实现的方面

### 1. "All is Node" 统一哲学

当前最大的差距。三个独立模型 vs 统一 Node：

```
当前: Node | Connection | Graph        (三个独立模型)
Flowing UI: 只有 Node                  (统一模型)
  - DataNode = 数据节点
  - RelationshipNode = 关系节点
  - NodeReference = 统一引用
```

**影响**: 模型层需要重构，涉及 `core_data` 包的核心数据模型。

### 2. "Hook is Node" 映射

当前 Hook 和 Node 没有对应关系，Flowing UI 要求每个 Hook 都有对应的 Node：

```
当前: HookRoleBase → HookPoint  (对应扩展点)
Flowing UI: HookRoleBase → Node  (对应数据节点)
```

**影响**: 需要建立 Hook ↔ Node 的映射关系，改变 `HookRoleBase` 的生命周期。

### 3. Role/Act 模型

完全不存在。这不仅仅是添加几个字段，而是整套节点行为体系。

**影响**: 需要在 `NodeTemplate` 中声明角色，建立匹配机制，实现 act 调度。

### 4. 约束求解布局

当前的 4 种计算器和 Flowing UI 的"约束求解"是不同维度的：
- 当前是**预设算法 × 参数配置**
- Flowing UI 是**声明式约束 × 自动求解**

**影响**: 需求整套约束类型体系 + 求解器算法。

### 5. 事务性流式拖拽

当前拖拽只存在于 graph 插件内部，Flowing UI 要求跨 Hook 的完整协议。

**影响**: 需要 DragController 跨 Hook 协调、形态渐变、事务回滚。

### 6. 图结构驱动的渲染流

当前渲染流是 `Hook树 → HookRoleBase → Widget`，Flowing UI 是 `图结构 → Container → 角色分类 → 布局 → 覆盖层`。

**影响**: 重构渲染管道。

---

## 关键矛盾：中间态的问题

当前系统的最大问题是**设计方向和 Flowing UI 不同步**：

```
当前实际方向:
  "传统 Flutter Widget树 + 插件化Hook注入"
  → 强在: 插件化、DI、CQRS、模块化
  → 弱在: 概念不统一、布局不灵活、拖拽有限

Flowing UI 设计方向:
  "图结构驱动的声明式UI"
  → 强在: 概念统一、布局灵活、流动自然
  → 弱在: 约束求解复杂、角色模型需大量设计
```

Flowing UI 文档本身没有给出从"A到B"的过渡方案（9.4节标记为"待澄清"），而当前实现选择了 **A 的完全体**（传统树结构插件化）而不是 **走向 B**（图结构驱动）。

### 具体矛盾点

| 主题 | 当前选择 | Flowing UI 要求 | 冲突程度 |
|------|---------|----------------|---------|
| Node 模型 | 独立模型 (Node+Connection+Graph) | 统一 Node | 🔴 直接冲突 |
| UI 结构 | Hook 树 | 前端图投影 | 🔴 直接冲突 |
| Hook | 对应 HookPoint | 对应 Node | 🟡 可调和 |
| Role | 无 | 核心机制 | 🟡 可添加 |
| 布局 | 计算器 | 约束求解 | 🟡 可替换 |
| 拖拽 | 图内拖拽 | 跨 Hook 流动 | 🟡 可增强 |
| 插件系统 | 非常完善 | 未涉及 | 🟢 无冲突 |
| CQRS | 非常完善 | 未涉及 | 🟢 无冲突 |
| 双渲染器 | 已实现 | 待澄清 | 🟢 无冲突 |

---

## 结论

1. **当前实现和 Flowing UI 不是"部分实现 vs 完全设计"的关系**，而是**两个不同方向的实践**

2. **当前超出的**：插件系统、Hook 注册体系、CQRS+事件、双渲染器、4种布局算法、坐标系、持久化
   → 这些可以作为 Flowing UI 实现的**基础设施**

3. **当前缺失的**：All is Node、Hook is Node、Role/Act 模型、约束求解、事务性拖拽、图驱动渲染
   → 这些是 Flowing UI 的核心价值

4. **最大差距**：Node 模型不统一（三个独立模型 vs 统一 Node），这是最底层的差异
