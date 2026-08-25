# 审查文档：app（应用入口组合根）

- 路径：`packages/app`｜扫描文件：4（lib 1 + test 3）｜结论：**结构合规（0 violation / 1 warning / 2 info，M8 复核）**

## 摘要

组合根职责清晰、总体合规：装配顺序即加载顺序（pluginFactory 内联 11 插件，SharedPreferences 注入 +
servicesProvider 闭包延迟解析，R13 合规）；依赖方向与声明一致（lib/test 全部 import 均在 pubspec 声明，
只向上依赖）；**M8 后组合根零行为实现**（_createNote/_onCardDrop 已从 main.dart 移除——画布卡片 drop
语义归 `CanvasCardDropSemantics` 壳层服务家族、Ctrl+N 归 ToolbarActionRegistry 'note.create' 动作、
多仓库经 `VaultHost` 接口消费；01 拍板 #32 已反转）；读侧 Graph 直读无 QueryBus；无 print、无 codegen、
UI 文案经 t()（键 zh/en 齐全，种子标题属 R11 豁免）。`lib/main.dart` 确为唯一文件（无 app.dart/builtin_plugin_loader.dart）。
残余项仅低风险（测试文件 import 顺序、播种直写豁免）。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | warning | import_order | `test/seed_test.dart:14` | R10 | 测试文件 flutter_test 位于项目包之后（seed_test/smoke_test/killerdemo_test 同模式）；低风险，统一裁决。 |
| 2 | info | write_path | `packages/app/lib/main.dart`（seedIfEmpty） | R2 | **播种直写 Graph 属引导例外**：seedIfEmpty 在组合根直调 graph.save/delete，且 contain-root 结构性引用未过 AcyclicChecker；VaultManager._ensureRuntime 播种先于插件加载（无 handler 可派发），构造保证无环、幂等——属组合根引导例外，**文档已显式注明豁免理由**（architecture.md「多仓库」行，M8；防误仿）。 |
| 3 | info | doc_comments | `lib/main.dart` | R6 | 职责由顶部 library 文档块覆盖（M8 已重写：只组装、零行为分发）；无需补行。 |

## 统计与建议

- 统计：violation 0｜warning 1｜info 2（M8 复核）
- P0（M8 已执行）：#1 裸 catch → 移至 graph_plugin 并类型化（on IOException / on Exception）；#2 import 顺序 → main.dart 重排（SDK → Flutter → 第三方 → 项目包）。
- 文档动作：#6 design_smell 随 M8 移除（组合根回调已删除）；#4 播种豁免理由已注明（architecture.md 多仓库行）。

## 整改落实（2026 本次会话）

> 全量整改由 docs/review 总览 §7 统一裁决驱动（P0 类型化捕获 + P0-2 环校验 + P0-3 inverse 注释；
> P1-5 R13 测试兜底豁免 / P1-6 R10 import 顺序仓库惯例 / P1-7 R6 命令族聚合豁免；
> P2-8/P2-9 窗口化回收与象限索引缓存）。组合根无代码级违规（warning/info 均已注释或按裁决豁免；
> 详见总览 §7）。CI 两工具 PASS 与 `dart analyze` 零 error/warning 为验收线。