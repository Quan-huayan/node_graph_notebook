# 审查文档：core（核心机制层，纯 Dart）

- 路径：`packages/core`｜扫描文件：35｜结论：**基本合规（1 violation / 4 warning / 7 info）**

## 摘要

机制层整体架构合规度高：纯 Dart 零 Flutter import；依赖方向（core_data+plugon）与声明一致性由
CI 复跑 PASS；R2 写网关落实（写操作唯一执行者为 MoveReferencesHandler 等 Handler）、
R3(a) 落盘前 AcyclicChecker 环校验、R4 无 QueryBus、R5 插件互不依赖、R9 类型化异常、
R12 无 codegen、R13 无 provider 快照均落实；节点命令词表 DTO 纯数据且 undo inverse 注入完整，
UndoManager 经 executeRaw 原始通道避免撤销自压栈——设计正确。
主要风险集中在**窗口化/失效链路**与**撤销声明**：见违规 #1–#4。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | **violation** | undo_inverse | `lib/src/command/move_references.dart:50` | R3(c) | **MoveReferences 无对偶命令**：结构性引用写（移动节点 references）的 WriteResult 声明 `inverse => null`，移动本身可逆，却无任何"为何不可撤销"注释（已核验：第 50 行）。建议补注释说明，或提供对偶命令（Unmove/MoveBack）。 |
| 2 | warning | hook_rendering | `lib/src/ui_manager/windowed_ui_manager.dart:73` | R14 | **视口窗口化只入不出**：onViewportChanged 只对可见集增量物化，从不回收离开视口的 Hook——平移遍历全库后 Hook 持续累积，违背"Hook 数量≈可视窗口"的 10⁶ 背书。建议对（已物化 ∩ ∉ 可见集）执行回收。 |
| 3 | warning | hook_rendering | `lib/src/ui_manager/materializer_impl.dart:44` | R14 | **任意-kind 物化判重漏建**：递归物化路径用无 kind 的 `isMaterialized` 判重，同节点已在 sidebar 物化时画布/对话框容器下的子物化被挡回。建议改 `window.isMaterialized(nodeId, kind: kind)`。 |
| 4 | warning | hook_rendering | `lib/src/ui_manager/windowed_ui_manager.dart:173` | R14 | **structure 树重挂粒度不足**：`_rebuildSubtree` 只回收受影响节点自身 Hook，子树 Hook 残留且旧/新容器不在 affectedNodeIds 时不重挂。建议级联回收子树 + DTO 文档提示 affected 集合应含容器。 |
| 5 | warning | design_smell | `lib/src/invalidation/hook_index.dart:49` | — | **recycle 全量扫描非 O(1)**：遍历整个 _index 找 hookId，与文件头 O(1) 声明矛盾（反查表 _hookToNode 已有未用）；建议直接用反查实现 O(1)。 |
| 6 | info | hook_rendering | `lib/src/fallback/fallback_concept.dart:136` | R14 | FallbackHook.render 空实现（M1 占位）：呈现兜底实际落在 node_graph GenericNodeCardBody / appframe HookView，建议 doc 明示这一跨层依赖。 |
| 7 | info | other | `lib/core.dart:24` | R6 | window.dart（WindowManager 抽象契约）未导出，只导出具体实现——外部包无法按接口编程；建议补 export。 |
| 8 | info | other | `test/ui_manager_test.dart:40` | — | MoveReferencesHandler（机制层唯一直接写 Graph 的 Handler）缺契约测试；建议补成环拒绝/落盘成功/受影响集场景。 |
| 9 | info | file_structure | `lib/src/command/node_commands.dart:17` | R6 | 一文件多类（9 个 DTO/Result）为全仓"命令族聚合"约定；风险低，建议规则显式豁免（见总览 P1-7）。 |
| 10 | info | undo_inverse | `lib/src/command/command_bus.dart:40` | R3 | CommandBusImpl 与 PluginCommandBus 并存，前者 dispatch 不接 UndoManager——误装配会静默丢失撤销接线；建议文档标注或收敛单实现。 |
| 11 | info | other | `lib/src/invalidation/hook_index.dart:30` | — | `onNodeChanged` 死方法占位（恒 null 且与接口语义不同）；建议删除或加 @Deprecated。 |
| 12 | info | import_order | `test/acyclic_checker_test.dart:8` | R10 | 测试文件 flutter_test 排在项目包之后（全仓测试同模式，字面违反 R10）；见总览 P1-6 统一裁决。 |

## 统计与建议

- 统计：violation 1｜warning 4｜info 7
- P0：#1 补 inverse 注释/对偶；P2：#2–#5 属窗口化与失效路由的 10⁶ 落地差距，与 appframe QuadTree、
  node_graph 连接线全扫是同一条规模债的不同路段，建议合并进计划。