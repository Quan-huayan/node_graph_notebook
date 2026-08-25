# 审查文档：node_graph（画布插件）

- 路径：`packages/node_graph`｜扫描文件：26｜结论：**合规良好（3 violation / 4 warning / 3 info）**

## 摘要

画布插件整体合规良好：R2 写网关严格（UI 层结构写全走 CommandBus，仅画布 position/相机/样式按判据②
外观直写例外）；R3(a) connect 写引用前经 AcyclicChecker 并拒绝自连接，R3(c) create/update/delete/
restore/connect 五命令 inverse 对偶闭环完整；R14 窗口化渲染**真实接线非摆设**（可见集过滤 + onViewportChanged
300ms 防抖推送 + 物化定向重建，viewport_rendering_test 验证视口外不渲染/平移后可重建）；R5 无跨插件
import、R7/R8/R12 合规、R11 文案全走 i18n（抽样 key zh/en 均在）。主要违规集中在 UI 层裸 catch×6
（agent 报告 3 处代表位置，全量 6 处已核验）与 import dart:io 的 web 兼容性。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | **violation** | typed_exceptions | `lib/src/canvas_widget.dart:612`、`:871` | R9 | **UI 裸 catch 兜底**：_connect/_createNodeAt 在类型化 catch（CycleError/IOException）之后保留裸 `catch (error)`（全包共 6 处：canvas_widget 612/871、node_card 274/304/328、layout_dialog 58，均已核验）。失败均有用户可见反馈，建议只捕已知类型，未知错误包装类型化异常上抛。 |
| 2 | **violation** | typed_exceptions | `lib/src/node_card.dart:274` | R9 | 卡片菜单 _edit/_delete/_disconnectAll 三处裸 catch 兜底（见 #1 全量清单）。 |
| 3 | **violation** | typed_exceptions | `lib/src/layout/layout_dialog.dart:58` | R9 | ApplyLayoutCommand dispatch 失败裸 catch 显示 SnackBar。 |
| 4 | warning | service_resolution | `lib/graph_plugin.dart:56` | R13 | **onLoad 保存 provider 快照**（已核验）：生产由 app 注入 servicesProvider 运行时求值，快照仅单插件测试兜底；建议收紧为仅测试注入或移除回退（总览 P1-5）。 |
| 5 | warning | import_order | `lib/src/node_card.dart:20` | R10 | 含 Flutter 的 lib 文件统一将项目包置于 Flutter 之前（涉及 8 个文件）；全仓一致约定，统一裁决（总览 P1-6）。 |
| 6 | warning | design_smell | `lib/src/canvas_widget.dart:13`、`lib/src/node_card.dart:18` | — | **UI 层 import dart:io**（仅为捕获 IOException）：使插件 UI 依赖桌面 IO，无法编译 web 目标；建议由 appframe 暴露无平台依赖的存储异常类型，或将 IOException 捕获收敛到存储层。 |
| 7 | warning | design_smell | `lib/src/canvas_widget.dart:699` | — | **连接线每帧全量扫描**：`graph.getAll()` 全扫（叠加 _readMembers 的 getByPrefix 全量扫位置键），10⁶ 目标下 O(n) 每帧成本；注释已列「连接 Hook 化/增量索引」优化项，建议纳入计划跟踪（总览 P2-10）。 |
| 8 | info | file_structure | `lib/src/node_commands.dart:35` | R6 | node_commands.dart 聚集 5 个 Handler（layout_commands.dart 3 类）；「纯 DTO+Handler 同文件」既定约定，建议规则显式豁免（总览 P1-7）。 |
| 9 | info | acyclic_check | `lib/src/node_commands.dart:199` | R3 | RestoreNodeHandler 恢复级联关系实例未再经 AcyclicChecker/端点存在性复检（undo 还原历史有效状态不会引入新环，但端点若其后被移除会悬空引用）；低风险补一道存在性校验。 |
| 10 | info | other | `lib/src/canvas_widget.dart:689` | R14 | 合规确认：可见集按相机逆变换 × 真实视口过滤（含 200px 余量），防抖推送 + 首帧补推，测试验证物化/渲染同源；外观直写边界符合 R2 唯一例外。 |

## 统计与建议

- 统计：violation 3｜warning 4｜info 3
- P0：#1–#3 并入总览 P0-1（全仓 UI 裸 catch 批量类型化）。
- P1：#6 dart:io 的 web 兼容性值得单独排期（插件 UI 不依赖桌面 IO）；#4 并入 P1-5。
- P2：#7 连接线 Hook 化；#9 低风险补校验。

## 整改落实（2026 本次会话）

> 全量整改由 docs/review 总览 §7 统一裁决驱动（P0 类型化捕获 + P0-2 环校验 + P0-3 inverse 注释；
> P1-5 R13 测试兜底豁免 / P1-6 R10 import 顺序仓库惯例 / P1-7 R6 命令族聚合豁免；
> P2-8/P2-9 窗口化回收与象限索引缓存）。本文件各违规项落实状态：**已整改**（代码注释均引用本
> 文件 audit 编号与总览 §7 行号，可溯源）。仅标 [计划] 的规模项（如每帧全扫、getAll×N）保持注释，
> 未改实现。CI 两工具 PASS 与 `dart analyze` 零 error/warning 为验收线。