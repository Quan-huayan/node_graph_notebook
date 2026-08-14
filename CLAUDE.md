# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> 本文档是给未来开发者的第一份文档（05 纪律 11）：文中每个路径/命令必须真实存在。
> 2026-08-13 P2-3 全量重写为 rewrite 架构（docs/rewrite/）的实际包结构；旧 16 包
> 已于 M7 删除（git 历史保留，无 archive/ 目录）。

## Project Overview

**Node Graph Notebook** is a Flutter-based concept-map visualization notebook that rethinks note organization using a node-based architecture. The core philosophy is "All is node!!" — all content elements (text, concepts, relationships) are unified as nodes with graph-based visualization.

### Key Features

- Node-based note organization with concept mapping（文件夹/AI 节点/画布容器 = Concept 结构匹配）
- Markdown editing and rendering（笔记 = markdown 文件，编辑器插件）
- Interactive graph canvas（Flutter InteractiveViewer，成员 = 外观位置键）
- AI integration（AIConcept + chat 实例 + Function Calling 工具 + Mock/OpenAI Provider）
- Plugin system（plugon：DI + 扩展点 + 生命周期编排）
- Data import/export（JSON 往返保真 + markdown 聚合/拆分）
- Theme customization（明/暗/跟随系统 + 持久化）
- Lua scripting（动态 Concept 引擎，vendored Lua 5.4 + lua54.dll）
- Internationalization（zh/en，I18nService 壳层服务）
- Multi-vault（Obsidian 式多仓库，VaultManager 热切换）

## Workspace Architecture

The project uses a **Dart Workspace** monorepo structure. The root `pubspec.yaml` defines the workspace (`workspace:` 列表), and all packages reside under `packages/`.

### Package Dependency Graph

```
core_data (纯模型契约, 零平台依赖)
    ↑
core (机制: CommandBus/ConceptRegistry/环校验/UIManager 窗口化; 依赖 core_data + plugon)
    ↑
appframe (Flutter 壳: HostRuntime/存储/DragController/FlutterRenderContext/QuadTree)
    ↑
plugins/* (node_* 11 插件——互相不依赖, 通信走 Command; 依赖 core/core_data/appframe/plugon)
    ↑
app (组合根: packages/app/lib/main.dart 装配全部插件 + 壳)
```

依赖方向严格单向（04 §三 约束 1/3），CI 每 push 用 `tool/check_imports.dart` 校验
（lib/test 分层声明一致性 + 方向表；`.github/workflows/ci.yml`）。

### Package List

| Package | Name | Description |
|---------|------|-------------|
| `core_data` | `core_data` | 纯数据模型契约 (Node, Concept, Graph, UIStateStore, Hook) 。零平台依赖 |
| `core` | `core` | 核心机制: CommandBus/Handler (纯 DTO + Handler), ConceptRegistry, 匹配优先序, 兜底 Concept, AcyclicChecker, HookIndex, UI 管理器, 窗口化 |
| `appframe` | `appframe` | Flutter 壳: HostRuntime (组合根), FSTGraph/SidecarStore/FSUIStateStore, DragController/FlightShell, FlutterRenderContext, QuadTree, I18nService/ThemeController |
| `plugon` | `plugon` | 粘合层 (vendored): DI (ServiceCollection/Provider), ExtensionRegistry, PluginManager (生命周期/拓扑序/回滚) |
| `app` | `app` | 应用入口: main.dart (pluginFactory 装配 + VaultManager + 空库播种 + runApp) |
| `node_folder` | `node_folder` | 文件夹插件: FolderConcept (L0 容器), ContainConcept (L1 关系), MoveNodesHandler |
| `node_graph` | `node_graph` | 画布插件: CanvasConcept (成员 = 外观位置), ConnectionConcept (L1), 节点操作 Handler, GraphCanvas UI, 可见性/样式/布局对话框 |
| `node_ai` | `node_ai` | AI 插件: AIConcept (L0 容器), chat 实例 (L1, 消息 = content markdown), AppendMessage/AskAI 命令, Function Calling 工具, AIProvider (Mock 默认 + OpenAI) |
| `node_lua` | `node_lua` | Lua 插件: 动态 Concept 引擎 (脚本化 validate/createHook + Commands 表 + 宿主写 API), vendored Lua 5.4 运行时 + assets/lua54.dll |
| `node_editor` | `node_editor` | 编辑器插件: SaveNoteCommand (写路径), NoteConcept, MarkdownEditorView (编辑 + 简单预览) |
| `node_converter` | `node_converter` | 导入导出插件: Export/Import 命令 (JSON 往返保真 + markdown 聚合/拆分) |
| `node_search` | `node_search` | 搜索插件: SearchService (标题/内容包含匹配, 纯读侧), SearchPanelConcept (侧边栏 tab) |
| `node_i18n` | `node_i18n` | 国际化插件: I18nSettingsConcept (语言设置条目) —— 服务本体在 appframe 壳层 |
| `node_settings` | `node_settings` | 设置插件: 设置容器 + 主题/外观/仓库条目 Concept 与表单 (编辑壳层 ThemeController) |
| `node_market` | `node_market` | 插件市场插件: MarketDialog (已装插件静态列表, MVP 无网络) |
| `node_data_recovery` | `node_data_recovery` | 数据恢复插件: Backup/Verify/Repair 命令 (sidecar 备份/校验/修复) |

## Architecture Pattern

```
UI Layer (Hook render → RenderContext sink; 画布/侧边栏/对话框)
    ↓
CommandBus (写操作网关, core/lib/src/command/)——纯 DTO + Handler, plugon 扩展点路由
    ↓
Command Handlers (业务逻辑, 插件贡献——写操作唯一执行者, 01-D)
    ↓
FSTGraph / FSUIStateStore (数据访问, appframe/lib/src/store/)
```

**Important Patterns:**
- ✅ **Write operations** → `CommandBus.dispatch(command)`（自动发布写后通知 → UIManager 失效路由）
- ✅ **Read operations** → `Graph` 直读（`get/getMany/getAll/getByMetadata`）或插件读侧服务（如 SearchService）；**无 QueryBus**（02 §1.5：不恢复总线抽象）
- ✅ **插件间通信** → 只走 Command + 数据引用（04 §三 约束 3：插件互相不依赖）
- ✅ **写后通知** → `commandBus.attach(uiManager.onWriteResult)` → `InvalidationEvent{changeKind, nodeIds}` → 呈现层定向重建（structure/data 粒度）
- ✅ **撤销** → `WriteResult.inverse`（对偶命令）+ `UndoManager` + Ctrl+Z/Ctrl+Y（03 §四）
- ✅ **Plugins** → plugon：`registerServices` / `registerExtensions`（Concept + CommandHandler 贡献）

## Development Commands

```bash
# Install dependencies (run from workspace root)
dart pub get

# Code analysis (root = 整个 workspace；零 error/warning 为验收线)
dart analyze

# Run tests (per package; 无跨包 runner——CI 与本地同口径)
cd packages/<name> && flutter test
# 全量 16 包（PowerShell，从仓库根）：
#   $failed=@(); Get-ChildItem packages -Directory | ForEach-Object {
#     Push-Location $_.FullName; flutter test; if ($LASTEXITCODE -ne 0) { $failed += $_.Name }; Pop-Location }

# Run the app (from packages/app; 数据根 = 运行目录 data/)
cd packages/app
flutter run

# Build Windows release (from packages/app; 构建后需重跑代码签名, 01 #28)
cd packages/app
flutter build windows

# Format code
dart format .

# CI 工具（CI 每 push 全跑, 本地提交前同跑）
dart run tool/check_imports.dart                  # 依赖方向/声明一致性
dart run tool/check_hardcoded_strings.dart        # UI 硬编码中文（豁免清单见脚本头）
dart run tool/benchmark.dart --nodes 30000        # 基准（预算内 FAIL 即 exit 1）
```

**无 build_runner / 无 .g.dart**：JSON 序列化是手工的（`StoredNode.fromJson/toJson`，
`packages/appframe/lib/src/store/stored_node.dart`）。修改模型 = 改这个文件，不需要 codegen。

## Package Details

### `core_data` — 纯数据模型契约

零平台依赖（不 import dart:ui / flutter），所有其他包均可依赖。`packages/core_data/lib/src/models/`：

- `node.dart` — 统一节点模型（id/title/content/references/metadata/时间戳）
- `concept.dart` — Concept 契约（结构匹配 validate / createHook / drop 语义）
- `graph.dart` — 图仓库接口（get/getMany/save/delete/getAll/getByMetadata/scanIndex）
- `ui_state_store.dart` — 外观 KV 契约（get/set/remove/getByPrefix/attach/detach）
- `hook.dart` — Hook 契约（nodeId/hookId/render(RenderContext)）
- `drop_semantics.dart` — drop 语义判定契约（Reject/Drop 结果）

### `core` — 核心机制（零 Flutter）

依赖 `core_data` + `plugon`。`packages/core/lib/src/`：

- `command/` — 命令系统：`command.dart`（Command 纯 DTO + WriteResult + ChangeKind）、
  `command_bus.dart`（PluginCommandBus：扩展点路由 + 写后通知 + UndoManager 接入）、
  `undo_manager.dart`（撤销/重做栈，P1-2）、`node_commands.dart`（**节点命令词表 DTO
  上移 core**——跨插件共享，P1-5）、`move_references.dart`、`exceptions.dart`
- `registry/` — `extension_points.dart`（conceptPoint/commandHandlerPoint）、
  `concept_registry.dart`（findFor 匹配优先序）、`plugin_concept_registry.dart`
  （扩展点派生）、`static_concept_registry.dart`
- `matching/specificity_priority.dart` — 特异性优先序（required 约束数 → 注册序）
- `fallback/fallback_concept.dart` — 兜底 Concept（永不空洞）
- `cycle/acyclic_checker.dart` — 环校验（返回 cycle path）
- `invalidation/` — `hook_index.dart`（nodeId→hookId O(1)）、`router.dart`
- `ui_manager/` — `ui_manager.dart`（UIManager 契约：hookFor/materializeIfAbsent/
  recycle/onViewportChanged/失效事件）、`windowed_ui_manager.dart`（默认实现）、
  `materializer.dart` + `materializer_impl.dart`（物化策略）、
  `viewport_query.dart`（ViewportQuery 契约）、`value_rect.dart`（视口矩形，零 Flutter）、
  `window.dart` + `window_manager_impl.dart`（窗口登记）

### `plugon` — 粘合层（vendored，117 上游测试）

`packages/plugon/lib/`：`core/di/`（ServiceCollection/ServiceProvider/owner 清理）、
`core/extensions/`（ExtensionPoint/ExtensionRegistry/贡献停用）、
`core/plugin/`（Plugin 契约/PluginManager：拓扑序/状态机/回滚）、
`flutter/`（provider/bloc 适配）。契约细节见 `packages/plugon/docs/ARCHITECTURE.md`。
**纪律**：vendored 包整体 git 跟踪（05 纪律 10）。

### `appframe` — 应用框架层

依赖 core + core_data + plugon（唯一 Flutter 依赖点之外的全插件共享壳）。`packages/appframe/lib/src/`：

- `host/host_runtime.dart` — **组合根**：装配存储/机制/plugon 编排/前端图（DI 顺序见下）
- `host/vault_manager.dart` — 多仓库（vaults.json + 热切换 + `.trash/` 回收站 + 默认仓库守卫）
- `store/fs_graph.dart` — 结构存储（FSTGraph：sidecar + 元数据二级索引）
- `store/sidecar_store.dart` — sidecar 分区（`.node/<前2位>/<id>.node.json`，原子写 tmp+rename）
- `store/fs_ui_state_store.dart` — 外观 KV（`ui-state.json`）
- `store/stored_node.dart` — Node 序列化（手工 fromJson/toJson）
- `store/file_layer.dart` — 内容文件层
- `interaction/drag_controller.dart` + `flight_shell.dart` — 拖拽事务 + 飞行动画
- `render/flutter_render_context.dart` — Hook render 的 Flutter 上下文（host/kind/sink）
- `spatial/quad_tree.dart` + `quad_tree_viewport_query.dart` — 空间索引 + 视口查询
  （P2-4：HostRuntime 缺省装配，生产接线）
- `ui/hook_view.dart` — 物化 Hook 渲染宿主（失效事件定向重建）
- `ui/notebook_app.dart` — MaterialApp 壳（主题/暗色接线）；`ui/app_shell.dart` — 壳布局
- `ui/theme_controller.dart` — 主题控制器（壳层服务，设置插件编辑，P1-1 持久化）
- `ui/node_style.dart` — 节点样式解析 + kind 默认配色（P2-5 暗色变体）
- `ui/confirm_dialogs.dart` — 删除确认壳（showDeleteNodeConfirm，跨插件共用）
- `ui/toolbar_concept.dart` + `toolbar_container_concept.dart` — 工具栏 UI 节点机制
- `ui/toolbar_actions_row.dart` — 工具栏按钮渲染
- `ui/shell_signals.dart` — 壳层信号（Ctrl+F → 侧边栏搜索 tab，P1-4）
- `i18n/i18n_service.dart` + `translations.dart` — 国际化服务与 zh/en 词表（壳层）
- `command/create_toolbar_button.dart` — 拖拽建工具栏按钮命令

### `app` — 应用入口

`packages/app/lib/main.dart` **是唯一文件**（组合根）：
`SharedPreferences.getInstance()`（P1-1 注入）→ `pluginFactory`（11 插件内联装配）→
`VaultManager`（多仓库）→ 空库播种（`seedIfEmpty`：根目录/文件夹/工具栏/设置等种子标题）→
`runApp(NotebookApp(...))`。**没有 app.dart / builtin_plugin_loader.dart**（M7 已删）。

### `node_folder` — 文件夹插件

- `folder_plugin.dart` — FolderPlugin：FolderConcept/ContainConcept/MoveNodesHandler 贡献
- `src/folder_concept.dart` — 文件夹（L0 容器，kind=='folder'；子级 = contain 读侧反查）
- `src/contain_concept.dart` — 包含关系（L1：`references={parent,child}`）
- `src/move_nodes.dart` — 移动/取消包含命令（环校验 + inverse 对偶，P1-2）
- `src/folder_view.dart` / `folder_contents_view.dart` / `folder_card_view.dart` / `sidebar_tabs_view.dart` — 树视图/内容/画布卡片体/侧边栏 tab

### `node_graph` — 画布插件

- `graph_plugin.dart` — GraphPlugin：CanvasConcept/ConnectionConcept + 4 个节点命令 Handler
- `src/canvas_widget.dart` — GraphCanvas：InteractiveViewer 相机 + 成员卡片 + 连接线 +
  **窗口化渲染**（P2-4 可见集 + 视口推送接线）
- `src/canvas_concept.dart` — 画布容器（成员 = 外观位置键，拖入 = UIMove 直写）
- `src/connection_concept.dart` — 连接关系（L1：`references={from,to}`，无向）
- `src/node_commands.dart` — 节点命令 Handler（create/update/delete 级联/restore/connect；
  DTO 从 core 词表再导出）
- `src/node_card.dart` — 卡片壳（拖拽/右键菜单/连接判定 + GenericNodeCardBody 兜底）
- `src/node_dialogs.dart` / `graph_nodes_dialog.dart` / `node_style_dialog.dart` — 编辑/可见性/样式对话框
- `src/layout/` — 布局（力导向/网格/树状 + ApplyLayoutCommand + 对话框）

### `node_ai` — AI 插件

- `ai_plugin.dart` — AIPlugin：AIConcept/ChatConcept/AIPanelConcept + 命令 Handler + 工具注册
- `src/ai_concept.dart` — AI 节点（L0 容器，kind=='ai'）
- `src/chat_concept.dart` — 对话会话（L1：`references={ai,source}`，消息 = content markdown）
- `src/chat_commands.dart` / `chat_handlers.dart` — AppendMessage（快）/ AskAI（长任务）命令
- `src/chat_messages.dart` — 消息序列化（`**用户**`/`**AI**` 分段）
- `src/ai_provider.dart` + `ai_provider_config.dart` — Provider 接口 + Mock（默认）/ OpenAI 实现
- `src/ai_chat_view.dart` — 会话列表 + 消息流 + 输入框
- `src/ai_settings.dart` — AI 设置条目（key/model/baseUrl，P1-1 持久化）
- `src/ai_panel_concept.dart` + `ai_panel_commands.dart` — 侧边栏 AI 面板（拖入建面板实例）
- `src/ai_card_view.dart` — 画布卡片体
- `src/function_calling/` — Function Calling：工具注册表/参数校验/循环（maxIterations=10）+
  4 个节点操作工具（**DTO 走 core 词表**，P2-2 消除 node_graph 依赖）

### `node_lua` — Lua 插件

- `lua_plugin.dart` — LuaPlugin：脚本加载 + 引擎生命周期 + 宿主写 API 桥
- `src/lua_engine.dart` — LuaEngine（vendored 运行时封装 + 沙箱 + `__call_host` 单 C 回调）
- `src/lua_concept.dart` — 动态 Concept（脚本化 validate/createHook 桥接）
- `src/lua_handlers.dart` — Lua 命令路由 + LuaWriteHandler（写操作唯一执行者仍是 Dart Handler）
- `src/lua_script_loader.dart` — 脚本解析（Concept 表/Commands 表）
- `src/lua_commands.dart` — Lua 命令 DTO
- `src/vendor/lua_runtime.dart` + `lua_bindings.dart` — ffi 绑定（assets/lua54.dll，多级探测加载）
- 已知限制：执行超时未实现 [计划]（COMMAND_LINE_GUIDE.md 安全沙箱节）

### `node_editor` — 编辑器插件

- `editor_plugin.dart` — EditorPlugin：NoteConcept + SaveNoteHandler
- `src/editor_concept.dart` — 笔记 Concept（普通笔记，L0）
- `src/save_note.dart` — SaveNoteCommand（写路径，inverse 对偶，P1-2）
- `src/markdown_editor_view.dart` — 编辑 + 简单预览
- `src/note_row_view.dart` / `note_card_view.dart` — 侧边栏行 / 画布卡片体

### `node_converter` — 导入导出插件

- `converter_plugin.dart` — ConverterPlugin + 'converter.open' 工具栏动作
- `src/converter_commands.dart` — Export/Import 命令 DTO
- `src/converter_handlers.dart` — JSON 往返保真 + markdown 聚合/拆分（导入宽容：坏条目跳过；
  markdown 幂等 id = `imported-<slug>`）

### `node_search` — 搜索插件

- `search_plugin.dart` — SearchPlugin（SearchService 服务注册）
- `src/search_service.dart` — 标题/内容包含匹配（大小写不敏感，纯读侧）
- `src/search_panel.dart` — SearchPanelConcept + 侧边栏面板（输入 + 结果 + 打开节点 Hook）

### `node_i18n` — 国际化插件

- `i18n_plugin.dart` — I18nPlugin：I18nSettingsConcept 贡献
- `src/i18n_settings.dart` — 语言设置条目（kind=='settings-i18n'）+ 切换表单（编辑**壳层
  I18nService**——服务本体在 appframe，插件互不依赖下语言包全局可达，01 #51）

### `node_settings` — 设置插件

- `settings_plugin.dart` — SettingsPlugin：4 个设置条目 Concept
- `src/settings_container.dart` — 设置容器（子级 = `references.settings` 反查聚合）
- `src/theme_settings.dart` — 主题条目 + 切换表单（编辑壳层 ThemeController）
- `src/appearance_settings.dart` — 外观条目（字体大小）
- `src/vault_settings.dart` — 仓库条目（多仓库管理 + **移除 = 确认 + `.trash/` 回收站**）
- `src/settings_entries_view.dart` — 设置容器内联铺开视图

### `node_market` — 插件市场插件

- `market_plugin.dart` — MarketPlugin
- `src/market_dialog.dart` — 已装插件静态列表（host.loadedPlugins，MVP 无网络）

### `node_data_recovery` — 数据恢复插件

- `recovery_plugin.dart` — RecoveryPlugin：Backup/Verify/Repair Handler
- `src/recovery_commands.dart` — 三命令 DTO
- `src/recovery_handlers.dart` — 备份（sidecar + ui-state.json → backups/<时间戳>）/
  校验（可解析 + 引用完整）/ 修复（删除损坏 sidecar）

## Dependency Injection Order

`HostRuntime`（`packages/appframe/lib/src/host/host_runtime.dart`）是组合根。构造体：

1. `FSTGraph` / `FSUIStateStore` / `HookIndex` / `WindowManagerImpl`（存储与登记）
2. `_viewportQuery` = 传入 ?? `QuadTreeViewportQuery(uiStateStore)`（P2-4 生产缺省）
3. `ExtensionRegistry` + `PluginCommandBus` + `UndoManager`（撤销栈，P1-2）
4. `PluginConceptRegistry`（扩展点派生查询器）
5. `ServiceCollection` 注册壳层服务：HostRuntime / Graph / UIStateStore / CommandBus /
   ToolbarActionRegistry / ShellSignals / ThemeController / I18nService /
   SidebarDropSemantics / ToolbarDropSemantics（插件经 `servicesProvider` 延迟解析——
   **不许在 onLoad 保存 provider 快照**，01 #47）
6. `themeController.attach(prefs)` / `i18nService.attach(prefs)`（P1-1 设置持久化回读）

`start()`：宿主贡献 Toolbar 概念与 MoveReferences/CreateToolbarButton Handler →
`PluginManager.loadPlugin` 逐个（拓扑序/回滚）→ `WindowedUIManager`（含视口查询）→
`commandBus.attach(uiManager.onWriteResult)` → `materializeRoot`（前端图从根建立，物化按需）。

## Data Persistence

以**数据根目录**（缺省 = 运行目录 `data/`；多仓库 = VaultManager 管理的独立目录）为根：

- **结构**：sidecar 分区 `data/.node/<nodeId前2位>/<id>.node.json`（256 分区；原子写 tmp+rename）
- **内容**：节点 content 即 markdown 文本（含在 sidecar / 文件层，可直接编辑）
- **外观**：`data/ui-state.json`（KV：`position.graph.<nodeId>` 画布位置、
  `camera.main.<hookId>` 相机矩阵、`style.graph.<nodeId>` 样式）
- **备份**：`data/backups/<时间戳>/`（BackupCommand）
- **Lua 脚本**：`data/lua_scripts/*.lua`（文件树可 git 管理）
- **仓库配置**：`<baseDir>/vaults.json`（多仓库清单，原子写）
- **设置**：SharedPreferences（主题/语言/AI key——app 层注入，重启保持）

## Command Pattern（03 §四）

```dart
// Command = 纯 DTO（name + payload；节点命令词表在 core/lib/src/command/node_commands.dart）
final result = await host.commandBus.dispatch<CreateNodeCommand, CreateNodeResult>(
  CreateNodeCommand(id: id, title: title, content: content),
);
// WriteResult = {affectedNodeIds, changeKind(structure/data/ui), inverse}
// inverse 非空 = 可撤销（UndoManager + Ctrl+Z/Ctrl+Y 全局快捷键）；
// 写后通知自动发布 → UIManager 失效路由 → InvalidationEvent → 呈现层定向重建
```

- **写操作唯一执行者 = Command Handler**（插件经 `commandHandlerPoint` 扩展点贡献）
- **读操作** = `Graph` 直读或插件读侧服务（无 QueryBus）
- **Handler 内禁止**：环校验缺失（写引用前必须 `AcyclicChecker.check`）、静默失败
  （失败 → 抛错/CommandResult.failure → UI 可读文案，架构 §8）
- **不可撤销写**（导出/备份/Lua 写等）允许 `inverse: null`——显式声明，不是遗漏

## Plugin Development

### Plugin Structure

```dart
class MyPlugin extends Plugin {   // package:plugon/plugon.dart
  @override
  PluginMetadata get metadata =>
      const PluginMetadata(id: 'com.example.my', name: '…', version: '1.0.0');

  @override
  void registerServices(ServiceCollection services) { /* 服务注册（owned 视图） */ }

  @override
  void registerExtensions(ExtensionRegistry registry) {
    registry.addContribution(conceptPoint, MyConcept(), ownerPluginId: metadata.id);
    registry.addContribution(commandHandlerPoint, MyHandler(), ownerPluginId: metadata.id);
  }

  @override
  Future<void> onLoad(PluginContext context) async {}
  @override
  Future<void> onEnable() async {}
  @override
  Future<void> onDisable() async {}
  @override
  Future<void> onUnload() async {}
}
```

服务解析经 `HostRuntime.serviceProvider`（**运行时求值**，勿保存 onLoad 快照，01 #47）。

### Adding a New Plugin

1. Create `packages/node_xxx/` with `pubspec.yaml`（`resolution: workspace` + 按需依赖
   core/core_data/appframe/plugon/flutter）
2. Add package path to root `pubspec.yaml` `workspace:` list
3. Add dependency in `packages/app/pubspec.yaml`
4. Register in `packages/app/lib/main.dart` 的 `pluginFactory`（装配顺序即加载顺序）
5. Run `dart pub get` from workspace root；`dart run tool/check_imports.dart` 校验依赖方向

### Hook / UI 呈现

- Hook 契约：`render(RenderContext)` 把 widget 加进 `FlutterRenderContext.sink`
- 物化入口：`host.uiManager.hookFor(nodeId, kind)` / `materializeIfAbsent(nodeId, kind)`
  （kind 感知：'graph' 画布卡片 / 'open' 对话框 / 侧边栏形态）
- 失效：订阅 `uiManager` 的 `InvalidationEvent`（structure → 重建；data → 定向重建）
- 画布窗口化：GraphCanvas 相机变化推 `onViewportChanged`（P2-4；可见集渲染）
- 插件提供卡片体（kind='graph'），未提供 → GenericNodeCardBody 兜底（永不空洞）

## Coding Standards

要点（本节为准；无独立 coding_standards 文件）：

- **Public APIs MUST have documentation comments**；复杂逻辑必须注释"为什么"
- **Public APIs MUST have type annotations**；构造器先于类成员；一文件一类
- Import order: Dart SDK → Flutter → Third-party → Project → Relative
- 禁 `print()`——用 `debugPrint()`；工具脚本用 `stdout.writeln`
- 文件 IO 用 `existsSync()`（禁 `await exists()`）；`withOpacity()` → `withValues(alpha:)`
- 使用类型化异常，禁裸 catch `Exception`
- **新 UI 文案必须进翻译表 zh+en**（`packages/appframe/lib/src/i18n/translations.dart`；
  `tool/check_hardcoded_strings.dart` 在 CI 强制——05 纪律 7）
- **设置类功能验收必须含"重启后保持"**；**错误路径验收必须含用户可见反馈**（05 纪律 6/8）

## Important Notes

### Architecture Patterns
1. **纯 DTO + Handler**：命令是数据，Handler 是唯一执行者（01-D；无旧 CQRS 执行模型）
2. **插件互相不依赖**：通信走 Command/数据引用；`tool/check_imports.dart` 强制
3. **Concept 匹配**：findFor 优先序（特异性 → 注册序）→ 兜底（永不空洞）
4. **三档判据**：结构（references）→ 数据（content）→ 外观（UIStateStore）——
   写结构必须走 CommandBus；外观直写（画布位置/样式）由渲染方自管
5. **UI 是 Hook 构成的图**：HookView 渲染物化 Hook；卡片体由成员节点自己的 Hook 提供

### Development Guidelines
1. **无 codegen**——改模型 = 改 `stored_node.dart` 手工序列化（不要引入 build_runner）
2. **依赖缺口是静默陷阱**：workspace 共享 package_config 会掩盖未声明依赖——
   pubspec 变更后必跑 `dart run tool/check_imports.dart`
3. **Flame 渲染栈不在仓库**（M7+ 资产）；画布 = InteractiveViewer（01 #23/#54）
4. **10⁶ 现状**：窗口化渲染已接线（P2-4）；LOD/增量索引/回收/10⁶ 基准数字 = [计划]
   （architecture.md §7）
5. **每步原子提交**；`git status` 干净再收工（05 纪律 3）
6. **测试数字区分自有/vendored**：plugon 117 为上游；"全绿"以 CI 输出为口径（05 纪律 12）

### Lua Scripting
1. **脚本位置** → 数据根 `data/lua_scripts/`
2. **安全** → 沙箱（os/io/package/require/debug/load* 禁用）+ 坏脚本隔离 +
   引擎不可用降级（不崩溃启动）；执行超时未实现 [计划]
3. **动态 hooks** → 脚本化 Concept（validate/createHook）+ `Commands` 表 + 宿主写 API
   （`host.node_create/update/delete` 经 C 回调 → 同步 LuaWriteHandler → 写后广播）
4. **API 契约** → 返回值 `"affected:<ids>;<kind>"` / `"error:<消息>"` / `"ok"`

## Additional Documentation

- `docs/rewrite/00-philosophy.md` ~ `04-glue-engineering.md` — 设计文档（是什么/为什么）
- `docs/rewrite/architecture.md` — 落地架构（谁写、写在哪、时序；10⁶ 未交付项已标 [计划]）
- `docs/rewrite/01-responsibilities.md` — 职责矩阵 + 逐日拍板回填（决策日志）
- `docs/rewrite/05-lessons-and-disciplines.md` — 审计复盘：12 条纪律 + 整改清单回填
- `docs/COMMAND_LINE_GUIDE.md` - Lua 脚本编写指南（含安全沙箱）
- `packages/plugon/docs/ARCHITECTURE.md` - plugon（vendored）契约文档
