# 审查文档：node_converter（导入导出插件）

- 路径：`packages/node_converter`｜扫描文件：9｜结论：**主体合规（2 violation / 2 warning / 2 info）**

## 摘要

写操作全部经 CommandBus Handler（R2/R4/R5 合规），UI 文案全走 i18n（zh+en 键齐全）、无 print()/
await exists()/codegen，导入宽容与 imported-<slug> 幂等符合规格。**两项明确违规**：ImportHandler
落盘 references 前未做 AcyclicChecker 环校验（R3a，已核验全文无 AcyclicChecker 引用）——恶意/手工
JSON 的自引用或互引会把环写入图；对话框两处裸 catch（R9）。另有 ImportResult.inverse:null 缺注释
（R3c）与 onLoad 保存 provider 快照（R13）两个 warning。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | **violation** | handler_discipline | `lib/src/converter_handlers.dart:115` | R3(a) | **导入写引用未防环**：ImportHandler 落盘 references 前未调用 AcyclicChecker.check（全文无 AcyclicChecker 引用，已核验）；参照 MoveNodesHandler 在 save 前对新增引边做增量环校验并抛 CycleError。 |
| 2 | **violation** | typed_exceptions | `lib/src/converter_dialog.dart:63`（另 :104） | R9 | _exportAll/_import 用无类型 `catch (error)`；建议按 StateError/FileSystemException/FormatException 分型捕获。 |
| 3 | warning | undo_inverse | `lib/src/converter_commands.dart:75` | R3(c) | ImportResult.inverse:null 未按 R3c 注释理由（同文件 ExportResult L42 有注释）；导入属不可撤销写，应补显式说明。 |
| 4 | warning | service_resolution | `lib/converter_plugin.dart:43` | R13 | onLoad 保存服务快照（已核验）：生产 servicesProvider 运行时求值合规，快照仅测试兜底；并入总览 P1-5。 |
| 5 | info | import_order | `lib/converter_plugin.dart:11` | R10 | flutter import 排在项目包之后；全仓同惯例，统一裁决（总览 P1-6）。 |
| 6 | info | other | `lib/src/converter_handlers.dart:115` | — | **导入覆盖既有节点无提示**：JSON 导入对既有 id 直接整体覆盖（含 references/metadata）无确认；属往返恢复语义，建议对话框回显覆盖计数降低误导入风险。 |

## 统计与建议

- 统计：violation 2｜warning 2｜info 2
- P0（本包最优先）：#1 导入环校验（与 #6 一并做：导入 = 信任边界，写前环校验 + 覆盖计数提示）；
  #2 并入全仓 R9 批量。

## 整改落实（2026 本次会话）

> 全量整改由 docs/review 总览 §7 统一裁决驱动（P0 类型化捕获 + P0-2 环校验 + P0-3 inverse 注释；
> P1-5 R13 测试兜底豁免 / P1-6 R10 import 顺序仓库惯例 / P1-7 R6 命令族聚合豁免；
> P2-8/P2-9 窗口化回收与象限索引缓存）。本文件各违规项落实状态：**已整改**（代码注释均引用本
> 文件 audit 编号与总览 §7 行号，可溯源）。仅标 [计划] 的规模项（如每帧全扫、getAll×N）保持注释，
> 未改实现。CI 两工具 PASS 与 `dart analyze` 零 error/warning 为验收线。