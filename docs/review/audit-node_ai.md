# 审查文档：node_ai（AI 插件）

- 路径：`packages/node_ai`｜扫描文件：31｜结论：**合规度很高（0 violation / 1 warning / 0 info 结构化项 + 摘要风险 5 项）**

## 摘要

整体架构合规度很高：R1 依赖方向与声明一致（lib/ 零 node_graph/app/其它插件 import；node_graph 仅
dev_dependencies 供测试装配 GraphPlugin，工具 DTO 走 core 词表——CreateNode/UpdateNode/DeleteNode/
ConnectNodes 已核实）；R2 写操作全部收敛于 Command Handler（lib/ 中 graph.save 仅出现在
DropInto/Append/AskAI/CreateAIPanel 四个 Handler 内，工具执行经 CommandBus dispatch）；R4 读侧直读
Graph 无 QueryBus；R3(a) 写引用前均做 AcyclicChecker 环校验；R7/R8/R12 无 print、无异步 exists、
无 codegen；R11 UI 文案全部走 translations（抽查 15 个 ai.*/settings.*/dialog.* key 均在 zh+en 词表）；
dart analyze 零 error/warning。

> 说明：本包结构化审查只回传了 1 条违规项，其余风险由 agent 在摘要中列出（未逐条定位行号）。
> 下面 #2–#5 来自摘要，已核验的快照位置见 #4。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | warning | write_path | `lib/src/chat_handlers.dart:215` | R2/R3 | **工具转录直写无写后通知**：AskAI 长任务中「调用工具/工具结果」转录由 Handler 直写 graph.save（Handler 内写合规，但绕过 dispatch 的写后通知副作用）——UI 直到最终回复经 AskAI dispatch 通知才一次性刷新，中间步骤不可见，进度仅剩 busy 指示器，且长任务无取消机制。建议中间转录也经 dispatch 写或显式广播通知，实现逐步进度。 |
| 2 | warning | undo_inverse | `lib/src/*`（摘要项） | R3(c) | 4 个 WriteResult.inverse:null 中 3 个缺「为什么不可撤销」注释（R3c 半合规），建议补齐注释。 |
| 3 | warning | typed_exceptions | `lib/src/*`（摘要项） | R9 | 多处兜底裸 catch（均有向类型化/用户可见结果转换的意图）；并入总览 P0-1 批量类型化。 |
| 4 | warning | service_resolution | `lib/ai_plugin.dart:69` | R13 | **onLoad 保存 services 快照**（已核验）：生产经 servicesProvider 运行时求值主路径合规，快照仅测试兜底；并入总览 P1-5 统一裁决。 |
| 5 | warning | import_order | 多文件（摘要项） | R10 | Flutter/第三方 import 排在项目包之后；全仓一致惯例，统一裁决（总览 P1-6）。另零散观察：WriteNotifier 硬 cast 且失效粒度粗、`_commandBusProvider!` 非空断言、ChatHook 占位空渲染、doc 漂移。 |

## 统计与建议

- 统计：violation 0｜warning 至少 5（1 结构化 + 4 摘要）｜info 0（另有零散观察）
- P0：#1 是审查重点（长任务进度/取消语义），建议排期：中间转录广播 + 取消令牌。
- P1：#2/#4/#5 并入总览批量项。

## 整改落实（2026 本次会话）

> 全量整改由 docs/review 总览 §7 统一裁决驱动（P0 类型化捕获 + P0-2 环校验 + P0-3 inverse 注释；
> P1-5 R13 测试兜底豁免 / P1-6 R10 import 顺序仓库惯例 / P1-7 R6 命令族聚合豁免；
> P2-8/P2-9 窗口化回收与象限索引缓存）。本文件各违规项落实状态：**已整改**（代码注释均引用本
> 文件 audit 编号与总览 §7 行号，可溯源）。仅标 [计划] 的规模项（如每帧全扫、getAll×N）保持注释，
> 未改实现。CI 两工具 PASS 与 `dart analyze` 零 error/warning 为验收线。