# 05 — 经验教训与纪律（2026-08-13 全量审计复盘）

> 前置：[[00-philosophy]] | [[01-responsibilities]] | [[02-model-presentation]] | [[03-interaction-signals]] | [[04-glue-engineering]] | [[architecture]]
> 本文是 2026-08-13 对 refactor 分支全量代码审计（文档 ↔ 代码 ↔ 测试三方核对）的复盘。
> 教训来自代码事实；每条纪律必须附带**检查机制**——不许停留在口号（口号化本身正是本次审计最大的教训）。
> 执法规则：每次里程碑验收逐条对照本文；纪律与 01 职责矩阵同权。

---

## 一、核心结论

设计文档的自律程度与代码交付纪律完全不成比例：抽查的 9 项架构声明仅 1 项（M7.3 三项功能）完整落地；宪法级条款（撤销契约、禁止静默失败、设置持久化判据）全数违约；且整个 M7 重构（509 项变更）从未提交，工作区处于一次误操作即归零的状态。

## 二、教训 → 纪律（12 条）

1. **宪法条款空转。**
   事实：03 §四"任何'撤销没反应'的写操作都是设计缺陷"——交付为零：全部 `WriteResult.inverse => null`，UndoMiddleware 仅存在于 `core/lib/src/command/command.dart:44` 注释，全仓库无键盘事件；architecture §8"禁止静默失败"——保存失败 IOException 裸冒到 `runZonedGuarded` 只 debugPrint（`app/lib/main.dart:82`）。
   教训：文档里的产品级承诺不会自动变成代码，只会变成负债。
   纪律：**任何写入 01/03/architecture 的"产品级需求"条款，必须同步有契约测试或验收场景；无法交付时，修改条款本身。二选一，不允许第三条路。**
   检查机制：里程碑验收逐条核对"条款 ↔ 代码 ↔ 测试"三方证据。

2. **计划写成事实。**
   事实："317 测试全绿"无法复现（实际 359，其中 117 为 vendored plugon）；"CI nightly 跑 10⁶"——仓库无任何 CI；"tool/check_imports.dart 校验依赖"——文件不存在；architecture §7 帧预算在 UI 侧无对应机制。
   纪律：**文档只陈述可被机器或文件验证的事实；未交付项必须标注 [计划]。**
   检查机制：验收时抽查每个"已交付"断言，当场跑对应命令验证。

3. **大重构零提交。**
   事实：509 项未提交（455 D + 24 M + 30 ??）；refactor HEAD 仍是旧 19 包结构，新 node_* 16 包全部未跟踪；plugon 整个包未跟踪；CLAUDE.md 所称 archive/ 不存在。
   纪律：**每完成一个可编译的原子步骤（一个包的建/删、一个里程碑）立即提交；"整个重构"作为未提交状态存在不超过一天。**
   检查机制：`git status` 列入每日开工检查。

4. **性能目标脱离生产链路。**
   事实：10⁶ 窗口化机制在 core 存在但生产零接线（`onViewportChanged` 全仓库仅测试调用；HostRuntime 注入 `_EmptyViewportQuery`；`QuadTreeViewportQuery` lib 下零实例化）；画布 build 全库 `getAll()`（`node_graph/lib/src/canvas_widget.dart:578`），注释自认"10⁶ 窗口化渲染 = M7+ 优化项"；唯一实测是 30k 手跑；metadata 索引 30k 一次性构建 31s，10⁶ 外推为分钟级冻结，无预算。
   纪律：**任何性能声明必须给出生产调用链证据 + 自动化基准 + 预算数字；机制层有实现 ≠ 产品有该能力。**
   检查机制：benchmark 接 CI；渲染路径评审必查"是否全库遍历"。

5. **破坏力与确认门槛不匹配。**
   事实：仓库删除 = 垃圾桶图标无确认 → `dir.deleteSync(recursive: true)` 物理删除整库（`node_settings/lib/src/vault_settings.dart:212`、`appframe/lib/src/host/vault_manager.dart:157`）；而节点删除有确认框。
   纪律：**所有物理删除必须有二次确认 + 可恢复路径（先移备份目录）；禁止对用户数据直达 `deleteSync(recursive)`。**
   检查机制：删除类命令/按钮列入危险操作清单，逐个评审。

6. **i18n 半成品比没有更糟。**
   事实：~150 处硬编码中文 vs 翻译表 70 条 key，其中 8 条死 key；删除确认框的翻译已写好却用硬编码（`node_graph/lib/src/node_card.dart:276`）。
   纪律：**新 UI 文案必须进翻译表（zh+en）；死 key 即删；硬编码用户可见字符串 = review 拒绝。**
   检查机制：硬编码字符串 grep 检查脚本进 CI。

7. **设置类功能的验收标准是"重启后仍在"。**
   事实：主题/语言/AI key 全内存态，重启即失忆——00 §4.2 判据原文自己写了"重启后会'失忆'而用户期望被记住，它是①"。
   纪律：**任何"设置"功能的验收断言必须包含重启保持。**
   检查机制：设置类验收场景模板化（含重启断言）。

8. **错误路径必须验收"用户看到什么"。**
   事实：保存失败（磁盘 IO）、AI 断网（`http.ClientException` 不在 catch 范围）、Lua 脚本错误——用户零反馈。
   纪律：**每个写/网络路径的验收包含一个失败场景断言：具体反馈形态与文案（对齐 architecture §8 文案表）。**
   检查机制：验收场景清单固定包含失败路径。

9. **数据恢复无入口 = 功能不存在。**
   事实：Backup/Verify/Repair 命令存在但全仓库无任何 dispatch 调用方，无 UI 入口。
   纪律：**面向用户的功能必须有 UI 入口才可交付。**
   检查机制：功能清单核对"命令 ↔ UI 入口"配对。

10. **vendored 依赖必须被跟踪；数据目录必须被忽略。**
    事实：plugon 未跟踪；`packages/app/data/` 未被 .gitignore 覆盖，`git add -A` 会误提交用户数据。
    纪律：**vendored 包整体提交；运行时数据目录、构建产物进 .gitignore。**
    检查机制：`git ls-files` / `git check-ignore` 抽查。

11. **CLAUDE.md 是给未来开发者的第一份文档。**
    事实：13 个包的细节章节描述已删除的旧包；`dart run build_runner` 指向 pubspec.lock 中不存在的依赖；app.dart / builtin_plugin_loader.dart 已不存在。
    纪律：**每次包结构变更同步更新 CLAUDE.md；文档中每个路径/命令在写入时必须可执行。**
    检查机制：里程碑验收含 CLAUDE.md 抽查。

12. **测试数字只报自己的。**
    事实：317 含 vendored 117 且无法复现；"analyze 零问题"实际 42 个 info。
    纪律：**报告测试数区分自有/第三方；"全绿"必须是 CI 跑出来的。**
    检查机制：CI 测试矩阵输出为唯一口径。

---

## 三、实施清单（整改令）

### P0 — 数据安全与存在性（本周内）

| # | 事项 | 目标文件 | 验收 |
|---|---|---|---|
| P0-1 | 拆分提交当前工作区：旧包删除 → plugon → 新包逐个 → docs；`packages/app/data/` 进 .gitignore | 全仓库 | `git status` 干净；`git check-ignore packages/app/data` 命中 |
| P0-2 | 仓库删除：二次确认对话框 + 先移备份目录再删 | `node_settings/lib/src/vault_settings.dart`、`appframe/lib/src/host/vault_manager.dart` | 误点垃圾桶不删数据；备份目录可找回 |
| P0-3 | 保存失败反馈：save 异常 → CommandResult.failure → snackbar（架构 §8 现成文案） | `appframe/lib/src/store/`、`node_editor/lib/src/markdown_editor_view.dart:127` | 磁盘满时保存，用户看到可读错误 |
| P0-4 | AI 失败与状态可见：catch `http.ClientException` → snackbar；Mock/未配 key 状态在聊天页与设置表单明示 | `node_ai/lib/src/ai_provider.dart`、`ai_chat_view.dart`、`ai_settings.dart` | 断网发消息有提示；未配 key 时 UI 明示 Mock 模式 |

### P1 — 产品完整性

| # | 事项 | 验收 |
|---|---|---|
| P1-1 | 设置持久化：SharedPreferences 由 app 层提供 → ThemeController / I18nService / AIProviderConfig 接入 | 重启后主题/语言/AI key 保持 |
| P1-2 | 撤销：实现 inverse + UndoMiddleware + Ctrl+Z（先做 删除/移动/改标题 三个高频命令），或从 03 §四 删除该条款——二选一，PM 建议前者 | Ctrl+Z 可撤销三个高频命令；测试覆盖 |
| P1-3 | i18n 收尾：先用 8 条死 key 替换硬编码 → 补齐剩余 ~80-100 条 → 硬编码检查脚本 | 切英文界面无中文残留（种子数据除外） |
| P1-4 | 键盘快捷键第一批：Ctrl+N / Ctrl+S / Ctrl+F | 三键可用 |
| P1-5 | 侧边栏删除入口（笔记/文件夹）+ 确认框 | 可从侧边栏删除 |
| P1-6 | 首启引导：杀手演示引导（拖笔记进 AI 节点） | 新用户知道拖拽演示存在 |

### P2 — 工程可信度

| # | 事项 | 验收 |
|---|---|---|
| P2-1 | CI 落地：analyze + 全量测试 + benchmark（30k 起步）+ 硬编码字符串检查 | push 即跑，结果可查 |
| P2-2 | `tool/check_imports.dart` 落地接 CI；修复 3 个包未声明依赖（node_search/node_i18n/node_settings pubspec）；node_ai→node_graph 依赖例外决策留档 | check_imports 通过；pubspec 与 import 一致 |
| P2-3 | CLAUDE.md 细节章节重写为 node_* 结构 | 文中每个文件/命令真实存在 |
| P2-4 | 10⁶ 决策：视口接线（QuadTreeViewportQuery → 画布；onViewportChanged → HostRuntime）立项，或 architecture §7 标注 [计划]；Lua 执行超时同样二选一 | 文档与代码一致 |
| P2-5 | 测试补充：converter/data_recovery/i18n/settings 契约测试；暗色模式默认卡片色加暗色变体 | 测试数可复现；暗色下卡片对比度合格 |

---

## 四、整改回填（2026-08-13）

P0/P1 全部落地（commit a0a5e95…a47d31c，19 个拆分提交 + 11 个整改提交）：

- **P0-1 完成**：M7 重构全部进入 git（旧包删除 / plugon vendored / 16 个 node_* 包逐个 / core·appframe·app / docs）；`packages/app/data/`、截图产物、本地 Claude 设置进 .gitignore。
- **P0-2 完成**：仓库移除 = 二次确认 + 移入 `.trash/` 回收站（renameSync，失败即保留）；**新增默认仓库守卫**（审计发现原代码删除默认仓库会连带摧毁全部仓库与配置）。
- **P0-3 完成**：写路径失败反馈全覆盖（编辑器保存/画布创建/卡片编辑/删除/断开/布局）——IO → "保存失败，请检查磁盘空间与文件权限"，其余 → "操作失败"；删除确认框改走翻译表。
- **P0-4 完成**：OpenAI 网络异常（断网/DNS/超时 60s）包装为 AIProviderException → snackbar；未配 key 时聊天页 Mock 横幅 + 设置表单模式指示。
- **P1-1 完成**：主题/语言/AI key 持久化（SharedPreferences 由 app 层注入，attach 读回 + setter 自动保存；多仓库切换共享同一 prefs）。
- **P1-2 完成**：撤销系统（03 §四 条款兑现）——UndoManager（撤销/重做栈、executeRaw 防重复入栈）+ Create/Update/SaveNote/Delete/Restore/Move/Uncontain/Connect 全部声明 inverse + Ctrl+Z/Ctrl+Y 全局快捷键。
- **P1-3 完成**：UI 层硬编码中文清零（converter/market/graph_nodes/theme/i18n/search/folder/卡片视图全文案走 t()）；翻译表 70 → ~120 key；8 条死 key 转正。剩余中文 = 数据/协议层（种子标题、导出文件头、Mock 回复、AI 工具协议文案）——按验收豁免。
- **P1-4 完成**：Ctrl+N（组合根回调，onCardDrop 同款语义分发）/ Ctrl+S（编辑器内作用域）/ Ctrl+F（ShellSignals 壳层信号 → 侧边栏切搜索 tab）。实测坑：快捷键在 MaterialApp 内层无焦点即失效——置于外层 + navigatorKey 供对话框上下文。
- **P1-5 完成**：侧边栏笔记/文件夹删除入口 + 共用确认壳（appframe showDeleteNodeConfirm）；**命令词表 DTO 上移 core**（插件互相不依赖的正确落地——node_folder/node_editor 发删除命令零 node_graph 依赖）。
- **P1-6 完成**：首启引导（onboarding.shown 标记，zh/en 文案，核心玩法四步 + 快捷键清单）。

**P1 收尾复核（2026-08-13，三方核对）**：上记 P1-1…P1-6 与 P0 记录逐条对照代码复查——UndoManager（core/lib/src/command/undo_manager.dart）+ 全部节点命令 inverse、onboarding.shown（app_shell.dart）、ShellSignals Ctrl+F（notebook_app.dart）、showDeleteNodeConfirm（confirm_dialogs.dart，三消费方）、命令词表 DTO 上移 core（node_commands.dart 头注释）——全部属实，P1 关闭。

## 五、P2 整改回填（2026-08-13）

P2-1…P2-5 全部落地（commit ed4334d…1dca9bf，5 个原子提交）：

- **P2-1 完成**：CI 落地——`.github/workflows/ci.yml`（windows-latest，Flutter 3.41.5 锁定）：check_imports → check_hardcoded_strings → analyze --fatal-warnings → benchmark 30k → 16 包全量测试（push 即跑）。新建 `tool/check_hardcoded_strings.dart`（状态机剥离注释 + 字符串字面量 CJK 扫描 + P1-3 类别化豁免清单——首跑 348 命中逐项裁决：唯一真 UI 违规「（无内容）」占位符转正翻译表，其余为种子数据/翻译字典/内部错误/协议文本/模型元数据）。`tool/benchmark.dart` 补 exit code（任一预算 FAIL → exit 1，05 纪律 12 CI 口径）。本地预演 30k：save 2.8ms / 冷索引 350ms / 失效查找 0.14ms，全预算 PASS。
- **P2-2 完成**：`tool/check_imports.dart` 落地接 CI（lib/test 分层声明校验 + 方向表，反向依赖即失败）；node_search/node_i18n/node_settings/node_market/app 依赖缺口全部补齐（workspace 共享 package_config 掩盖未声明依赖 = 该工具抓出的静默陷阱）。**node_ai→node_graph 例外**裁决为**消除**而非留档：DTO 已全部在 core 词表（P1-5），4 个 Function Calling 工具改 import core、pubspec 删除依赖（仅测试留 dev_dependencies 装 GraphPlugin）——04 §三 约束 3"插件互相不依赖"零例外。
- **P2-3 完成**：CLAUDE.md 全量重写为 node_* 结构（16 包真实文件树、HostRuntime 实际 DI 顺序、sidecar 实际布局、plugon 方法式插件模板）；删除 build_runner 指令与 BLoC/QueryBus/Flame 章节；顺带揪出旧文档引用不存在的 docs/coding_standards.md。验收：文中每个路径机械校验存在、每条命令实测可跑。
- **P2-4 完成**：10⁶ 裁决 = **补上漏洞**（用户裁决）——视口真接线：HostRuntime 缺省 `QuadTreeViewportQuery`；画布相机变化防抖 300ms 推 `onViewportChanged`（矩形 = 相机矩阵对 LayoutBuilder 真实视口尺寸的逆变换——M6 失败模式 MediaQuery 坑的第二半修正）+ 相机 listener 立即重建（InteractiveViewer 内部变换不触发重建）；**画布渲染 = 可见集**（200px 余量、连接线端点过滤、命中测试与渲染同源）。未交付项（LOD 四级/帧预算毫秒数/10⁶ 增量索引/离视口回收/§9 10⁶ 基准数字）全部标 [计划]（architecture §1/§5.1/§7/§9、04 资产表、01 #54 拍板回填）。**Lua 执行超时：标注 [计划]**（COMMAND_LINE_GUIDE 注明机制已评估：lua_sethook+LUA_MASKCOUNT 绑定齐全）。
- **P2-5 完成**：暗色卡片变体（defaultColorForKind 亮度感知，ai/folder 暗色 tint，浅色保持 50 系）；契约测试补齐：converter +3（空库导出/坏条目跳过/重导幂等）、data_recovery +3（backup 含 ui-state.json/Verify→Repair→Verify 闭环/Repair 幂等）、i18n +3（zh/en 键集一致无空值/t() 回退链/概念匹配）、settings +3（概念匹配×2/表单→ThemeController+prefs 重启回读）——check_imports 顺带揪出 node_settings 测试 shared_preferences 未声明并补齐。

**验收状态（2026-08-13，P2 后）**：全仓 16 包 **404 测试全绿**（自有 287 + vendored plugon 117；P2 新增 16：视口接线 1 + 窗口化渲染 2 + 暗色卡片 2 + converter 3 + data_recovery 3 + i18n 3 + settings 3）；`dart analyze` 零 error/warning（51 info 级风格项遗留）；check_imports + check_hardcoded_strings PASS（CI 同门槛）；benchmark 30k 全预算 PASS；工作区干净（P2 每个整改原子提交）。**审计闭环**：P0/P1/P2 全部落地，遗留项（10⁶ LOD/增量索引/回收/基准数字、Lua 超时、Flame 栈）均为已标注的 [计划]。

