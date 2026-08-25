# 审查文档：node_i18n（国际化插件）

- 路径：`packages/node_i18n`｜扫描文件：6｜结论：**合规为主（3 violation / 1 warning / 1 info）——3 项均为同一 import 顺序问题**

## 摘要

依赖方向单向（core/core_data/appframe/plugon 均声明于 pubspec）、无 Graph 直写、无 QueryBus、无 print/
裸 catch/codegen；I18nService 经 host.serviceProvider 渲染时求值符合 R13，UI 文案经 t() 渲染
（'English' 为语言专名豁免）。插件本身无写命令/Handler（R2/R3 不适用）；createInstance 以类型化
UnimplementedError 显式拒绝播种，符合纪律。3 项 violation 全部是 import 顺序（R10），属全仓一致惯例
「项目包先于 Flutter」与规则字面相反——在其它包被标 warning/info，本包 agent 口径偏严标了 violation，
统一裁决见总览 P1-6。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | **violation** | import_order | `lib/src/i18n_settings.dart:11` | R10 | flutter/material 置于项目包导入之后；按 R10 应把 Flutter 组提到项目包前（统一裁决或全仓重排）。 |
| 2 | **violation** | import_order | `test/i18n_contract_test.dart:10` | R10 | flutter_test 位于项目包之后，测试文件同样适用。 |
| 3 | **violation** | import_order | `test/i18n_settings_test.dart:5` | R10 | appframe 置于 flutter/material 之前。 |
| 4 | warning | doc_comments | `lib/src/i18n_settings.dart:46` | R6 | Concept/Hook/Plugin 覆写成员（validate/createInstance/createHook/render/getter/metadata）普遍缺 /// 注释；接口契约已由 core_data 文档化，低风险，建议补一行简注。 |
| 5 | info | other | `pubspec.yaml:6` | — | pubspec 描述仍称「无运行时 UI 切换」，与现状矛盾（M7.2 已提供 settings-i18n 切换表单且即时生效）；建议更新描述。 |

## 统计与建议

- 统计：violation 3（同因）｜warning 1｜info 1
- P1：#1–#3 并入全仓 import 顺序裁决（P1-6）；若坚持 R10 字面，本包仅 3 文件机械重排即可。
- 文档动作：#5 更新 pubspec 描述。