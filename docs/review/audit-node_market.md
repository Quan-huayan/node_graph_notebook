# 审查文档：node_market（插件市场插件）

- 路径：`packages/node_market`｜扫描文件：5｜结论：**合规（0 violation / 2 warning / 2 info）**

## 摘要

纯展示型市场插件（无写路径/无 Command Handler）：R1 依赖方向与 pubspec 声明一致（test 跨插件导入
node_i18n/node_settings 均在 dev_dependencies 并注释理由），R11/R12/R2/R3/R4/R14 合规。主要风险：
onLoad 保存 provider 快照作测试回退（R13 字面违反，生产由 app 注入惰性闭包、点击解析时求值，风险可控）；
import 顺序与 R10 字面不符（全库一致惯例）。其余规则无违例，仅个别 override 缺独立文档。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | warning | service_resolution | `lib/market_plugin.dart:43` | R13 | onLoad 执行 `_snapshot = context.services`（已核验）作未注入宿主的测试回退；生产由 app/main.dart 注入 `() => host.serviceProvider` 惰性求值合规。建议删除快照、构造强制 provider 或惰性解析，消除陈旧 provider 风险（总览 P1-5）。 |
| 2 | warning | import_order | `lib/market_plugin.dart:13` | R10 | appframe 排在 flutter 之前（market_dialog.dart:7、测试:6 同）；全库一致惯例，统一裁决（总览 P1-6）。 |
| 3 | info | doc_comments | `lib/market_plugin.dart:35` | R6 | metadata/onLoad/build 等 override 无独立 /// 注释（仅依赖继承语义）；建议为 metadata 补一行说明市场插件身份与版本。 |
| 4 | info | hardcoded_strings | `lib/src/market_dialog.dart:80` | R11 | 合规确认：对话框文案全部经 i18n.t() 取键且 zh/en 键齐全（market.*/dialog.close）；概念名属模型元数据豁免，无硬编码中文。 |

## 统计与建议

- 统计：violation 0｜warning 2｜info 2
- P1：#1 并入总览 P1-5（全仓 9 插件快照统一裁决）；#2 并入顺序裁决。