# 审查文档：node_editor（编辑器插件）

- 路径：`packages/node_editor`｜扫描文件：12｜结论：**合规良好（2 violation / 2 warning / 1 info）**

## 摘要

写网关成立——编辑保存仅经 SaveNoteCommand（数据）+ UpdateNodeCommand（metadata），删除经
DeleteNodeCommand；SaveNoteHandler 是 lib/ 内唯一 Graph.save 执行者且实现 inverse 对偶（R3c 完整）；
R4 直读（graph.get）与 R13 运行时求值合规；R12 无 codegen；R14 Hook render 走 FlutterRenderContext.sink
无全量渲染；R11 抽查通过（文案全部走 t() 且 zh/en 键齐全）。XSS 核查：预览为纯 widget 树
（Text/SelectableText），无 Html/iframe/javascript 注入面，链接仅复制到剪贴板，无 url_launcher——
无注入风险。主要问题：UI 层 3 处裸 catch（R9）、onLoad 保存 _snapshot（R13 字面）、
markdown_parser 文档与实现漂移。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | **violation** | typed_exceptions | `lib/src/markdown_editor_view.dart:410`（另 :319） | R9 | **裸 catch 吞全部异常**：_save/_saveProps 无类型 catch，吞掉编程错误（如 StateError）；意图是 R3b 用户可见反馈，建议改类型化 catch + 兜底重抛。 |
| 2 | **violation** | typed_exceptions | `lib/src/note_row_view.dart:87` | R9 | 删除入口裸 catch 吞 DeleteNodeCommand 抛出的编程错误；建议捕获类型化异常后展示反馈。 |
| 3 | warning | service_resolution | `lib/editor_plugin.dart:39` | R13 | onLoad 保存 _snapshot（已核验）：生产用 servicesProvider 活引用，快照仅测试兜底；并入总览 P1-5。 |
| 4 | warning | import_order | `lib/src/markdown_editor_view.dart:20` | R10 | 项目包先于 Flutter（markdown_view/note_row_view/note_card_view/测试同模式）；统一裁决（总览 P1-6）。 |
| 5 | info | hook_rendering | `lib/src/markdown_editor_view.dart:105` | R14 | 编辑视图直连 WriteNotifier（`commandBus as WriteNotifier`）绕过 UIManager 失效路由以 setState 刷新——dispose 正确 detach 且作用域限于编辑器视图，注释引 03 §五 观察契约，低风险可保持。另记录：markdown_parser.dart:14 文档声称的 extractTagCandidateLines 实际不存在，TagService 自实现 _maskCodeRegions 重复同一跳过逻辑，存在围栏规则漂移风险。 |

## 统计与建议

- 统计：violation 2｜warning 2｜info 1
- P0：#1/#2 并入总览 P0-1（UI 裸 catch 批量类型化）。
- 文档动作：markdown_parser 的 doc 注释与实现对齐（extractTagCandidateLines 移除或实现），防围栏规则漂移。