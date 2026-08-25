# 架构违规审查总览（逐包分 agent 审查）

> 审查日期：2026-（本次会话）｜范围：工作区全部 16 包｜方式：每包一个独立审查 agent 静态只读审查
> 目录：`docs/review/audit-<包名>.md` 共 16 份逐包文档 + 本总览

## 1. 审查背景与目的

`CLAUDE.md` 定义了一套 rewrite 架构纪律（依赖单向、纯 DTO + Handler、写操作唯一执行者、
插件互不依赖、窗口化渲染、i18n 强制等）。其中两条由 CI 工具强制：
`tool/check_imports.dart`（依赖声明一致性 + 分层方向）与 `tool/check_hardcoded_strings.dart`
（UI 硬编码中文）。本审查聚焦 **CI 未覆盖** 的规则面：写路径网关、Handler 纪律（环校验 /
inverse 对偶 / 失败可见性）、Public API 文档、print/existsSync/裸 catch、import 顺序、
服务解析快照禁令（01 #47）、无 codegen、Hook 呈现与窗口化渲染是否真实接线，以及设计层耦合气味。

## 2. 审查方法

- **逐 package 分 agent**：16 个独立 agent，每个只审查一个包（lib/ + test/ + pubspec），
  逐个 read 文件全文后按规则清单输出结构化违规（类别/严重度/文件:行/证据/规则号）。
- **严重度口径**：`violation` = 明确违反规则需整改；`warning` = 疑似/设计气味/潜在风险；
  `info` = 观察/合规确认/低风险建议。
- **CI 基线**（审查当日复跑，均 PASS）：`check_imports`（16 包）、`check_hardcoded_strings`（160 文件）。
  因此依赖方向/声明一致性/UI 硬编码中文三条线视为绿地，agent 仅抽查。

### 判据规则表（R1–R14）

| 规则 | 内容 |
|---|---|
| R1 | 依赖方向单向 core_data←core←appframe←node_*←app；插件互相不依赖；lib⁄test import 必须声明于 pubspec |
| R2 | 写操作唯一执行者 = Command Handler；UI/服务层禁直调 Graph 写 API；唯一例外 = 外观直写（UIStateStore） |
| R3 | Handler 纪律：(a) 写 references 前必须 AcyclicChecker 防环；(b) 失败不得静默；(c) 可撤销命令必须有 inverse 对偶，不可撤销写显式 inverse:null 并注释理由 |
| R4 | 读 = Graph 直读或插件读侧服务；不得新建 QueryBus |
| R5 | 插件互通只走 Command + 数据引用 |
| R6 | Public API 必须有 /// 文档；复杂逻辑注释"为什么"；public API 有类型注解 |
| R7 | 禁 print()（用 debugPrint()） |
| R8 | 文件存在性检查用 existsSync()，禁 await exists() |
| R9 | 类型化异常，禁裸 catch (e) |
| R10 | import 顺序：Dart SDK → Flutter → 第三方 → 项目包 → 相对 |
| R11 | UI 文案必须进 translations.dart（zh+en）经 t()；豁免：种子数据/模型元数据/内部错误/协议文本/vendored |
| R12 | 无 codegen（禁 build_runner/.g.dart） |
| R13 | 服务经 serviceProvider 运行时求值；禁在 onLoad 保存 provider/服务快照（01 #47） |
| R14 | Hook render 写 RenderContext.sink；UI 经 UIManager 物化 + 失效定向重建；画布窗口化渲染（可见集+onViewportChanged） |

## 3. 合规总评

整体架构防线牢固：**依赖方向/声明一致性/硬编码中文 CI 全绿**；写操作网关、环校验、
inverse 对偶的**主线全部落实**（core/node_graph/node_folder 的 Handler 均守纪律）；
窗口化渲染**真实接线非摆设**（node_graph 可见集 + 防抖推送 + 测试验证，core 视角待补回收半边）。
16 包未发现"越层直写存储""插件互import""QueryBus 复活""build_runner 引入"等结构性越轨。

集中风险在四类**纪律级/规模级**问题（详见 §5），均为可批量整改项，无架构推倒重来性质。

## 4. 逐包统计汇总

| 包 | 文件 | violation | warning | info | 首要问题 |
|---|---|---|---|---|---|
| core_data | 9 | 0 | 1 | 5 | 契约暴露可变 Map（可绕过 R2 内存脏写） |
| core | 35 | 1 | 4 | 7 | MoveReferences inverse:null 无理由；窗口化只入不出 |
| plugon | 24 | 0 | 1 | 3 | vendored 编排器裸 catch（已注释意图，建议保持） |
| appframe | 51 | 0 | 9 | 4 | 4 处裸 catch；CreateToolbarButton inverse 无注释；QuadTree 每查询全量重建 |
| app | 4 | 2 | 1 | 3 | main.dart 裸 catch + import 顺序；播种直写为引导例外需文档化 |
| node_folder | 20 | 0 | 4 | 4 | onLoad 快照；UI 裸 catch；CreateNodeInFolder 缺 id 守卫 |
| node_graph | 26 | 3 | 4 | 3 | UI 裸 catch×6；onLoad 快照；连接线每帧全扫 |
| node_ai | 31 | 0 | 1 | 0 | 工具转录直写无写后通知（AskAI 中间步骤不可见） |
| node_lua | 11 | 0 | 8 | 3 | 宿主写绕过 dispatch；删除无级联；单引擎静态全局 |
| node_editor | 12 | 2 | 2 | 1 | UI 裸 catch×3；onLoad 快照 |
| node_converter | 9 | 2 | 2 | 2 | **导入未防环（R3a）**；对话框裸 catch |
| node_search | 8 | 0 | 3 | 2 | tags 计数 CJK 括号未走 t()；search 重复全扫 |
| node_i18n | 6 | 3 | 1 | 1 | import 顺序×3（全仓惯例与 R10 字面相反） |
| node_settings | 11 | 1 | 3 | 1 | vault_settings 裸 catch + 直调 VaultManager 无失败反馈 |
| node_market | 5 | 0 | 2 | 2 | onLoad 快照 |
| node_data_recovery | 6 | 2 | 4 | 2 | onLoad 快照；Repair inverse 无注释；TypeError 漏捕 |
| **合计** | **268** | **16** | **50** | **43** | |

## 5. 跨包共性问题（按整改优先级）

### P0 —— 明确违规，建议立即批量整改

1. **UI/边界层裸 catch（R9）**——全仓 13 处以上（appframe×4、node_graph×6、node_editor×3、
   node_converter×2、node_settings×1、app×1、node_folder×2、node_lua×1、node_data_recovery 2 处
   TypeError 漏捕、plugon×6 建议豁免注释）。全部有用户可见反馈（符合架构 §8），但 catch-all 吞掉编程错误。
   **整改**：改 `on StateError / on CycleError / on IOException / on FormatException` 类型化捕获，
   未知错误上抛；或按项目惯例统一"UI 边界允许兜底但必须注释豁免理由"。
2. **导入未防环（R3a，node_converter）**——`converter_handlers.dart` ImportHandler 落盘 references
   前无 AcyclicChecker.check，恶意/手工 JSON 可把环写入图。**整改**：参照 MoveNodesHandler 增量环校验并抛 CycleError。
3. **inverse:null 缺理由注释（R3c）**——core/move_references:50、appframe/create_toolbar_button:48、
   node_lua/lua_commands:103、node_converter/converter_commands:75、node_data_recovery/recovery_commands:93/63、
   node_folder/move_nodes:212 均声明不可撤销却无"为什么"。**整改**：补注释或在可逆处补对偶命令。
4. **node_i18n / app 的 import 顺序标 violation**——见 P1 统一裁决。

### P1 —— 需要设计裁决后统一执行

5. **onLoad provider 快照（R13）——全仓 9 插件同款模式**（node_folder:45、node_graph:56、node_ai:69、
   node_lua:59、node_editor:39、node_converter:43、node_settings:78、node_market:43、node_data_recovery:38）。
   生产主路径均已由 app 注入 `() => host.serviceProvider` 运行时求值（合规缓解），快照仅作单插件测试兜底，
   但 `_snapshot!` 存在空断言且未来装配遗漏会静默用陈旧 provider。
   **裁决**：A) 删除快照、测试基座强制注入 provider；或 B) 在 CLAUDE.md/01 #47 补充"测试兜底豁免"注释。
6. **import 顺序（R10）——全仓一致惯例"项目包先于 Flutter"与规则字面相反**（CI 不查顺序）。
   **裁决**：定为仓库约定并修订规则文档，或按 R10 全仓重排（约 40+ 文件，机械可做）。
7. **"一文件一类"（R6）——Command+Result+Handler 同文件聚合为仓库实际约定**（core/node_commands 9 类、
   node_graph/node_commands 5 Handler、move_nodes 6 类、plugon exceptions 按域合并）。
   **裁决**：规则文档显式豁免"命令族聚合文件"，避免新成员误拆/误合并。

### P2 —— 10⁶ 规模路径（已有 [计划] 标注或新发现）

8. **窗口化回收半边缺失（R14，core）**：`windowed_ui_manager.dart:73` onViewportChanged 只增量物化、
   从不回收离开视口的 Hook——平移遍历全库后 Hook 累积，动摇"Hook 数量≈可视窗口"背书。
   **整改**：视口变化时回收（已物化 ∩ ∉ 可见集）。配套：`materializer_impl.dart:44` 判重无 kind，
   同节点多容器漏建 Hook；`hook_index.dart:49` recycle 全量扫描与 O(1) 声明矛盾（用 _hookToNode 反查）。
9. **appframe QuadTreeViewportQuery 每查询全量重建（O(n)）**，AppShell 每 build 三处 getAll()，
   `toolbar_container_concept.dart:109` render 强解包 `!` 存在删除竞态崩溃。属规模落地差距，建议增量维护 + 缓存 + null 回退。
10. **node_graph 连接线每帧 `graph.getAll()` 全扫**（canvas_widget:699，注释已列"连接 Hook 化"优化项）；
    node_search search() 重复全扫；node_folder 写路径 getAll 定位 contain。均待物化/反查索引落地。

## 6. 文档索引

| 层 | 文档 |
|---|---|
| 契约层 | [audit-core_data.md](audit-core_data.md) |
| 机制层 | [audit-core.md](audit-core.md)、[audit-plugon.md](audit-plugon.md) |
| 壳层 | [audit-appframe.md](audit-appframe.md)、[audit-app.md](audit-app.md) |
| 插件 | [audit-node_folder.md](audit-node_folder.md)、[audit-node_graph.md](audit-node_graph.md)、[audit-node_ai.md](audit-node_ai.md)、[audit-node_lua.md](audit-node_lua.md)、[audit-node_editor.md](audit-node_editor.md)、[audit-node_converter.md](audit-node_converter.md)、[audit-node_search.md](audit-node_search.md)、[audit-node_i18n.md](audit-node_i18n.md)、[audit-node_settings.md](audit-node_settings.md)、[audit-node_market.md](audit-node_market.md)、[audit-node_data_recovery.md](audit-node_data_recovery.md) |