# 审查文档：node_search（搜索插件）

- 路径：`packages/node_search`｜扫描文件：8｜结论：**总体合规（0 violation / 3 warning / 2 info）**

## 摘要

纯读侧搜索/标签面板：lib 无跨插件依赖且声明一致（node_graph 仅测试用 dev_dependencies，已注释）；
无直写 Graph、无 print/裸 catch/codegen，服务经 serviceProvider 运行时求值，Hook 写 sink，UI 文案经 t()
（zh/en 齐全）。主要偏离为 R10 import 顺序（全仓一致惯例）与 tags_panel 计数文案含 CJK 括号未走翻译表
（文件在 CI allowlist 内，设计气味）。其余为低风险观察：search() 重复全量扫描、测试种子直写 graph.save。
R1/R2/R4/R6/R7/R8/R9/R12/R13/R14 无明确违规。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | warning | import_order | `lib/src/search_panel.dart:10` | R10 | Flutter 导入置于项目包后（tags_panel.dart:9 同错位）；全仓一致惯例，统一裁决（总览 P1-6）。 |
| 2 | warning | import_order | `test/search_test.dart:6` | R10 | flutter_test 位于项目包之后（search_panel_test/search_drag_test 同）；统一裁决。 |
| 3 | warning | hardcoded_strings | `lib/src/tags_panel.dart:156` | R11 | **计数文案 CJK 括号未走 t()**：`Text('${entry.key}（${entry.value}）')` 全角括号直接拼接（文件在 CI allowlist、通过）；按 R11 意图建议新增 zh/en 键（如 tags.count）经 t() 渲染。 |
| 4 | info | read_side | `lib/src/search_service.dart:46` | — | search() 单次调用内 getAll() 至少两次，且每次 new TagService（内部亦全量扫描）；10⁶ 物化索引已注计划，现阶段可先缓存图快照并复用 TagService 降耗（总览 P2-10）。 |
| 5 | info | write_path | `test/search_test.dart:39` | R2 | 测试 setUp 直接 host.graph.save 播种——R2 约束对象为 UI/服务层，测试夹具可接受；如需口径一致可在 setUp 走命令。 |

## 统计与建议

- 统计：violation 0｜warning 3｜info 2
- P1：#3 文案键化（低成本、贴近 R11 意图）；#1/#2 并入顺序裁决。
- P2：#4 索引落地后消解。