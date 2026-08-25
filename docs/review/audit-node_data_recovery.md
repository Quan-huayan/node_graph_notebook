# 审查文档：node_data_recovery（数据恢复插件）

- 路径：`packages/node_data_recovery`｜扫描文件：6｜结论：**主体合规（2 violation / 4 warning / 2 info）**

## 摘要

依赖方向/声明一致（core/core_data/appframe/plugon 全声明，无 node_* 互依），写操作全部收敛于 Handler
（Repair 的 graph.delete 在 Handler 内），无 QueryBus/print/await exists()/裸 catch（TypeError 漏捕除外）/
codegen，备份 inverse 注释齐备。明确违规：onLoad 保存 provider 快照（R13）与 RepairResult.inverse:null
缺注释理由（R3c）。潜在数据面风险：Verify/Repair 对「合法但非 Map」的 JSON sidecar 只兜 FormatException，
`as Map` 的 TypeError 会击穿 Handler（恢复工具在坏数据上崩溃，本应判定修复）。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | **violation** | service_resolution | `lib/recovery_plugin.dart:38` | R13 | **onLoad 保存 provider 快照**（已核验）：生产 `_servicesProvider?.call()` 已运行时解析且 app/test 均已传 provider，快照分支冗余且 `_snapshot!` 有空断言风险；建议删除（总览 P1-5）。 |
| 2 | **violation** | undo_inverse | `lib/src/recovery_commands.dart:93` | R3(c) | **修复写缺 inverse 注释**：Repair（删损坏 sidecar，属 R3c 明列的不可撤销恢复写）inverse:null 未注释理由；同文件 BackupResult 已注释（L33），应补「恢复不可撤销」说明。 |
| 3 | warning | undo_inverse | `lib/src/recovery_commands.dart:63` | R3(c) | VerifyResult.inverse:null 同样缺注释；校验虽非写操作但以 WriteResult 呈现，建议补说明（只读校验、不可撤销无意义）。 |
| 4 | warning | typed_exceptions | `lib/src/recovery_handlers.dart:126` | R9/R3(b) | **校验漏 TypeError**：第一遍捕获 TypeError 记「结构异常」，第二遍只兜 FormatException——合法但非 Map 的 JSON（数组/字符串）在第二遍 `as Map` 抛未捕获 TypeError 直接击穿。建议补 `on TypeError`。 |
| 5 | warning | typed_exceptions | `lib/src/recovery_handlers.dart:165` | R9/R3(b) | 修复路径同 #4：非 Map 合法 JSON 抛未捕获 TypeError 而非判 corrupt=true，修复命令崩溃（本应删除该损坏 sidecar）；建议补 on TypeError 置 corrupt。 |
| 6 | warning | import_order | `test/recovery_test.dart:11` | R10 | flutter_test 排在项目包之后；全仓同模式，统一裁决（总览 P1-6）。 |
| 7 | info | design_smell | `lib/src/recovery_handlers.dart:32` | — | 三个 Handler 均 `as FSTGraph` 直达 sidecar/dataRoot 文件层：恢复语义需要文件级操作，可接受，但耦合具体存储实现，未来抽象存储时留意。 |
| 8 | info | other | `lib/recovery_plugin.dart:44` | R2 | 合规确认：三 Handler 均经 commandHandlerPoint 注册（写网关唯一执行者）；无写引用故无环校验需求；R1/R4/R5/R7/R8/R11/R12/R14 合规。 |

## 统计与建议

- 统计：violation 2｜warning 4｜info 2
- P0：#4/#5 TypeError 漏捕（恢复工具在坏数据上的正确性，直接优先级最高）；#1/#2 并入总览批量项。

## 整改落实（2026 本次会话）

> 全量整改由 docs/review 总览 §7 统一裁决驱动（P0 类型化捕获 + P0-2 环校验 + P0-3 inverse 注释；
> P1-5 R13 测试兜底豁免 / P1-6 R10 import 顺序仓库惯例 / P1-7 R6 命令族聚合豁免；
> P2-8/P2-9 窗口化回收与象限索引缓存）。本文件各违规项落实状态：**已整改**（代码注释均引用本
> 文件 audit 编号与总览 §7 行号，可溯源）。仅标 [计划] 的规模项（如每帧全扫、getAll×N）保持注释，
> 未改实现。CI 两工具 PASS 与 `dart analyze` 零 error/warning 为验收线。