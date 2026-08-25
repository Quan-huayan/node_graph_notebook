# 审查文档：appframe（Flutter 壳层 + 组合根）

- 路径：`packages/appframe`｜扫描文件：51｜结论：**合规为主（0 violation / 9 warning / 4 info）**

## 摘要

壳层整体架构合规度高：R1 依赖方向与声明一致（lib 仅依赖 core/core_data/plugon/flutter/shared_preferences，
无 node_*/app import）；R2 写路径干净（UI/服务层无直调 Graph 写 API，唯一直写为 DragController 的
UIMove 外观直写 → UIStateStore，属法定例外）；R7/R8 达标（无 print、全 existsSync）；R12 无 codegen
（StoredNode 手工序列化）；R13 合规（serviceProvider 运行时求值，未在 onLoad 保存快照）；R14 已真实
接线非摆设（HookView 持有物化实例 + 失效定向重建，viewport_wiring_test 证实 onViewportChanged 只物化
视口内节点）。主要风险集中在**兜底健壮性类型化**（4 处裸 catch）与**规模声明落地差距**
（QuadTree 每次全量重建、AppShell 每次 build 三处 getAll、工具栏 Hook 强解包）。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | warning | typed_exceptions | `lib/src/interaction/drag_controller.dart:302` | R9 | **裸 catch 吞全部命令失败**：非 CycleError 的任意异常被裸 catch(error) 吞掉并转成通用「移动失败」。建议捕获 StateError/IOException/FormatException 等已知类型，未知编程错误上抛。 |
| 2 | warning | typed_exceptions | `lib/src/store/sidecar_store.dart:82` | R9 | 损坏 sidecar 兜底用裸 catch(e)（注释说明意图，合规方向正确）；建议类型化捕获 FormatException/TypeError，让未知编程错误上抛。 |
| 3 | warning | typed_exceptions | `lib/src/store/fs_ui_state_store.dart:35` | R9 | ui-state.json 损坏重建为空 KV 用裸 catch(_)（外观可丢，注释说明）；建议收窄到解析损坏的已知形态。 |
| 4 | warning | typed_exceptions | `lib/src/ui/app_shell.dart:213` | R9 | 仓库切换失败裸 catch(error) 把任意异常显示为「切换失败」；建议捕获已知失败类型，其余上抛。 |
| 5 | warning | undo_inverse | `lib/src/command/create_toolbar_button.dart:48` | R3(c) | **CreateToolbarButtonResult 结构写却 inverse:null 且无理由注释**：若为「UI 代理节点不入撤销栈」的有意设计请补注释；否则应提供删除按钮的对偶命令。 |
| 6 | warning | hardcoded_strings | `lib/src/interaction/drag_controller.dart:200` | R11 | **拒绝原因中文硬编码上屏**：「节点不存在」「移动失败：」经 outcome.reason 直接展示在 SnackBar；R11 豁免「内部错误消息」，但此处原因上屏即 UI 文案，建议改翻译键或仅内部记录。 |
| 7 | warning | hardcoded_strings | `lib/src/ui/app_shell.dart:180` | R11 | 状态栏/工具栏拼接硬编码全角冒号「：」与「」括号（en 语言下仍显示中文标点）；建议把标点并入翻译键。 |
| 8 | info | hardcoded_strings | `lib/src/host/vault_manager.dart:110` | R11 | 缺省仓库名「默认仓库」硬编码（种子数据性质，处于豁免边界）；建议按 i18n 取名或允许改名。 |
| 9 | warning | design_smell | `lib/src/spatial/quad_tree_viewport_query.dart:53` | — | **视口查询每次全量重建索引**：每次 queryNodes 都从 UIStateStore 全量重建 QuadTree（O(n)），「查询 O(log n+k)」的 10⁶ 声明不成立；建议缓存重建并在外观变更时增删。 |
| 10 | warning | design_smell | `lib/src/ui/app_shell.dart:147` | — | **壳层每次重建全量扫描节点**：_canvasNodeId()/状态栏计数/_toolbarRootNodeId() 三处 getAll()（_isShellNode 还有逐节点 get）；建议改用 getByMetadata 索引或缓存壳节点 id。 |
| 11 | warning | design_smell | `lib/src/ui/toolbar_container_concept.dart:109` | — | **容器 Hook 渲染强解包 null**：`graph.get(nodeId)!` 若工具栏容器在物化期间被删除将崩溃（toolbar_concept.dart 有 null 回退，此处没有）；建议 null 回退。 |
| 12 | info | import_order | `lib/src/host/host_runtime.dart:20` | R10 | 第三方 shared_preferences 排在项目包之后（vault_manager.dart 同款）；见总览 P1-6 统一裁决。 |
| 13 | info | doc_comments | `lib/src/ui/command_palette.dart:29` | R6 | 连续两行重复的文档注释（笔误）；建议删去一行。 |
| 14 | info | hook_rendering | `lib/src/ui/hook_view.dart:96` | R14 | 合规确认：hookFor/materializeIfAbsent + 失效事件定向重建 + recycleOnDispose，viewport_wiring_test 证实物化/渲染同源——窗口化机制侧已真实接线。 |
| 15 | info | service_resolution | `lib/src/host/host_runtime.dart:302` | R13 | 合规确认：serviceProvider 为惰性 getter（pluginManager.services），ToolbarHook._runAction/ToolbarActionsRow 事件时点解析服务，无 onLoad 快照。 |

## 统计与建议

- 统计：violation 0｜warning 9｜info 4
- P0：#1–#4 与 #5、#6 并入总览 P0-1/P0-3 批量整改（UI 裸 catch 类型化、inverse 注释、文案进词典）。
- P2：#9–#11 是 10⁶ 规模路径（QuadTree 增量/壳层扫描去重/Hook 渲染 null 兜底），与 core 的窗口化回收、
  node_graph 连接线全扫同一条规模债。