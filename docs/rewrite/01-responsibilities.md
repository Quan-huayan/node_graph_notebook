# 01 — 职责矩阵（先行活文档）

> 定位：**承诺清单，不是描述**。每行 = 一个已定决策。
>
> 执法规则：
> 1. 02-04 每篇写完必须回填本矩阵
> 2. 任何新概念必须先占一行，才许进入设计文档
> 3. architecture.md 不得引入矩阵之外的概念
> 4. 未决项只允许存在于文末"遗留细化"区；拍板即升格入各域

---

## A. 数据域

| 决策点 | 拥有者 | 依据 |
|---|---|---|
| Node 的结构约束（slots / metadataSchema / required） | Concept | 02 |
| Node ↔ Concept 归属判定 | 纯结构匹配，ConceptRegistry 执行 | 02（无 instanceOf） |
| 多 schema 同时命中 | 特异性优先（required 约束多者胜）→ 注册序平局 | 02（确定性锚点） |
| 无 schema 命中 | 兜底 Concept 渲染为普通笔记 | 02（永不空洞） |
| references 内容 | 仅 targetId，`Map<String,String>` | 00（Ln 定义） |
| metadata 内容 | 纯数据，不含 UI 信息 | 00（投影不变式） |
| 内容形态 | 内联文本（笔记）+ 文件引用（代码/数据/二进制） | 02（文件层） |
| 环 | v1 禁止 | 00（环策略） |
| 环校验执行点 | 写命令的 Handler | 02 |
| level | 不存在于模型；布局启发式近似（允许 ∞） | 00 |
| Node 持久化 | Graph（结构）+ 文件层（内容） | 02 |
| 外观状态持久化 | UIStateStore，键带容器上下文 | 02 |
| 前端结构持久化 | 禁止 | 00（投影不变式） |
| 孤儿 UI 状态 | UIStateStore 惰性 GC | 02 |
| 文件身份 | 存储实现内部（别名表 fileId→path），逻辑层不感知 | 02（§2.1） |
| 内容形态 | 文本主内容；附件 = 被引用的独立节点（非字段） | 02（§1.1） |

## B. 呈现域

| 决策点 | 拥有者 | 依据 |
|---|---|---|
| Node → Hook 物化时机 | UI 管理器（视口/容器驱动） | 03 |
| nodeId → hookId 索引 | UI 管理器 | 03 |
| 失效路由 | UI 管理器，只达已物化 Hook | 03 |
| 失效后的反应 | Concept（重读 metadata → 重渲染） | 03 |
| 渲染递归调度 | UI 管理器（框架） | 03（Hook Tree 遍历） |
| Hook 的呈现形态 | `Concept.createHook(node, context)` | 03 |
| context.kind 来源 | 容器 Hook | 03 |
| Hook 渲染内容 | Hook 自身，位置无关 | 03 + 04（壳层前提） |
| Hook 回收 | UI 管理器（窗口化） | 03 |

## C. 交互域

| 决策点 | 拥有者 | 依据 |
|---|---|---|
| 拖拽事务生命周期 | DragController（实现层） | 04 |
| drop 语义判定（①数据命令 / ②UIStateStore） | 目标容器 | 00（三档判据）+ 04 |
| 飞行壳层 | 交互层（实现层） | 04 |
| 侧边栏拖拽（结构性） | 数据命令，改 Graph references | 00（判据①） |
| 画布拖动（外观性） | UIStateStore 写 | 00（判据②） |

## D. 信号域

| 决策点 | 拥有者 | 依据 |
|---|---|---|
| Command 形态 | 纯 DTO，无 execute() | 03 |
| 命令业务逻辑 | Handler | 03 |
| 写后通知（WriteResult / WriteNotifier） | CommandBus 完成写 → UI 管理器路由 / 插件订阅（Disposable + onUnload 关闭） | 03（§四/§五） |
| 撤销契约（inverse 对偶命令） | Handler 声明 / 实现层 UndoMiddleware 执行 | 03（§四） |
| 长任务（布局/AI） | Handler 后台执行，结果走写路径 | 03（§四） |
| 主动读 | Hook 读自己 Node.metadata | 03 |
| 被动读通知 | UI 管理器路由 / Concept 反应 | 03 |
| 失败契约（CycleError / WriteResult.failure） | Handler 抛出 → 用户可读文案 | 03（§四）+ architecture.md §8 |

## E. 粘合域

| 决策点 | 拥有者 | 依据 |
|---|---|---|
| Concept 注册 | Plugon（`ExtensionPoint<Concept>` 贡献，owner 清理自动） | 04（§1.1） |
| Concept 匹配（findFor 优先序 + 兜底） | ConceptRegistry（查询侧） | 04（§1.4） |
| Handler 注册 | Plugon（`ExtensionPoint<CommandHandler>` 贡献） | 04（§1.1） |
| 命令路由（dispatch） | CommandBus（查询侧） | 04（§1.1） |
| 依赖注入 | Plugon（ServiceCollection/Provider：lifetime/owner/循环检测/disposeOwner） | 04（§1.2） |
| 插件生命周期编排 | Plugon（PluginManager：拓扑序/状态机/回滚/占位） | 04（§1.5） |
| 插件禁用后的节点 | 降级为兜底渲染，永不空洞 | 04（§1.5） |
| onDisable / unload 清理 | Plugon（disposeOwner + removeOwner） | 04（§1.5） |
| 旧 Hook 扩展点（HookRegistry） | 删除，一律转新 Hook | 00（删除清单） |
| Lua 插件 | 重写：Lua = 动态 Concept 引擎（脚本化 Concept + Handler + Hook） | 04 |
| Concept 接口复杂度 | 必须薄——Lua 需能实现它 | 04 |
| AI 节点（L0） | 结构匹配 `kind == 'ai'`，references 恒空；拖入 = 数据命令 | 00（杀手演示）+ 01 拍板 #30 |
| 对话会话（chat 实例） | L1-node：`chat.references = {ai, source}`；消息历史 = content（markdown 序列化） | 01 拍板 #30 |
| 对话发送 | AppendMessageCommand（快，用户消息落盘）+ AskAICommand（长任务，回复落盘）——均走写路径 | 03（§四 长任务）+ 01 拍板 #30 |
| LLM 后端 | AIProvider 接口（plugon DI 注册，Handler 延迟解析）；Mock 默认 + OpenAI 可换 | archive/ai 资产带走，01 拍板 #31 |
| 卡片 drop 语义分发 | 壳层语义服务（`CanvasCardDropSemantics`，宿主缺省 null + 插件 last-wins）；**app 组合根回调已移除**（M8 反转） | 04（§三 约束 3）+ 01 拍板 #31 修正：拍板 #32 已反转 |

## F. 遗留细化（非决策级，进入 02 / architecture.md 时定）

| 细化项 | 问题 | 倾向 |
|---|---|---|
| Node ↔ 文件绑定 | 内联 / sidecar / 集中结构文件 | sidecar 结构文件 + 内联文本 |
| 引用稳定性 | 文件移动后 references 指向什么 | id 寻址；文件路径只是别名，不是身份 |
| commit 历史 | v1 是否做 git 式历史 | v1 不做，只借文件树 + 结构分离 |
| 10^6 分区 | 文件目录分区策略 | 哈希分区 / 日期分区（02 定） |
| 结构存储物理 | 集中 index（.git 式） vs 每节点 sidecar | architecture.md 第 6 章定 |

---

## 设计概念登记（02-04 引入；实现类见 architecture.md）

| 概念 | 归属行 |
|---|---|
| 附件节点（asset 类 Concept） | A 域"内容形态"（附件 = 被引用节点，非字段） |
| HookContext | B 域"createHook(node, context)" |
| FlightShell / DragController | C 域"飞行壳层 / 拖拽事务生命周期" |
| CycleError / WriteResult | D 域"失败契约 / 写后通知" |
| WriteNotifier | D 域"写后通知"（替代旧 EventBus 自动发布） |
| 兜底 Concept | A 域"无 schema 命中" |
| HookIndex / WindowManager / UIManager | B 域"nodeId→hookId 索引 / 窗口化"的实现类 |
| Plugon（ServiceCollection/ExtensionRegistry/PluginManager） | E 域"依赖注入 / 生命周期编排"（粘合层实现基础） |
| **contain Concept** | A 域"references 内容"（2026-08-04 拍板：folder↔note 的 contain 关系 = 独立 Concept，具体关系 = 其 Node 实例） |
| **ai Concept / chat 实例** | 00 杀手演示"拖进 AI 节点 → 变对话"（2026-08-05 拍板 #30：AI 节点 L0 + 会话 L1，消息 = content markdown） |
| **DropIntoAICommand / AppendMessageCommand / AskAICommand** | D 域"命令形态"（#30：拖入创建/更新会话；发送拆分快命令 + 长任务） |
| **AIProvider** | D 域"长任务"（#31：plugon DI 注册服务，Mock 默认 + OpenAI 可换） |
| **LuaConcept / LuaHook** | E 域"Lua 插件"（#33：脚本化 Concept 桥，接口薄度验证；Hook 占位） |
| **LuaCommand / LuaWriteCommand / LuaWriteHandler** | D 域"命令形态"（#34：脚本命令路由 + 宿主写 API 同步执行，写操作唯一执行者仍是 Dart） |
| **vendored Lua 5.4 运行时** | E 域"Lua 插件"（#34：flutter_embed_lua MIT 资产 + lua54.dll 多级探测 + 缺陷修复） |

---

## 拍板记录

- 2026-08-04：F 区四项拍板 ——
  1. **存储**：内容 = 文件树（任意类型：md / 代码 / 数据 / 3D 模型），Node 是文件之上引申的结构层，"某种形式的 git"：借文件树与结构分离、可 diff、可外部管理；**不借内容寻址**（id 是身份，路径是别名）、**不借 commit 历史**（v1 不做）。
  2. **旧 Hook**：一律转新 Hook，无双轨。Lua 本质是 API 包装，重写为动态 Concept 引擎（脚本化 Concept + Handler + Hook）。
  3. **包结构**：参照现行 workspace 分层切包，核心约束 = 依赖单向无环 + CI 校验。
  4. **仓库策略**：同仓库并行（新包结构并行建，旧包冻结归档），M6 后旧包整体删除，git 历史保留。

- 2026-08-04（M1/M2 落地回填）——
  5. **存储物理落地**：每 Node 一个 sidecar（`data/.node/<h2>/<id>.node.json`，哈希分区 256），含 title/content 镜像/references/metadata/时间戳，为结构权威；主内容另落盘内容文件镜像（`files/<type>/<h2>/<id8>_<slug>.<ext>`，可被编辑器/git 管理）。sidecar 含 content 镜像 ⇒ 内容文件损坏可从 sidecar 恢复（架构 §8 恢复路径）。F 区"结构存储物理 / 10⁶ 分区"两项由此关闭。
  6. **冷启动索引（2s 预算机制背书）**：`SidecarStore.scan()` = **目录枚举**（只列文件名，不读内容）——文件系统目录本身就是 nodeId → 分区路径索引（架构 §6.3"读索引"）；节点结构（含 title）懒加载。实测 30k 枚举 ~0.8s。metadata 二级索引为**一次性惰性构建**（首次 getByMetadata/getAll，之后增量维护；架构 §6.3 只承诺内存可承受，无时间预算）。10⁶ 全量枚举在 Windows 上外推可能超 2s——已记录为已知风险，索引文件缓存列为 M2.5 优化项。
  7. **原子写**：tmp + rename；`flush: false`（数据进 OS 页缓存后 rename，原子语义"旧或新"不变；崩溃窗口数据由数据恢复插件兜底）。实测 save 8.3ms/op（30k，Windows），达标 <10ms。
  8. **基准首跑（30k，Windows，2026-08-04）**：save 8.3ms ✓（<10ms）、冷启动枚举 0.8s ✓（<2s）、失效广播 0.42ms ✓（<1ms）、metadata 一次性构建 31s（无预算）。CI nightly 跑 10⁶ 全量。

- 2026-08-04（M3/M4 落地回填）——
  9. **契约扩展（追溯断档回填，落地判据 4）**：`Concept.askDropSemantics`（默认拒绝，容器 Concept 覆写——接口"薄"保持，03 §三 判定机制落地）；`Hook.reloadMetadata / dirty / markDirty`（02 §3.4 失效反应的呈现侧契约）；`CommandHandler.commandType`（Dart 泛型方法类型参数运行时不可反查，Handler 显式声明路由键——03 §四签名的实现补充）；`UIManager.onWriteResult`（WriteResult 载荷 changeKind → 三层增量粒度分发，02 §3.4）；`WindowManager.attach / Materializer.materialize` 增补 kind 参数与可空容器（根容器物化，kind 追溯链：子 Hook 的 HookContext.kind = 容器 kind）。
  10. **AcyclicChecker 签名修正**：`check(affectedRefs: Map<String, Set<String>>)`——单节点可同时变更多条引用边（重排场景），M1 的 `Map<String,String>` 无法表达（设计缺口，M4 落地时回填）。
  11. **M4 交互落地**：`FlightShell`（状态机 idle→flying→committed|aborted + 每帧插值回调；OverlayEntry 渲染由宿主 M6 接入）；`DragController`（四阶段事务 + onDrop 提交时序 §5.3：askDropSemantics 判定 → 环预判 → dispatch → 写后通知 → 壳层过渡；失败路径回弹无副作用）；`MoveReferencesCommand / MoveReferencesHandler`（通用引用变更命令骨架：环校验 + 落盘 + structure 树重挂——folder 插件可复用或声明自己的命令）。
  12. **工具链限制记录**：dart CLI 不能编译依赖 Flutter SDK 的包——`tool/benchmark.dart` 直接 import `package:appframe/src/store/*` 具体文件（避开 render/interaction 编译单元）。CI 跑 benchmark 用 `dart run` 即可。
  13. **M3/M4 验收**：§5.1 视口物化、§5.2 失效广播（data 重绘 / structure 树重挂 / ui 直写）、§5.3 拖拽提交全路径（含双保险环校验）、§5.4 降级重物化——时序全部可运行，52 契约/行为测试全绿（core_data 6 + core 28 + appframe 18），analyze 零问题。

- 2026-08-04（M5/M6 落地回填）——
  14. **M5 插件化落地**：扩展点 `conceptPoint` / `commandHandlerPoint`（plugon ExtensionPoint，owner 清理自动）；`PluginConceptRegistry`（findFor 每次从 getActive 实时派生——插件禁用即兜底，**零同步**，无需重建注册表）；`PluginCommandBus`（扩展点路由 + 宿主级注册兼容）；`HostRuntime` 组合根（架构 §4 启动序列 3-10 全落地：存储 → 总线 → 查询器 → UI 管理器 → DI → PluginManager → 插件加载 → 根物化；Graph/UIStateStore 注册为 plugon 服务供插件解析）。**生命周期顺序约束**：registerExtensions 先于 onLoad——插件扩展贡献内的依赖必须延迟解析（MoveNodesHandler 的 graphProvider 模式）。
  15. **M6 folder 试金石验收**（杀手演示全部通过）：
    - **引用单向修正（设计缺口回填）**：架构 §5.3 步骤 b "graph.save(folderA), graph.save(noteB)" 落地为**旧容器移除 + 新容器加入**双写——child 的 parent 反向引用违反 00 §2.2 Ln 定义（互相引用即成环）；归属 = 从引用反查推导，不写 child 自身。
    - **空容器宽容**：FolderConcept.validate 只查 slots 约束（references keys ⊆ {children}），requiredSlots {children} 只作特异性计分——若 required 硬性排除，空文件夹永远无法被识别为容器（无法拖入）。
    - 验收：创建笔记 → 拖入 folder（数据命令）→ 拖上画布（UIMove 外观直写）→ 撞环拒绝（拖 A 进 A 后代）→ 禁用插件降级兜底 → 重启恢复（投影不变式）——4 端到端场景全绿。
  16. **M5/M6 验收**：65 测试全绿（plugon 117 + core_data 6 + core 33 + appframe 22 + folder 4）+ analyze 零问题 + 基准回测全 PASS（save 9.4ms / 冷启动 0.6s / lookup 0.34ms，噪声峰 1.06ms 复测 0.34ms）。**10⁶ 优化项记录**：MoveNodesHandler 旧容器清理用 getAll 全量扫描（M6 数据量小可接受；10⁶ 需 children 反查索引）。

- 2026-08-04（M6 修正——contain 关系模型，用户设计裁决）——
  17. **L0 与关系实例**：folder / note 均为 **L0-node，references 恒空**（00 §2.2 Ln 定义：L0 不引用任何 Node）。contain 关系 = **独立 Concept**，具体关系 = **contain 实例（L1-node）引用两端**：`contain.references = {parent: <folder>, child: <note>}`。
  18. **M6 folder 原实现作废**：folder 持有 `children` 引用（违反 L0）与列表节点方案均废弃；多子级 = 多个 contain 实例。folder 的 children = **读侧反查**（references.parent 指向我的 contain 实例的 child 集合）。拖拽重排 = 改 contain 实例 references（数据命令）。folder 显示信息（名称等）→ metadata（metadata 自由，结构与 references 无关）。
  19. **contain 实例创建/更新**：拖 noteB 进 folderA = 若无 contain 实例（child=noteB）则创建 `{parent: folderA, child: noteB}`，有则更新 parent。环校验仍保留（L0/L1 天然无环，防未来 L2+ 与自引用边界）。
  20. **容器语义挂 Concept**（00 推论 3 落地）：`Concept.childNodeIdsOf(node, graph)` 默认 null（物化器用 references 展开）；容器 Concept 覆写（folder = contain 读侧反查）——子级推导归 schema，物化器只执行。**语义环检查**：拖 folder 进自己后代 = 逻辑环（Ln 模型 references 天然无环，folder 嵌套矛盾由 isDescendant 反查传播拒绝）。
  21. **应用壳交付**（packages/app）：main.dart（数据根 = 运行目录 data/，空库播种 root→contain→folderA + 两笔记）+ app.dart（sidebar folder 树 = 读侧反查渲染 + 画布节点卡片 + Draggable/DragTarget 拖拽 → DragController → MoveNodesCommand）。Windows release 构建运行中（debug exe 被 Defender 误报，release 正常）。

- 2026-08-05（M6 graph 插件落地回填，用户设计裁决）——
  22. **画布成员语义**：成员 = **外观位置**（判据②）：节点有 `position.graph.<nodeId>` 键（UIStateStore）才显示在画布上——00 杀手演示"拖上画布→图节点"的字面落地。**可见性对话框投影不变式修正**：旧实现（archive/graph/ui/graph_nodes_dialog.dart）把"哪些节点在图里"存进 Graph 结构 = 违反投影不变式 4.1；新实现对话框 = **位置键增删**（勾选 → 写默认网格槽位；取消勾选 → remove 键），纯 UIStateStore 操作。对话框可选项 = 用户内容节点（结构判定 references 为空；画布自身排除）——**不引用 folder 概念**（04 §三 约束 3：插件互相不依赖）。
  23. **graph 插件（packages/node_graph）**：`CanvasConcept`（结构匹配 kind=='canvas'；askDropSemantics → UIMove 判据②；L0 容器）+ `GraphCanvas`（定位卡片、相机、拖拽）+ `GraphNodesDialog`。**渲染选型**：Flutter widgets + InteractiveViewer（相机 `camera.main.<canvasHookId>` 矩阵持久化 + 启动恢复 §5.5）——Flame 渲染栈保留为 M7+ 资产（架构 §1 技术风险 1 未验证）。**画布 drop = widget 直接写 UIStateStore**（判据② 无需命令；askDropSemantics 无坐标载荷，真实落点由宿主写入）。**InteractiveViewer 边界坑（Flutter 3.41.5）**：`constrained: false` + 缺省 boundaryMargin 零余量 → 场景视口逆映射越界即钳零（任何右/下平移被吞）；须显式 `boundaryMargin: EdgeInsets.all(2000)`。**画布内卡片拖拽用 LongPressDraggable**（与 pan 手势区分）。
  24. **空间索引资产落地**：QuadTree（旧资产带走）移植到 **appframe**（04 §三）；`QuadTreeViewportQuery`（UIStateStore 位置键 → 视口内 nodeId，全量重建 O(n)，10⁶ 增量索引 = 优化项）。**单根容器视口物化限制**：画布自行做视口可见性过滤（§5.1 查询侧真实），**不调** `UIManager.onViewportChanged`（WindowedUIManager 单 `_rootHook`，多容器视口物化 = M7+ 项）。**孤儿位置键惰性 GC**（02 §2.3）：画布触达时对照 Graph 清理损坏/已删节点键。
  25. **M6 验收更新**：画布 6 场景全绿（成员 = 位置渲染/侧边栏拖入零结构写入/画布内长按拖动/可见性对话框增删/相机持久化+重启恢复/孤儿 GC）+ folder 5 场景（画布桩场景移除——机制覆盖由真实 CanvasConcept 承接，node_folder 测试不再依赖测试桩）。全量 202 测试绿（plugon 117 + core_data 6 + core 33 + appframe 31 + node_folder 5 + node_graph 9 + app 1）+ analyze 零问题。旧包归档（487 个 R 到 archive/）已 staged 未提交。

- 2026-08-05（M6 graph 节点操作回补，用户设计裁决）——
  26. **节点操作按新架构重写回 M6**（旧 create/delete/update/connect 命令，00 删除清单后全部重写为纯 DTO + Handler，03 §四）：`CreateNodeCommand`/`UpdateNodeCommand`（copyWith 落盘）/`DeleteNodeCommand`/`ConnectNodesCommand`——graph 插件贡献 4 个 Handler + `ConnectionConcept`。**连接 = L1-node 实例**（00 §2.2：`connect.references = {from,to}`，无向边：反向连接幂等；自连接 → CycleError；两端零引用不被修改）。**删除级联**：引用该节点的关系实例（contain/connect）一并删除 + 画布位置键同步清理（判据② 外观与结构删除一致）。
  27. **画布交互**：右键菜单（查看内容/编辑/断开所有连接/删除，对齐旧 node_menu 资产）+ 双击空白创建节点（自实现双击检测——**Listener 而非 GestureDetector**：DoubleTap 识别器抢占手势 arena 会使 InteractiveViewer pan 失效，实测坑）+ 拖卡片到卡片建连接（卡片 DragTarget 内层优先于画布移动 DragTarget）+ 连接线渲染（CustomPaint，连接实例 → 两端位置）。**卡片拖动改即时 Draggable**（初版 LongPressDraggable：长按超时前手指微动被 pan 抢走 → 整画布平移，观感像"同时拖多个节点"，实测坑；ImmediateMultiDrag slop 18 < pan slop 36，卡片上按下即拖赢）。
  28. **代码签名（病毒误报治理）**：debug/release exe 均被 SmartScreen/杀软误报（本机 Defender 实时保护关闭，威胁记录空——非真实病毒）。方案：`New-SelfSignedCertificate` 代码签名证书 + 导入 **CurrentUser 受信任根 + 受信任发布者** + `Set-AuthenticodeSignature` 签名 → Status Valid，弹窗消除。分发仍需要正式 CA 证书（自签名只对本机有效）。**签名步骤须在每次 `flutter build windows` 后重跑**（构建覆盖 exe）。
  29. **M6 graph 最终验收**：画布 13 场景全绿（渲染成员/拖入/拖动/可见性对话框/相机/孤儿 GC + 命令 8：create/update/update 不存在/delete 级联/connect/反向幂等/自连接/validate + 交互 5：双击创建/菜单编辑/菜单删除级联/拖拽连接/自连接拒绝）。全量 **215 测试绿**（plugon 117 + core_data 6 + core 33 + appframe 31 + node_folder 5 + node_graph 22 + app 1）+ analyze 零问题 + Windows release 构建成功 + 签名 Valid。批量操作/节点图标/图预览等次要功能仍留 M7+（04 §四）。

- 2026-08-05（M7 AI 杀手演示，用户设计裁决）——
  30. **AI 场景模型**（00 杀手演示"拖进 AI 节点 → 变对话"落地）：**AI 节点 = L0-node**（references 恒空，`metadata.kind == 'ai'`，AIConcept 结构匹配——同 folder 模式）；**对话会话 = chat 实例（L1-node）**：`chat.references = {ai: <AI节点>, source: <笔记>}`，拖笔记进 AI 节点 = 数据命令（查 references.source 唯一实例：无则创建、有则更新 ai——同 contain 模式）；**消息历史 = chat 实例 content**（markdown 序列化 `**用户**:` / `**AI**:` 分段——对话记录是文本，可被编辑器/git 管理，00 §3.2）。笔记本体零修改、无数据副本。
  31. **对话发送 = 两命令拆分**（每条消息写 = 独立命令 + 独立写后通知，UI 时序自然）：`AppendMessageCommand`（快命令：用户消息 append 落盘 → 通知 → UI 即时显示）+ `AskAICommand`（长任务 Handler，03 §四：读 chat + source 上下文 → AIProvider 回复 → append 落盘 → 通知——复用写路径，不阻塞 UI）。**LLM 后端按 archive/ai 方式带走**：`AIProvider` 接口 + `MockAIProvider`（默认，延迟回复）+ `OpenAIProvider`（http，key 配置留 settings 迭代）；服务经 plugon DI 注册（`addSingleton<AIProvider>`），Handler 延迟解析。
  32. **UI 组合**：AI 节点创建 = 画布双击对话框加 kind 选择（笔记/文件夹/AI 节点，NodeEditDialog 扩展）；画布卡片 drop 语义分发 = **app 组合根注入**（04 §三 约束 3：node_graph 不依赖 node_ai——`GraphCanvas.onCardDrop` 可选回调，app 判定目标 Concept == AIConcept → `DropIntoAICommand`，否则默认连接）；对话 UI = `AIChatDialog`（会话列表 + 消息流 + 输入框，node_ai 包内，点击画布 AI 卡片打开）。
   ### M8（组合根回调移除，拍板 #32 反转）
   **错误**：卡片 drop 语义分发归组合根回调——每新增一个跨插件交互就往 app 顶层加一个回调（onCardDrop / onNewNote / vaultManager 同病），组合根被塞进插件行为实现，"领导啥事都干"。
   **反转**：drop 语义判定归 **壳层语义服务家族**（`CanvasCardDropSemantics`，与 `SidebarDropSemantics`/`ToolbarDropSemantics` 同族：宿主缺省 null = 默认连接语义，插件 last-wins 覆盖——node_ai 对 AI 目标返回 `DropIntoAICommand` 数据命令）；Ctrl+N = `ToolbarActionRegistry` 动作（'note.create'，归拥有 NodeEditDialog 的 graph 插件注册，壳层只把 NewNoteIntent 映射到动作名）；多仓库 = `VaultHost` 接口（`VaultManager` 为文件实现，可替换——壳层/插件只消费接口）。
   **落点**：app 组合根只剩模块清单 + 持久化注入 + VaultHost 实现选择；**零插件行为实现**. M8.

- 2026-08-05（M7 Lua 动态 Concept 引擎，01-E 承诺落地）——
  33. **Lua = 动态 Concept 引擎**：脚本（data/lua_scripts/*.lua，文件树可 git 管理）定义 `Concept` 表（id/name/slots/requiredSlots/requiredMetadataKeys/contentRequirement + `validate`/`createHook` Lua 函数），Dart `LuaConcept` 桥实现 Concept 接口委托 Lua——**接口薄度验证**（02 §1.2：Concept 接口薄到 Lua 能实现）。脚本可注册命令处理（`Commands = {name = fn(payload)}`）→ `LuaCommand`（纯 DTO）+ `LuaCommandHandler` 路由；返回值约定字符串：`"affected:<id1>,<id2>;<kind>"` / `"error:<消息>"` / `"ok"`。
  34. **Lua 写操作 = 宿主 API 桥（00 不变量 4.4-1 的 Lua 侧落地）**：`host.node_create/update/delete` 经单 C 回调（`__call_host`）→ **同步执行** `LuaWriteHandler.applySync`（C 回调无法 await；写逻辑本身无异步）→ 写后通知经 `CommandBus.notifyListeners` 广播（PluginCommandBus 新增公开广播，语义与 dispatch 一致）——**写操作唯一执行者仍是 Dart Handler**，环校验不因 Lua 而豁免。**vendored Lua 5.4 运行时**（flutter_embed_lua MIT 资产，`assets/lua54.dll` + NGN_LUA54_DLL/包路径/系统路径多级探测）——修复旧引擎缺陷：`run` 错误前缀未检测、`lua_tolstring` 对 number 原地转 string 破坏 lua_next 键（panic）、chunk 名截断破坏 UTF-8 错误消息、裸调用 chunk 返回值丢失（统一 `return` 前缀）、Lua 表构造器字符串键须方括号（`['id'] =`）、null 字段省略键。沙箱（os/io/package/require/debug/load* 禁用）+ 坏脚本隔离 + 引擎不可用降级（不崩溃启动）。执行超时未实现（沙箱为 MVP 安全边界，已知限制）。

- 2026-08-05（M7 其余插件，最小真实机制）——
  35. **data_recovery**：`BackupCommand`/`VerifyCommand`/`RepairCommand`（纯 DTO + Handler，03 §四）——备份 = 复制 sidecar 目录到 data/backups/<时间戳>；校验 = sidecar JSON 可解析性 + 引用完整性（引用目标存在）；修复 = 删除损坏 sidecar（恢复为可编辑空节点，架构 §8 CorruptNodeError 恢复路径）。启动失败恢复 = 宿主调用方按需触发。
  36. **search**：标题/内容包含匹配（大小写不敏感）——纯查询服务（读侧），不引入总线（02 §1.5：读优化归实现层）；`SearchQuery`（query + 可选 kind 过滤）。
  37. **converter**：`ExportCommand`（节点 → markdown/JSON 文件，写路径：新建节点/文件落盘）+ `ImportCommand`（markdown/JSON → 节点）。MVP 支持 JSON 往返（结构保真）与 markdown 单文件导入。
  38. **i18n**：zh/en 翻译资源**带走**（archive/i18n_zh、i18n_en）→ `Translations`（Map<String, String>）+ `I18nService`（当前语言 + `t(key)`）；语言切换 = 服务级（无 Hook——MVP 不做运行时 UI 切换）。
  39. **settings**：`SettingsService`（主题明暗持久化，SharedPreferences 由 app 层提供——MVP 内存 + app 组合根注入）+ 设置对话框（主题切换）。
  40. **market**：静态插件市场列表（本地内置数据：已装插件 + 描述；MVP 无网络）——展示已装插件（host.loadedPlugins）+ 待装概念条目。
  41. **M7 插件约束**：全部经 `servicesProvider` 注入（M7 修正模式）；插件互相不依赖（04 §三 约束 3）；app 组合根装配全部插件。

- 2026-08-05（M7.1 修正——UIManager 管线接入 widget 树 + 画布成员 Hook 化，用户设计裁决）——
  42. **双轨审计结论（代码事实）**：core 的 UIManager 物化管线（WindowedUIManager/MaterializerImpl/HookIndex/WindowManagerImpl）此前只在启动装配跑一遍——物化 render 进**无 sink 的 FlutterRenderContext**（结果丢弃），全 workspace 无 widget/插件消费；HookView 每次 build 重派生（findFor→createHook）+ AppShell 整树 setState——物化/索引/窗口化/增量失效在 UI 侧全旁路，架构 §7 帧预算在 UI 侧不成立。呈现层全部 UI 呈现路径审计：hook 渲染（Canvas/Folder/Editor/AI/Toolbar）+ action（settings/market/canvas 对话框）+ 壳（AppShell/HookView）——**画布成员卡片 NodeCard 为最后一个手写路径**。
  43. **UIManager 契约增补**（core）：`hookFor(nodeId, kind)`（**kind 感知**——同节点多容器多 Hook：sidebar 行 + graph 卡片 + open 对话框，window.kindOf 区分，不依赖 hookId 字符串）；`materializeIfAbsent(nodeId, kind)`（widget 驱动物化，容器 null——M3 已知简化，onConceptsChanged 恢复以 null 容器重物化）；`recycle(hookId)`；**失效事件**（`InvalidationEvent{changeKind, nodeIds}` + addListener/removeListener，对齐 WriteNotifier 模式）——onWriteResult 后发出（structure/data；ui 不发）。
  44. **HookView 改物化 Hook 渲染宿主**（appframe）：渲染 UIManager 物化实例——**重建不重派生**；订阅失效事件**定向重建**（只命中本节点；structure → 树重挂 → hookFor 空 → 重新物化）；未物化 → 按需物化；`recycleOnDispose`（节点打开对话框：打开即物化、关闭即回收，重开覆盖幂等）。**物化实例陈旧快照修正**：Hook render 时重读自己 Node（02 §3.4 主动读——EditorHook/ToolbarHook 不再持有陈旧 instance）。AppShell 删整树 setState → 壳级订阅（structure 恒重建；data 仅 root/toolbar/canvas 节点）。
  45. **画布成员 Hook 化**（graph 插件最后一个手写路径消除）：成员卡片 = 成员节点自己的**物化 Hook 渲染（kind='graph'）**——NoteCardView（editor）/AICardView（ai）/FolderCardView（folder）卡片体进各自插件（插件互相不依赖）；未提供 'graph' 形态（兜底/Lua 动态 Concept）→ `GenericNodeCardBody` 回退（永不空洞）；画布只提供定位与交互壳（NodeCard 拆 body 注入）。**画布级刷新改结构事件订阅**（成员增删/连接建删 = structure；data 由成员卡片定向重建）——连接线 = 画布级派生状态（ConnectionConcept 无 Hook 物化，10⁶ 优化项：连接 Hook 化）。
  46. **M7.1 验收**：全量测试全绿（plugon 117 + core_data 6 + core 41 + appframe 36 + node_folder 5 + node_graph 26 + node_ai 26 + node_lua 16 + node_editor 4 + node_converter 3 + node_search 2 + node_market 3 + node_data_recovery 4 + app 5 = 294）+ analyze 零问题。**明确不做**：Hook.dirty 像素级增量重绘（渲染循环迭代）、_rebuildSubtree 递归回收（M3 简化，子级惰性——新子级由 HookView 按需物化，视觉正确）、画布 onViewportChanged 窗口化（01 #24：M7+ 项）。
  47. **M7.1 补漏（运行时暴露）**：设置/市场插件仍用 onLoad 快照解析服务——plugon `loadPlugin` 每次销毁旧 provider（plugin_manager.dart `oldProvider?.dispose()`），启动后点击"设置/插件市场"即崩（"ServiceProvider 已销毁"）。修复：SettingsPlugin/MarketPlugin 迁移 M7 修正模式（`servicesProvider` 注入 + `_provider` 延迟解析），app 组合根补注入。M7 插件约束 #41 全量核验：9/9 插件均走宿主入口。

- 2026-08-05（M7.2 修正——验收反馈分类诊断，用户设计裁决）——
  48. **分类诊断**（精读 00-04 后逐条归类）：**实施缺口 3**（架构表达了、代码没执行）：E1 工具栏——00 删除清单"工具栏/侧边栏/状态栏都是容器 Node 的 Hook"未对齐（AppShell 手扫按钮节点，无工具栏容器）；E2 文件夹拖拽——03 判据① 侧边栏重排（含 folder）只实现一半（FolderView 无拖拽源）；E3 主题——拍板 #39"app 组合根读取应用到 MaterialApp"未接线（NotebookApp 硬编码，无人读 SettingsService）。**设计缺口 2**（架构没表达/自相矛盾）：D1 弹出对话框归属——02/03 无"弹出对话框"章节，'open' kind 只在代码注释出现；**用户裁决：弹出对话框 = 概念自治能力（谁弹谁负责外壳），节点打开 = 渲染其 Hook 进发起方对话框（画布打开 = CanvasConcept 责任）**；D2 UIStateStore 失效路径自相矛盾——02 §3.4 声称"数据变更（Handler 写 Graph / UIStateStore）进失效路由"但 UIStateStore 无通知接口、changeKind.ui 又声明"无需通知"；**决策：UIStateStore 观察者通道（渲染方自订阅关心前缀），外观直写不进失效路由**。**D3 撤销**（原判断"设置项需新扩展点"错误）：settings 聚合 = Hook Tree 既有表达——SettingsContainerConcept（容器节点）+ 各插件自己的设置节点（references.settings 反查聚合，插件不互依靠数据引用满足），零新机制。
  49. **阶段 C 决策（设置容器化，恢复旧设置）**：settings 容器节点 + `SettingsContainerConcept`（node_settings，`childNodeIdsOf` = `references.settings == 容器 id` 反查——contain/chatsOf 模式）；各插件贡献自己的设置节点与 Concept（AI key = node_ai、i18n 切换 = node_i18n、主题/持久化 = node_settings、字体/存储路径 = 壳层项）；打开设置容器 = D1 打开契约（发起方弹框）。
  50. **M7.2 落地验收**：E1 工具栏容器（ToolbarContainerConcept + 'toolbar-root' 种子，子级自动枚举——00 删除清单对齐）；E2 FolderView 拖拽源（folder→folder 嵌套 + 撞环数据层已覆盖）；E3 主题接线（AppThemeMode/ThemeController 上移 appframe 壳层——设置插件编辑、NotebookApp ListenableBuilder 即时响应；SettingsService 删除）；D1 弹框归属（画布/侧栏/设置条目各自外壳含关闭与回收；FolderHook 'open' = FolderContentsView）；D2 UIStateStore 观察者（attach/detach + 画布 position 前缀订阅，phase 感知防 build 中 setState——可见性对话框生效）；阶段 C 设置容器化（SettingsContainerConcept + 主题/AI key/语言三个条目节点与各自 Concept——AI key 经 ConfigAIProvider 即时切换 Mock/OpenAI）。全量测试 +13（appframe 40 / node_graph 28 / node_folder 8 / node_ai 28 / node_i18n 1 / node_settings 2 / app 5 等）全绿 + analyze 零问题。**明确不做**：设置持久化（SharedPreferences 由 app 层提供，后续迭代）、字体/存储路径设置（壳层项，后续迭代）。
  51. **M7.2 补修（用户验收反馈）**：① **设置铺开**——条目表单 inline 同页（设置容器 = 单视图滚动，删除 sidebar 行/嵌套弹框）；② **FlightShell 崩溃**——fly/bounce 的 onEnd 自移除后 _entry 未清空 → 下次 fly 二次移除 OverlayEntry（运行时暴露，双守卫修复）；③ **i18n 上移壳层**（语言包"形同虚设"根因修正）——I18nService/翻译资源从 node_i18n 移到 appframe（插件互不依赖下语言包在插件里不可达），node_i18n = 语言设置条目插件；壳层（AppShell 标题/未归类区/画布空提示/菜单项/关闭 tooltip/设置表单）接入 t()——切语言即时可见；④ **字体大小 + 存储路径设置恢复**——ThemeController.textScale + MaterialApp MediaQuery 应用；StorageSettings 显示数据根路径（迁移 UI 后续迭代）；⑤ **search/converter 可见**——'search.open'/'converter.open' 工具栏动作 + 各自对话框（搜索 = 读侧 + 结果打开节点 Hook；导入导出 = Export/Import 命令，JSON 往返）。全量 310 测试全绿 + analyze 零问题。
  52. **M7.2 二次补修（用户裁决——Flowing UI 具象化）**：① **侧边栏 Tab 容器**（根因：侧边栏 Hook 形态单一）——'sidebar-root' 形态 = SidebarTabsView（Tab1 文件夹树 + Tab2..N 面板节点，`references.sidebar == 根 id` 反查——settings 容器同款模式）；**搜索移回侧边栏**（SearchPanelConcept，'sidebar-panel' 形态 = 输入+结果+打开），删除搜索工具栏按钮/对话框（旧版 sidebar tab 设计恢复）；② **converter markdown 聚合/拆分恢复**——.md 导出 = 多节点聚合单文档（## 分段）；.md 导入 = 按 ## 拆分为节点（幂等 id）；JSON 往返保真保留；对话框格式选择；③ **AI 设置完善**——AIProviderConfig 增 model/baseUrl（三字段表单），ConfigAIProvider 使用；④ **字体族切换**（旧版能力恢复）——ThemeController.fontFamily + MaterialApp 主题应用 + 下拉（微软雅黑/宋体/黑体/楷体/Consolas）；⑤ **i18n 刷新 + 补漏**——设置对话框/表单监听 i18n（Listenable.merge）语言切换即时刷新；NodeEditDialog/删除确认/主要 snackbar（folder/canvas）走 t()；⑥ **设置样式**——条目分组卡片（surfaceContainerLow + 间距）。全量 317 测试全绿 + analyze 零问题。
  53. **M7.2 卡死修复（运行时暴露，用户复现：拖"123"文件夹 → 消失 → 再拖回根 → 系统级无响应）**：**根因 = 拖进自己未拒绝**——`isDescendant` 只查"目标是否在后代里"，不查"目标 == 自己"：画布卡片拖到侧边栏同名文件夹 tile → MoveNodesCommand(childId==containerId) 放行 → contain 自引用（parent==child）→ ① 树递归渲染自己（节点消失）② 之后再拖该节点 → `isDescendant` 无 visited 无限递归（每层全图扫描，UI 线程数十秒不响应 = Windows"未响应"）。修复：`isDescendant` 增 nodeId==ancestorId 判定（拖进自己 = 逻辑环）+ **visited 剪枝**（contain 图异常成环时保证终止）；MoveNodesHandler 显式 `childId == containerId → CycleError` 双保险；坏数据（自引用 contain sidecar）惰性清理。新增环防护测试 4 条（拖进自己/环图剪枝/正常链/handler 拒绝）。**教训**：语义后代检查必须同时防"自身"与"环图终止"——数据一致性由写路径保证，遍历健壮性是兜底。

- 2026-08-13（P2-4 裁决回填——10⁶ 视口接线，用户裁决"补上漏洞"）——
  54. **视口窗口化真接线（05 整改 P2-4）**：架构 §5.1/§7 与代码的断档裁决为**补实现**而非仅标注——① HostRuntime 缺省视口查询由空实现改为 `QuadTreeViewportQuery`（构造体装配，测试可显式覆盖）；② 画布相机变化（平移/缩放/窗口 resize）→ 防抖 300ms 推 `UIManager.onViewportChanged`，矩形 = 相机矩阵对 LayoutBuilder 真实视口尺寸的逆变换（M6 失败模式 MediaQuery 坑的第二半修正）+ 相机 listener 立即 setState（InteractiveViewer 内部 Transform 不触发重建，可见集必须随相机重算——不补则平移后卡片不出现）；③ **画布渲染 = 可见集**（200px 边缘余量；世界范围仍由全量位置决定，平移缩放无跳变；连接线 = 至少一端可见；空提示按全量位置判空；孤儿 GC 触达时全扫不变）——命中测试与渲染列表同源（可见即命中）。**10⁶ 未交付项标 [计划]**（architecture §7）：LOD 四级、帧预算毫秒数、QuadTree 增量索引（查询全量重建 O(n)）、离视口回收、§9 10⁶ 基准数字。**Lua 执行超时：标注 [计划]**（机制已评估可行——lua_sethook+LUA_MASKCOUNT 绑定齐全；沙箱为 MVP 边界不变）。测试：appframe 视口接线契约 + node_graph 窗口化渲染共 2 条新增。

- 2026-08-15（M7.4 Flowing UI 审计补漏——设计/落实断档收敛）——
  55. **审计发现（Flowing UI 四条断档）**：① `DragController` 四阶段只有 onDrop/cancel 被调用——`dragStart`/`dragMove` 无调用方，`_dragging` 恒 null；且每个 `FolderView` 各建一个控制器，嵌套 folder 的起点记录在源视图控制器里，目标视图读不到（飞行 from 退化为落点）。② `FlightShell` 状态机（present/tick/commit/abort）与视觉入口（fly/bounce）两套 API 脱节：present 只改 phase、fly/bounce 只画 overlay；FolderView 必须先 fly 再按结果 bounce，成功/失败竞态下出现双影像。③ 工具栏 drop 绕过 DragController 直接 dispatch，命令失败只 debugPrint（违反架构 §8），工具栏与侧边栏/画布三向落点语义同构但事务机制三套。④ `UIManager.onViewportChanged` 按 nodeId 判"已物化"——同节点已有 sidebar Hook 时 graph 视口物化被跳过（kind 感知契约有了 hookFor，视口侧漏补）。
  56. **M7.4 落地**：① `DragController`/`FlightShell` 上移 HostRuntime 单例并注册 DI；`dragStart`/`recordDragStart`/`dragMove` 补齐实现，AppShell→SidebarTabsView→SearchPanel 全链路上报起点；所有出口统一清理会话态；`onDrop` 新增 per-drop `moveCommandFactory` + `from/overlay/flightChild`，成功飞行/失败回弹由控制器统一编排。② `FlightShell.present` 可选 overlay 影像并自动 commit；fly/bounce 与 present 共用 `_startEntry`，identity 校验防旧 entry 二次 remove/状态回写。③ 工具栏经共享 DragController 提交（ToolbarContainerConcept 声明 `askDropSemantics=DataMove`，命令工厂路由 `ToolbarDropSemantics`）；失败给用户可见 SnackBar。④ `UIManager.onViewportChanged`/`WindowManager.isMaterialized` 增 kind 参数，画布推送 `kind: 'graph'`——同节点多容器窗口化不再互相遮挡。全量 417 测试绿（core +1、appframe +6 等）+ analyze 零 error/warning + 两个 CI 工具 PASS。
