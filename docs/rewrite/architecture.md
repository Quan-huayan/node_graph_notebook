# architecture.md — 落地架构

> 前置：[[00-philosophy]] | [[01-responsibilities]] | [[02-model-presentation]] | [[03-interaction-signals]] | [[04-glue-engineering]]
> 本文是**落地层**：回答"谁来写、写在哪、怎么跑起来"。5 篇设计文档回答"是什么、为什么"。
> 实现者只做翻译，不做设计。每一步有具体类、具体文件、具体失败行为。
>
> **落地判据**：
> 1. 五个核心时序无省略，不允许"由实现者决定"
> 2. 每个方法有调用方和失败行为
> 3. 每个 10⁶ 数字有机制背书
> 4. 逐段可追溯回设计文档的决策；追溯断档 = 设计缺口，先回填设计文档

---

## 1. 技术选型与否决项

| 选型 | 决定 | 理由 | 被否决的替代 |
|---|---|---|---|
| UI 框架 | Flutter（保留） | 现有资产带走、跨平台 | — |
| 画布渲染 | Flutter widgets + InteractiveViewer（M6 落地）；Flame 栈 = M7+ 资产 | 已带走资产：LOD/视锥裁剪/QuadTree——LOD/视锥裁剪在现渲染栈**无实现 [计划]**；"10⁶ 性能验证过"不实——10⁶ 验证 [计划] | Flutter CustomPainter（无现成 LOD/裁剪栈） |
| 结构存储 | sidecar JSON 文件（`<id>.node.json`，哈希分区） | 可 diff、可 git、可外部管理（00 §3.3）；10⁶ 分区后单目录有界 | 集中 index 单文件（10⁶ 单文件不可维护）；SQLite（锁死数据，违背文件树主张） |
| 内容存储 | 文件树（任意类型） | 用户可编辑、git 可管理 | 数据库 blob（不可外部访问） |
| 外观状态 | JSON 文件（UIStateStore 实现） | 量小（可视窗口），KV 足够 | 数据库（过度） |
| 身份 | uuid（Node.id；别名表内部 id） | 稳定身份，路径只是别名（00 §3.4） | 内容寻址（移动即失效） |
| 依赖管理（DI/扩展点/插件生命周期） | **Plugon v2**（并入 workspace 为 `packages/plugon`） | 本生态成熟基础设施：117 测试、owner 清理/拓扑序/回滚完备、架构文档面向 Flowing UI/Hook 设计 | 自研 DI（重蹈 v1 覆辙） |

**技术风险清单**：
1. Flame 与 Flutter 双树交互（Hook 位置无关渲染进 overlay）——M3 早期验证
2. 10⁶ sidecar 文件的冷启动加载——懒加载 + 窗口化；窗口化渲染已接线（P2-4，01 #54），10⁶ 数字未验证 [计划]（基准仅 30k，CI 每 push）
3. Lua 实现 Concept 接口的绑定成本——Concept 接口冻结前用 Lua 原型验证

## 2. 包结构与依赖

```
packages/
  core_data/        lib/src/models/{node,concept,graph,ui_state_store,hook}.dart
  core/             lib/src/registry/{concept_registry}.dart          # 查询侧（注册归 plugon）
                    lib/src/matching/{specificity_priority}.dart     # 匹配优先序
                    lib/src/fallback/{fallback_concept}.dart         # 兜底 Concept
                    lib/src/cycle/{acyclic_checker}.dart             # 环校验
                    lib/src/invalidation/{hook_index,router}.dart    # nodeId→hookId
                    lib/src/command/{command_bus,handler}.dart       # 路由侧（注册归 plugon）
                    lib/src/ui_manager/{materializer,window}.dart    # 物化/窗口化策略
                    # DI / ExtensionRegistry / PluginManager / Plugin 契约 → 依赖 package:plugon
  appframe/         lib/src/render/{flutter_render_context}.dart
                    lib/src/store/{fs_graph,fs_ui_state_store,file_layer,sidecar_store}.dart
                    lib/src/interaction/{drag_controller,flight_shell}.dart
  plugins/
    folder/ graph/ editor/ ai/ lua/ converter/ search/ i18n/ settings/ market/ data_recovery/
```

依赖方向（严格单向，CI 校验 `tool/check_imports.dart`，反向依赖即失败；P2-2 已落地——lib/test 分层声明校验 + 方向表，`.github/workflows/ci.yml` 每 push）：

```
core_data ← core ← appframe ← plugins/*
```

**创建理由**：core_data 零依赖（契约测试纯 Dart）；core 无 Flutter（Lua、测试、未来非 Flutter 壳可用）；appframe 是唯一 Flutter 依赖点；plugins 互相不依赖（通信走 Command + 索引）。

## 3. 核心类协作

| 类 | 关键成员 | 调用方 → 被调用方 | 失败行为 |
|---|---|---|---|
| `ConceptRegistry` | `register/unregister/findFor` | Plugin.onLoad → register；UI 管理器物化 → findFor | 无命中 → 兜底 Concept（永不抛） |
| `HookIndex` | `Map<String, Set<String>> _index`；`materialize(hookId)` `onNodeChanged(nodeId)` | Handler 返回 → UI 管理器 → onNodeChanged | 目标未物化 → 仅更新索引行，无渲染 |
| `WindowManager` | `materialize(nodeId, container)` `recycle(hookId)` | 视口变化 → materialize/recycle | 回收非物化 Hook → 静默 no-op |
| `CommandBus` | `register/dispatch` | Hook → dispatch；中间件管道包裹 Handler | 环校验失败 → CycleError → CommandResult.failure |
| `AcyclicChecker` | `check(affectedRefs, graph)` | 写命令 Handler → 落盘前调用 | 返回 cycle path；Handler 包装为用户文案 |
| `FSTGraph` | `get/getMany/save/delete/getByMetadata`（sidecar 分区目录） | Handler → save；窗口物化 → getMany | 磁盘错误 → IOException → WriteResult.failure |
| `FlightShell` | `present(overlay, from, to)` `commit()/abort()` | DragController.drop → present | 动画中断 → abort → 影像回弹，无副作用 |
| `ServiceCollection` / `ServiceProvider`（plugon） | `owned(id)` / `addXxx` / `get` / `disposeOwner` | Plugin.registerServices → 注册；跨插件 → `get<T>()` | 未注册 → ServiceNotFoundException；循环 → CircularDependencyException |
| `PluginManager`（plugon） | `loadPlugin` / `enablePlugin` / `unloadPlugin` | 宿主启动 → loadPlugin（拓扑序/占位/回滚） | 失败 → lastError + 回滚注册 + 重抛，可重试 |
| `WriteNotifier` | `attach/detach(listener)` | CommandBus 完成写 → 交给 UI 管理器 / 插件订阅 | 订阅者泄漏 → onUnload 必须 detach（硬规则） |

## 4. 启动序列

对照现有 DI 顺序（CLAUDE.md），差异标 `NEW` / `REMOVED`：

```
1. SharedPreferences              保留
2. StoragePathService             保留（数据根目录）
3. FSTGraph / FileLayer / FSUIStateStore   NEW（替代旧仓库，含 sidecar 分区）
4. CommandBus + 中间件管道（logging/undo/validation/transaction）  保留实现，挂到新 CommandBus
5. ConceptRegistry + AcyclicChecker   NEW
6. HookIndex / WindowManager / UIManager   NEW（替代旧 HookRegistry）
7. ServiceCollection + ServiceProvider（plugon）   NEW（注册 → owned 视图）
8. PluginManager（plugon）        loadPlugin：占位 → owned(id) 注册服务 → registerExtensions
                                  贡献 Concept/Handler → onLoad → enablePlugin
9. BuiltinPluginLoader           保留壳，加载新插件集
10. 前端图建立：根 Node → findFor → createHook → 递归（物化按需，窗口化）   NEW
```

失败行为：任一步失败 → 数据恢复流程（保留现有 data_recovery 思路：备份 + 校验 + 修复命令），不崩溃启动。

## 5. 关键时序（5 条）

### 5.1 物化（首帧 / 视口进入）

```
视口变化 → UIManager.onViewportChanged(rect)
  → for visible nodeId in queryNodes(rect):        # 空间索引（QuadTree 带走）
      if WindowManager.isMaterialized(nodeId): continue
      concept = ConceptRegistry.findFor(node)
      hook = concept.createHook(node, HookContext(kind))
      HookIndex.materialize(hook.hookId, nodeId)
      WindowManager.attach(hook, containerHook)
      hook.render(renderContext)                    # 位置无关
  首帧预算：10⁶ 节点 → 视口内物化 ≤ 数千 Hook，单帧内完成 [计划：毫秒数字未测]
```

**P2-4 接线回填（2026-08-13，01 #54）**：`onViewportChanged` 的生产触发方已接线——画布相机变化（平移/缩放/窗口 resize）→ 防抖 300ms 推送，矩形 = 相机矩阵对 LayoutBuilder 真实视口尺寸的逆变换；HostRuntime 缺省 = `QuadTreeViewportQuery`（不再空实现）；画布渲染 = 可见集（§7 机制侧落地）。未交付 [计划]：离视口回收（`recycle` 无调用方）、10⁶ 增量索引（查询全量重建 O(n)）。

### 5.2 失效广播（改标题 → 全部视图重渲染）

```
Handler.save(node) 落盘成功
  → 返回 WriteResult{affectedNodeIds, changeKind}    # 03 §四
  → WriteNotifier 交给 UIManager（写后通知，单播桥）
  → UIManager.onNodeChanged(nodeIds)
  → hookIds = HookIndex.lookup(nodeId)              # O(1)
  → for hookId in hookIds (仅已物化):
      concept 反应: hook.reloadMetadata() → hook.dirty = true
  → 下一帧: 渲染循环只重绘 dirty Hook
  增量粒度: changeKind=structure → 树重挂; data → 重绘
  10⁶ 背书: 未物化节点变更 = 索引更新一行；广播 O(已物化 Hook 数)
```

**UI 侧落地（M7.1 回填）**：onWriteResult 失效路由后向呈现层发
`InvalidationEvent{changeKind, nodeIds}`（结构/数据各一次；ui 不发）→
widget 层（HookView / 画布成员卡片）按自身 nodeId **定向重建**（只命中
节点，架构 §7"每帧渲染 Hook 数 ≤ dirty 集合"的 UI 侧近似）；渲染的是
**物化 Hook 实例**（重建不重派生，无 findFor/createHook），Hook render
时重读自己 Node（不持有陈旧快照）。未物化节点变更 = 索引/事件一行，
无渲染成本。画布级刷新 = 结构事件（成员/连接增删）；data 由成员卡片
定向处理。

**ui 写路径（M7.2 回填，02 §2.3 失效语义落地）**：UIStateStore 直写
（判据② 外观）不发失效事件；**写入方 = 渲染方**（画布自身拖动）本地
直刷；**外部写入方**（可见性对话框等）→ UIStateStore 观察者通道
（attach/detach）→ 渲染方按关心前缀（`position.graph.`）定向刷新——
"管理画布对话框"即走此路径（01 拍板 #22"宿主据此刷新画布"的机制化）。

### 5.3 拖拽提交（侧边栏重排 = 数据命令）

```
DragController.onDrop(draggedNodeId, targetContainerHook, dropPoint)
  1. targetContainer.concept.askDropSemantics(node) → DataMove()
  2. AcyclicChecker.check(newRefs, graph) → 命中 → 拒绝 → FlightShell.abort() 回弹
  3. commandBus.dispatch(MoveNodesCommand(...))
  4. FolderMoveHandler.handle():
     a. AcyclicChecker.check(...)      # 二次校验（双保险）
     b. graph.save(folderA), graph.save(noteB)
     c. uiStateStore.set('expand.<folderA.id>', false)
     d. return CommandResult.ok
  5. nodeChanged(folderA, noteB) → 失效广播（5.2）→ 侧边栏 + 画布 Hook 重渲染
  6. FlightShell.present(overlay, from, to) → 渐变到目标位置 → 销毁
  失败路径: 4a 抛 CycleError → 事务回滚 → FlightShell.abort() 回弹 → 无持久化副作用
```

### 5.4 插件禁用（降级渲染）

```
pluginManager.disablePlugin(id)（plugon）
  → plugin.onDisable()
  → extensions.setPluginActive(id, false)   # 贡献停用（Concept/Handler 随之不可用）
  → UIManager.onConceptsChanged()
    → for materialized hook of affected nodeIds:
        findFor(node) → 无命中 → fallbackConcept.createHook(node, ctx)
        HookIndex.repoint(hookId) 重渲染为普通笔记
  → UIStateStore 孤儿键惰性 GC（触达时清理）
  永不空洞断言: 每个 Node 的 findFor 均有返回（兜底）
unloadPlugin: 逆拓扑 → onDisable → onUnload
  → services.disposeOwner(id)（销毁已实例化实例 + 移除描述符）
  → extensions.removeOwner(id)（移除 Concept/Handler 贡献）
```

### 5.5 重启恢复

```
启动（§4）
  → FSTGraph 加载（懒加载，仅索引 + 窗口内节点结构）
  → UIStateStore 加载
  → 前端图从根建立（物化按需）
  → 位置恢复: UIStateStore.get('position.graph.<hookId>')
  结构确定性: 同一文件树 + 同一插件集 → 同一前端图（00 不变量 4.3-4）
  孤儿位置: getByPrefix 对照 Graph 存在性惰性清理
```

## 6. 存储实现

### 6.1 文件布局

```
data/
  .node/ab/3f/3f5a...c2.node.json     # sidecar 结构（哈希分区，前两位）
  files/note/ab/3f/.../my-note.md     # 内容文件（类型 + 哈希分区）
  files/code/...
  ui-state.json                        # UIStateStore 实现（KV，量小）
  .aliases.json                        # fileId → path 别名表（00 §3.4）
```

### 6.2 sidecar 格式（示例）

```json
{
  "id": "3f5a...c2",
  "title": "我的笔记",
  "content": "inline markdown…",   // 主内容，FSTGraph 落盘为 files/note/…/my-note.md
  "references": {"folder": "a1…", "related": "c4…", "cover": "d2…"},  // cover = 图片节点
  "metadata": {"tags": ["…"]},                        // 注意: 无 instanceOf——匹配靠结构
  "createdAt": "2026-08-04T…",
  "updatedAt": "2026-08-04T…"
}
```

**注意**：`metadata.instanceOf` 已删除（00 删除清单）。归属判定 = `ConceptRegistry.findFor` 结构匹配。schema 需要类型标识时，用自定义 metadata key（如 `conceptId`），由 Concept 的 `metadataSchema` 声明——它是数据，不是机制。

### 6.3 10⁶ 读写路径

```
写: save(node) → 序列化 sidecar → 写入 .node/ab/…/<id>.node.json（原子写: tmp + rename）
读(窗口): 冷启动读索引（nodeId → 分区路径 + 最小元数据），节点结构懒加载
getByMetadata: 内存二级索引（启动时构建，变更时增量更新）——10⁶ × 平均 100B 可承受
分区: nodeId 前两位哈希 → 256 分区，单分区 ~3900 文件（10⁶ 时）
```

## 7. 渲染循环

```
帧预算（60fps，10⁶ 节点）[计划：毫秒数字无基准背书]:
  物化/回收        < 2ms   窗口化（QuadTree 查询视口内节点）——接线已落地
                          （P2-4），数字未测 [计划]；回收无调用方 [计划]
  dirty Hook 重绘  < 10ms  只重绘 dirty；LOD: 远距离降级（标题 → 色块）
                          [计划：LOD 无实现]
  FlightShell      < 4ms   活动期间独占 overlay 层 [计划：未测]
  布局（增量）      < 4ms   布局算法只重算受影响 Hook 子树 [计划：未测]
LOD 级别: L0 标题+内容 / L1 标题 / L2 色块（由 Hook 距视口中心距离选择）
         [计划：无实现]
机制背书: 每帧渲染 Hook 数 ≤ 视口内 Hook 数 + dirty 集合，与全库规模无关——
         画布侧已落地（P2-4 可见集渲染 + 连接线端点过滤）；可见集过滤本身
         为线性扫描 O(n)，10⁶ 需增量索引 [计划]
```

## 8. 错误与边界（异常 → 用户反馈映射）

| 异常 | 触发 | 用户反馈（文案级） |
|---|---|---|
| `CycleError` | 环校验命中 | "此操作会形成循环引用，已阻止" |
| `SchemaRejectedError` | 容器拒绝该 Node schema | "此容器无法容纳这种节点" |
| `IOException` | 磁盘写失败 | "保存失败，请检查磁盘空间与文件权限" + 数据恢复入口 |
| `CorruptNodeError` | sidecar 解析失败 | "节点数据损坏，已恢复为可编辑状态"（兜底加载） |
| `PluginLoadError` | 插件加载失败 | "插件 X 加载失败，其余功能不受影响"（隔离失败） |

原则：**任何异常都有用户可见反馈 + 恢复路径**；禁止静默失败（除已定义 no-op 外）。

## 9. 测试策略

```
契约测试（core_data + core，纯 Dart，M1 后常绿）:
  Graph 接口 × 1、ConceptRegistry.findFor 优先序 × 3（特异性/平局/兜底）、
  AcyclicChecker × 3（直接环/传递环/无环）、HookIndex × 2（物化/未物化广播）

基准（M2 起）:
  10⁶ 节点冷启动索引构建 < 2s；单次 save < 10ms；失效广播 10⁶ 节点 < 1ms
  [计划：10⁶ 未测——30k 实测 save 2.8ms / 冷索引 350ms / 失效查找 0.14ms
  （2026-08-13 本地，CI 每 push 复测）]
  基准脚本: tool/benchmark.dart（生成 10⁶ 假数据）——CI 每 push 跑 30k
  （.github/workflows/ci.yml）；10⁶ nightly [计划]

端到端（M6 验收）:
  杀手演示脚本: 创建笔记 → 拖入 folder → 拖上画布 → 拖进 AI 节点 → 变对话
  每一步断言唯一 owner + 唯一存储（00 不变量 4.2）
  不变量断言: 前端结构零持久化（扫描无结构写入）、永不空洞（findFor 无 null）
```

## 10. 任务清单（里程碑 → 任务）

```
M0 文档冻结        审校 00-04 + architecture.md + 01 回填；无未决概念
M1 抽象层包        core_data 模型接口 → core 机制接口（契约测试随写）
M2 数据与存储      FSTGraph / FileLayer / SidecarStore / FSUIStateStore
                  / 匹配优先序 / 兜底 / AcyclicChecker / 基准脚本
M3 呈现            HookIndex / WindowManager / UIManager / FlutterRenderContext
                  / 窗口化 + 视口物化（§5.1）/ 失效广播（§5.2）
M4 交互            DragController / FlightShell / drop 判定 / 形态渐变
M5 插件化          引入 plugon（DI + ExtensionRegistry + PluginManager）/ 降级渲染（§5.4）/ 启动序列（§4）
M6 folder+graph 试金石
                   folder（contain 关系模型）→ 端到端验收（§9）
                   graph 插件（画布：成员=外观位置/相机/可见性对话框/空间索引）
                   / 旧包冻结归档
M7+               AI 场景（杀手演示）/ Lua 动态 Concept / 其余插件 / 旧包删除
M7 落地（2026-08-05，01 拍板 #30-41）
                   AI：AIConcept（L0 容器）+ chat 实例（L1，消息 = content
                   markdown）+ AppendMessage/AskAI 命令（长任务写路径）
                   Lua：动态 Concept 引擎（脚本化 validate/createHook +
                   Commands 表 + 宿主写 API，vendored Lua 5.4 + lua54.dll）
                   其余插件：editor / converter / search / i18n / settings
                   / market / data_recovery（最小真实机制，01 拍板 #35-40）
                   旧包删除（archive/ 整体 git rm，历史保留）
```

每任务验收物：对应章节的时序可运行 + 该章契约测试通过。写代码只翻本文档；设计依据翻 00-04。

---

## §9 M7.3 追加能力（2026-08-12）

以下为 M7.3 落地记录（判据①/②边界不变）：

- **画布缩放**：`scaleEnabled: true` + `camera.main.<hookId>` 全矩阵（平移+缩放）持久化/恢复；滚轮（`Listener.onPointerSignal`，指针锚点）与右下角按钮组（放大/缩小/适应视图，`_fitToView` 成员包围盒居中）。落点换算统一走 `_camera.toScene`，天然适配缩放。
- **Flowing UI 拖入语义分发**（`SidebarDropSemantics` / `ToolbarDropSemantics` 服务，宿主缺省注册 null = 默认语义，插件 last-wins 覆盖）：
  - AI 节点拖入侧边栏 → `CreateAIPanelCommand` 建 **AI 面板 L1 实例**（references {sidebar, ai}——AI 节点 L0 零变更）→ SidebarTabsView 枚举成「AI 对话」tab。
  - 任意节点拖入工具栏 → `CreateToolbarButtonCommand` 建 `kind=='toolbar'` 按钮（metadata.action='node.open' + target）→ `ToolbarActionRegistry.registerTargeted` 目标动作（点击打开目标节点对话框）。
  - 搜索结果行 = Draggable：拖到文件夹 = MoveNodes（列表项）/ 拖到画布 = 位置直写（卡片，单击出对话框）/ 拖到工具栏 = 建按钮。**落点语义全在既有 DragTarget，三向零新语义。**
  - `HookView._onInvalidation`：structure 事件无条件重建（容器子级 = 运行时枚举，M7.3 暴露缺口）。
- **多仓库（Obsidian 式）**：`VaultHost`（接口，appframe）← `VaultManager`（文件实现）——仓库 = 独立数据根；config `baseDir/vaults.json`；热切换 = 重建 HostRuntime + 重装配插件（servicesProvider 闭包天然适配）+ NotebookApp 键控整树重建 + theme/i18n 状态迁移 + 旧 host post-frame dispose。AppBar 切换器 + 设置「仓库」条目。**M8**：壳层/插件只消费 `VaultHost` 接口（换 git/云仓库 = 新实现类，组合根只选择实现），app 顶层不再持有仓库行为。
- **节点样式**：`style.graph.<nodeId>`（判据②）——颜色（12 色板）/ 尺寸 / 形态（card/circle 卡片与圆圈）；只在画布卡片壳层应用（卡片体 Hook 渲染样式无关）；默认按 kind 配色（ai→indigo 50、folder→amber 50）；DeleteNodeHandler 级联清理样式键。
- **布局**：`ApplyLayoutCommand`（ChangeKind.ui，不发失效事件——画布观察者通道刷新）——力导向（`IncrementalLayoutEngine` 移植，AdjacencyList → AdjacencyMap）/ 网格 / 树状（BFS 分层 + 分量兜底）；入口 = 画布空白右键菜单 + 工具栏 'layout.apply' 动作。
- **Function Calling 复活**：`AIToolRegistry`（服务，factory 预装 6 内置工具——onLoad 副作用在 plugon provider 重建后丢失的修正）/ `AIToolParameterValidator`（原型污染/DoS 防护）/ `FunctionCallingLoop`（maxIterations=10 兜底）；`AIProvider.complete`（OpenAI tools + tool_choice:auto，Mock scriptedToolCalls 测试驱动）；工具经 CommandBus dispatch 节点命令（判据①，写后通知画布实时反映）；AskAIHandler 工具调用/结果以 AI 角色文本落盘（每次重读最新 chat——陈旧快照互相覆盖的实测坑）；注册表空 → 旧 generate 路径回归兼容。

### M7.4 Flowing UI 补漏（2026-08-15）

- `DragController` / `FlightShell` 上移为 HostRuntime 共享单例：拖拽事务四阶段真正接线（dragStart → dragMove → onDrop → cancel），侧边栏（笔记行/文件夹/搜索结果）起点统一上报。
- `FlightShell.present` 合流状态机与视觉：`present(overlay:, child:)` 成功飞行、失败 `bounce` 回弹、`abort/commit` 清理影像；旧 entry 被替换时 identity 守卫防二次 remove。
- 工具栏 drop 走共享事务（`ToolbarContainerConcept.askDropSemantics = DataMove` + per-drop 命令工厂路由 `ToolbarDropSemantics`），失败反馈 SnackBar——三向落点同一事务机制。
- 视口物化 kind 感知：`UIManager.onViewportChanged(rect, kind: 'graph')` 与 `WindowManager.isMaterialized(nodeId, kind:)`——同节点 sidebar/graph 多 Hook 窗口化不再互相遮挡。
