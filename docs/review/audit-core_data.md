# 审查文档：core_data（纯数据模型契约层）

- 路径：`packages/core_data`｜扫描文件：9（lib 7 + test 2）｜结论：**合规（0 violation / 1 warning / 5 info）**

## 摘要

零依赖纯数据契约层的整体合规度高：`dependencies: {}` 为空，lib/ 全部文件仅相对导入、
无任何 `package:` 引入与 `dart:ui`/`flutter` 平台泄漏；test/ 仅依赖 flutter_test（dev_dependencies
已声明）+ 自包导入；复跑 `check_imports.dart` 与 `check_hardcoded_strings.dart` 均 PASS。
全部 public API 有 `///` 文档注释与类型注解，构造器先于类成员，无 print、无文件 IO、无裸 catch、无 codegen。
未发现明确违规项。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | warning | design_smell | `lib/src/models/node.dart:25` | — | **契约暴露可变 Map**：`references`/`metadata` 返回可变 Map 且 Graph.get 返回活动对象，消费方就地改值可绕过 R2 写网关造成内存脏写/缓存不一致。建议存储实现返回防御副本，或在契约注释中明确"结构变更（含 map 就地改值）必须走 Command"。 |
| 2 | info | hardcoded_strings | `lib/src/models/concept.dart:114` | R11 | 默认拒绝原因中文化 `RejectDrop('此容器无法容纳这种节点')` 内嵌契约——已按内部错误消息豁免（CI allowlist），但零依赖模型层无法用 t()，若 UI 直接展示 reason 将绕过 i18n；建议 UI 侧按语义键包装翻译。 |
| 3 | info | design_smell | `lib/src/models/hook.dart:37` | — | Hook 默认 no-op/dirty 常量为实现混入契约（01-E 薄接口承诺的有意设计且已注释），契约纯度打折但可接受；建议文档持续标注默认语义防膨胀。 |
| 4 | info | other | `lib/src/models/graph.dart:11` | R4 | Graph 契约缺 `scanIndex`（仅存在于 appframe FSTGraph 具体类），与 CLAUDE.md 描述不符；建议更新文档口径或将索引扫描明确归存储实现。 |
| 5 | info | file_structure | `lib/src/models/drop_semantics.dart:11` | R6 | drop_semantics.dart（4 类）/hook.dart（3 类）单文件多类，与"一文件一类"字面不符；sealed 家族同文件内聚合理，属可接受偏差，不建议拆分。 |
| 6 | info | dependency_declaration | `pubspec.yaml:13` | R1 | 合规确认：lib/ 零 package: import、无平台泄漏；复跑双 CI 工具 PASS。 |

## 统计与建议

- 统计：violation 0｜warning 1｜info 5
- 最值得处理的是 #1（可变 Map 直通活动对象——契约层唯一真实风险点），建议以契约注释先行、
  存储层防御副本跟进。