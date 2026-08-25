# 审查文档：node_folder（文件夹插件）

- 路径：`packages/node_folder`｜扫描文件：20｜结论：**合规为主（0 violation / 4 warning / 4 info）**

## 摘要

核心纪律整体合规：R1 依赖方向与声明一致性通过（lib 仅依赖 appframe/core/core_data/plugon/flutter，
零其它 node_* 与 app import）；R2 写网关严守（graph.save/delete 仅存在于 MoveNodesHandler/
UncontainHandler/CreateNodeInFolderHandler 三个 Handler；FolderView 删除/新建走 commandBus.dispatch，
拖拽经 appframe DragController 路由到 MoveNodesCommand）；R3 防环双保险到位（MoveNodesHandler 先做
语义后代检查 isDescendant —— 含自引用与 visited 剪枝，再经 AcyclicChecker.check 增量校验，失败抛
CycleError/StateError 不静默；三条写命令 inverse 对偶完整，M7 幂等 no-op 显式不可撤销带注释）；
R4 读侧全为 Graph 直读；R7/R8/R11/R12 抽查通过，UI 文案全走 i18nService.t()（键 zh/en 双侧存在）。
主要风险：onLoad 保存 provider 快照（R13 字面）+ UI 边界裸 catch + CreateNodeInFolderHandler 缺
command.id 存在性守卫（id 撞车会整体覆盖既有节点）。

## 违规清单

| # | 严重度 | 类别 | 位置 | 规则 | 标题 / 问题 / 建议 |
|---|---|---|---|---|---|
| 1 | warning | service_resolution | `lib/folder_plugin.dart:45` | R13 | **onLoad 保存 provider 快照**：`_snapshot = context.services`（已核验）。生产主路径已由 app 注入闭包运行时求值（合规缓解）,快照仅兜底单插件测试；未注入且未 onLoad 时 `_snapshot!` 有空指针风险。建议删除快照改为仅注入闭包，或补规则豁免注释（见总览 P1-5）。 |
| 2 | warning | typed_exceptions | `lib/src/folder_view.dart:252` | R9 | UI 边界 _create（252）/ _delete（283）两处裸 `catch (error)`（有用户可见 SnackBar，符合失败可见）；建议限定 `on StateError/on CycleError` 或注释临时豁免。 |
| 3 | warning | import_order | `lib/src/folder_view.dart:15` | R10 | Flutter import 排在项目包后（同款：folder_contents_view:12、folder_card_view:9、sidebar_tabs_view:12、folder_create_dialog:8）；全仓一致惯例，统一裁决（总览 P1-6）。 |
| 4 | warning | handler_discipline | `lib/src/folder_create.dart:38` | R3 | **缺少 id 存在性守卫与环校验**：CreateNodeInFolderHandler 只守卫 folderId 不守卫 command.id——id 撞车会整体覆盖既有节点（数据丢失），且当该 id 恰为 folder 祖先时新 contain 即成环。建议写前断言 `graph.get(command.id) == null`。 |
| 5 | info | undo_inverse | `lib/src/move_nodes.dart:212` | R3(c) | UncontainHandler 对缺失 parent 的损坏 contain 静默返回 inverse:null 无注释理由；正常数据下 requiredSlots 保证 parent 存在，属边角，建议补注释。 |
| 6 | info | design_smell | `lib/src/move_nodes.dart:91` | — | 写路径每次 getAll() 全量扫描定位 contain（childrenOf/_unfiledNotes/_panelIds 同样）；文档已标注反查索引为 10⁶ 优化项，确认现状非新增。 |
| 7 | info | hook_rendering | `lib/src/contain_concept.dart:88` | R14 | ContainHook.render 空实现（文档化占位：归属信息经 FolderView/HookView 反查表达）；已知待办非违规。 |
| 8 | info | file_structure | `lib/src/move_nodes.dart:17` | R6 | 单文件 6 个 public 类型（命令+结果+Handler 同族聚合，全仓惯例）；仅记录观察（总览 P1-7）。 |

## 统计与建议

- 统计：violation 0｜warning 4｜info 4
- P0：#4 id 守卫（真实数据完整性风险，建议立即补断言）；#1、#2 并入总览 P0-1/P1-5。
- P2：#6 反查索引落地后消解（与总览 P2 同一条规模债）。