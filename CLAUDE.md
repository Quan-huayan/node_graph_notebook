# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Node Graph Notebook** is a Flutter-based concept-map visualization notebook that rethinks note organization using a node-based architecture. The core philosophy is "All is node!!" — all content elements (text, concepts, relationships) are unified as nodes with graph-based visualization powered by the Flame game engine.

### Key Features

- Node-based note organization with concept mapping
- Markdown editing and rendering
- Interactive graph visualization using Flame game engine
- AI integration framework
- Plugin system for extensibility
- Data import/export functionality
- Theme customization (light/dark modes)
- Lua scripting support for automation
- Internationalization (i18n) support

## Workspace Architecture

The project uses a **Dart Workspace** monorepo structure. The root `pubspec.yaml` defines the workspace, and all packages reside under `packages/`.

### Package Dependency Graph

```
core_data (纯数据模型 + 仓库接口)
    ↑
core (CQRS, 插件系统, 中间件, 服务, UI布局)
    ↑
appframe (UI框架: BLoC, 页面, 工具栏, 侧边栏, Hook上下文)
    ↑
┌───────┬────────┬────────┬────────┬────────┐
graph   editor   folder   layout   search   ... (插件包)
│       │        │        │        │
└───┬───┘        │        │        │
    ↑            │        │        │
converter  ←─────┘        │        │
ai  ←─────────────────────┘        │
lua  ←─────────────────────────────┘
    ↑
app (应用入口, 组装所有包, 依赖注入)
```

### Package List

| Package | Name | Description |
|---------|------|-------------|
| `core_data` | `core_data` | 纯数据模型 (Node, Graph, Connection, NodeReference) + 仓库抽象接口 (NodeRepository, GraphRepository) |
| `core` | `core` | 核心框架: CQRS (CommandBus/QueryBus), 插件系统, 中间件, 服务, UI布局, 执行引擎 |
| `repository_fs` | `repository_fs` | 文件系统仓库实现: NodeRepository/GraphRepository 的 Markdown+JSON 持久化 |
| `appframe` | `appframe` | 应用框架层: UIBloc, 页面, 工具栏, 侧边栏, Hook上下文定义 |
| `app` | `app` | 应用入口: main.dart, 依赖注入组装, 内置插件加载 |
| `graph` | `node_graph` | 图可视化插件: Flame渲染, 节点/连接组件, BLoC, 命令处理器 |
| `ai` | `node_ai` | AI集成插件: 聊天, 分析, Function Calling工具 |
| `editor` | `node_editor` | Markdown编辑器插件: 编辑, 预览, 编辑面板Hook |
| `converter` | `node_converter` | 导入导出插件: Markdown/JSON 导入导出, 转换配置 |
| `search` | `node_search` | 搜索插件: 节点搜索, 预设管理, 侧边栏面板 |
| `layout` | `node_layout` | 布局引擎插件: 布局算法, 增量布局, 布局菜单 |
| `folder` | `node_folder` | 文件夹管理插件: 树视图, 侧边栏, 节点模板 |
| `lua` | `node_lua` | Lua脚本插件: 脚本引擎, 动态Hook, 命令服务器 |
| `i18n` | `node_i18n` | 国际化插件: 翻译管理, 语言切换Hook |
| `settings_plugin` | `node_settings` | 设置插件: 设置对话框, 工具栏Hook |
| `market` | `node_market` | 插件市场插件: 市场UI |
| `data_recovery_plugin` | `node_data_recovery` | 数据恢复插件: 备份, 修复, 验证命令及处理器 |

## Architecture Pattern

```
UI Layer (Widgets in appframe/插件包)
    ↓
BLoC Layer (UI State Management)
    ↓
CommandBus/QueryBus (Business Logic Gateway, in core)
    ↓
Command/Query Handlers (Business Logic, in core or 插件包)
    ↓
Services/Repositories (Data Access, in core_data + repository_fs)
```

**Important Patterns:**
- ✅ **Write operations** → Use `CommandBus.dispatch(command)` (automatically publishes events)
- ✅ **Read operations** → Use `QueryBus.dispatch(query)` for complex queries with caching, or Repository directly for simple queries
- ✅ **BLoCs** → Only manage UI state (isLoading, error, selection)
- ✅ **Event subscription** → Subscribe to `CommandBus.eventStream` for data changes
- ✅ **Plugins** → Extend functionality via hooks, services, and middleware

## Development Commands

### Essential Commands

```bash
# Install dependencies (run from workspace root)
dart pub get

# Generate JSON serialization code (required after model changes in core_data)
dart run build_runner build --delete-conflicting-outputs

# Run the app (from packages/app)
cd packages/app
flutter run

# Run tests
flutter test

# Code analysis
dart analyze

# Build Windows release (from packages/app)
cd packages/app
flutter build windows

# Format code
dart format .
```

**Before Running:** After pulling changes or modifying models in `packages/core_data/lib/src/models/`, always run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Package Details

### `core_data` — 纯数据模型与仓库接口

零业务逻辑的纯数据层，所有其他包均可依赖。

**Models** (`src/models/`):
- `node.dart` - 统一节点模型，所有内容元素的基类，支持 YAML frontmatter 元数据
- `graph.dart` - 图模型，管理节点连接关系
- `connection.dart` - 连接模型，定义节点间关系
- `node_reference.dart` - 节点引用对象
- `enums.dart` - 核心枚举 (NodeType, ViewMode 等)
- `converters.dart` - JSON 序列化转换器

**Repository Interfaces** (`src/repositories/`):
- `node_repository.dart` - 节点仓库抽象接口 (save, load, delete, search, queryAll)
- `graph_repository.dart` - 图仓库抽象接口
- `metadata_index.dart` - 元数据索引
- `exceptions.dart` - 仓库异常定义

### `core` — 核心框架

提供 CQRS、插件系统、中间件、服务等核心基础设施。依赖 `core_data`。

**CQRS Command System** (`cqrs/commands/`):
- `command_bus.dart` - 命令总线，集中命令分发，中间件管道，集成事件发布
- `command_handler_registry.dart` - 命令处理器注册与查找
- `models/command.dart` - Command 基类，支持 undo
- `models/command_context.dart` - 命令执行上下文
- `models/command_handler.dart` - Handler 接口
- `models/middleware.dart` - 中间件接口
- `events/app_events.dart` - 应用事件定义
- `events/event_subscription_manager.dart` - 事件订阅生命周期管理

**CQRS Query System** (`cqrs/query/`):
- `query_bus.dart` - 查询总线，LRU 缓存 (1000 条目)
- `query.dart` - Query 基类与接口
- `query_cache.dart` - LRU 缓存实现

**Query Definitions** (`cqrs/queries/`):
- `load_node_query.dart` - 单节点/批量/全部加载查询
- `list_nodes_query.dart` - 节点列表查询 (ReadModel)
- `search_nodes_query.dart` - 节点搜索查询
- `advanced_search_query.dart` - 高级搜索查询
- `graph_query.dart` - 图结构查询 (邻居/引用/路径/度)
- `search_index_query.dart` - 搜索索引查询

**Query Handlers** (`cqrs/handlers/`):
- `load_node_handler.dart`, `list_nodes_handler.dart`, `search_nodes_handler.dart`
- `advanced_search_handler.dart`, `graph_query_handler.dart`, `search_index_handler.dart`

**Read Models & Materialized Views** (`cqrs/`):
- `read_models/node_read_model.dart` - 读优化节点数据模型
- `materialized_views/search_index_view.dart` - 物化搜索索引

**Plugin System** (`plugin/`):
- `plugin.dart` / `plugin_base.dart` - Plugin 接口与基类
- `plugin_manager.dart` - 插件生命周期管理
- `plugin_context.dart` - 插件操作上下文
- `plugin_metadata.dart` - 插件元数据定义
- `plugin_lifecycle.dart` - 生命周期状态管理
- `plugin_registry.dart` - 插件注册与发现
- `plugin_discoverer.dart` - 自动插件发现
- `plugin_communication.dart` - 插件间通信
- `plugin_exception.dart` - 插件异常
- `dependency_resolver.dart` - 插件依赖解析
- `service_binding.dart` - 服务注册绑定
- `service_registry.dart` - 统一依赖注入容器
- `type_registry.dart` - 类型注册表 (接口→实现映射)
- `dynamic_provider_widget.dart` - 动态 Provider 树管理
- `api/api_registry.dart` - API 注册与查找
- `ui_hooks/` - UI Hook 系统:
  - `hook_base.dart`, `hook_context.dart`, `hook_lifecycle.dart`
  - `hook_registry.dart`, `hook_point_registry.dart`, `hook_priority.dart`
  - `hook_metadata.dart`, `hook_api_registry.dart`
- `middleware/` - 插件中间件:
  - `middleware_plugin.dart`, `middleware_pipeline.dart`, `middleware_registry.dart`

**Middleware** (`middleware/`):
- `logging_middleware.dart` - 命令执行日志
- `validation_middleware.dart` - 命令验证
- `transaction_middleware.dart` - 事务支持
- `undo_middleware.dart` - 撤销/重做
- `performance_middleware.dart` - 性能监控
- `cache_middleware.dart` - 缓存层

**Services** (`services/`):
- `settings_service.dart` - 应用设置管理
- `theme_service.dart` - 主题管理与切换
- `shortcut_manager.dart` - 键盘快捷键管理
- `i18n.dart` - 国际化服务
- `infrastructure/settings_registry.dart` - 设置注册
- `infrastructure/theme_registry.dart` - 主题注册
- `infrastructure/storage_path_service.dart` - 存储路径管理
- `theme/app_theme.dart` - 主题定义

**UI Layout System** (`ui_layout/`):
- `ui_layout_service.dart` - 中央布局管理服务
- `coordinate_system.dart` - 坐标系统管理
- `layout_strategy.dart` - 布局算法策略
- `node_template.dart` - 节点渲染模板
- `node_attachment.dart` - 节点附着系统
- `ui_hook_tree.dart` - UI Hook 树结构
- `rendering/` - 多渲染后端:
  - `renderer_base.dart`, `flame_renderer.dart`, `flutter_renderer.dart`
- `events/` - 布局事件:
  - `layout_events.dart`, `node_events.dart`

**Execution System** (`execution/`):
- `execution_engine.dart` - CPU/GPU 任务执行引擎
- `task_registry.dart` - 任务注册与管理
- `cpu_task.dart` - CPU 任务实现
- `gpu_executor.dart` - GPU 任务执行器

**Graph Data Structures** (`graph/`):
- `adjacency_list.dart` - 图邻接表实现

**Metadata** (`metadata/`):
- `metadata_validator.dart`, `metadata_schema.dart`, `standard_metadata.dart`

**Configuration** (`config/`):
- `feature_flags.dart` - Feature flag 管理

**Utilities** (`utils/`):
- `logger.dart`, `yaml_utils.dart`, `files.dart`, `safe_callback.dart`, `types.dart`

### `repository_fs` — 文件系统仓库实现

提供 `NodeRepository` 和 `GraphRepository` 的文件系统实现。要切换后端存储，替换此包并更新 `app` 中的依赖注入即可。

- `node_repository_fs.dart` - 节点 Markdown 文件存储
- `graph_repository_fs.dart` - 图 JSON 文件存储

### `appframe` — 应用框架层

提供 UI 框架组件，被所有插件包共享依赖。

**BLoC** (`bloc/`):
- `ui_bloc.dart` - 中央 UI 状态管理 (视图模式, 连接, 侧边栏, 工具栏)
- `ui_event.dart` - UI 事件
- `ui_state.dart` - UI 状态定义

**UI Components** (`ui/`):
- `pages/home_page.dart` - 主页面
- `bars/core_toolbar.dart` - 核心工具栏
- `bars/note_app_bar.dart` - 笔记应用栏
- `bars/sidebar.dart` - 侧边栏
- `dialogs/shortcut_help_dialog.dart` - 快捷键帮助
- `hooks/hook_bases.dart` - Hook 基类定义
- `hooks/hook_contexts.dart` - Hook 上下文定义 (MainToolbarHookContext, SidebarHookContext 等)
- `utilwidgets/highlight_text.dart` - 文本高亮

**Graph** (`graph/`):
- `quad_tree.dart` - QuadTree 空间索引

### `app` — 应用入口

组装所有包，配置依赖注入，加载内置插件。

- `main.dart` - 应用入口，初始化核心组件
- `app.dart` - NodeGraphNotebookApp，依赖注入组装，Provider 树构建
- `builtin_plugin_loader.dart` - 内置插件加载器

### `graph` — 图可视化插件

核心图可视化插件，使用 Flame 引擎渲染。

**BLoC** (`bloc/`):
- `graph_bloc.dart`, `graph_event.dart`, `graph_state.dart`
- `node_bloc.dart`, `node_event.dart`, `node_state.dart`

**Commands** (`command/`):
- `graph_commands.dart` - 图相关命令
- `node_commands.dart` - 节点相关命令

**Handlers** (`handler/`):
- `create_node_handler.dart`, `delete_node_handler.dart`, `update_node_handler.dart`
- `move_node_handler.dart`, `resize_node_handler.dart`, `update_node_position_handler.dart`
- `connect_nodes_handler.dart`, `disconnect_nodes_handler.dart`
- `create_graph_handler.dart`, `load_graph_handler.dart`, `update_graph_handler.dart`
- `add_node_to_graph_handler.dart`, `remove_node_from_graph_handler.dart`
- `rename_graph_handler.dart`

**Flame Rendering** (`flame/`):
- `graph_widget.dart` - Flame 游戏组件
- `graph_world.dart` - 根 Flame 组件
- `components/node_component.dart` - 节点渲染组件
- `components/connection_renderer.dart` - 连接线渲染
- `lod/lod_manager.dart` - LOD 细节层次管理
- `mixins/bloc_consumer.dart` - BLoC 集成
- `spatial_index_manager.dart` - QuadTree 空间索引
- `view_frustum_culler.dart` - 视锥裁剪
- `node_drag_controller.dart` - 节点拖拽控制
- `drag_feedback.dart` - 拖拽反馈

**Services** (`service/`):
- `graph_service.dart`, `node_service.dart` - 图/节点业务服务
- `node_context_menu.dart` - 节点上下文菜单
- `toolbar_settings_service.dart` - 工具栏设置

**Hooks** (`hooks/`):
- `graph_nodes_toolbar_hook.dart`, `refresh_graph_toolbar_hook.dart`, `toggle_connections_toolbar_hook.dart`

**Tasks** (`tasks/`):
- `connection_path_task.dart`, `node_sizing_task.dart`, `text_layout_task.dart`

### `ai` — AI 集成插件

- `function_calling/` - Function Calling 框架 (tool registry, parameter validation, 6个内置工具)
- `handler/analyze_node_handler.dart` - 节点分析处理器
- `service/ai_service.dart` - AI 服务
- `ui/` - AI 聊天/配置/测试对话框
- `ai_toolbar_hook.dart`, `ai_settings_hook.dart`

### `editor` — Markdown 编辑器插件

- `ui/markdown_editor_page.dart` - 编辑器页面
- `ui/markdown_preview_widget.dart` - 预览组件
- `ui/node_editor_panel_hook.dart` - 编辑面板 Hook

### `converter` — 导入导出插件

- `bloc/` - 转换器 BLoC
- `models/` - 转换配置、规则、验证、合并/拆分规则
- `service/` - 转换服务、导入导出服务
- `ui/` - 转换页面、导入导出对话框

### `search` — 搜索插件

- `bloc/` - 搜索 BLoC
- `model/` - 搜索预设、查询模型
- `handler/` - 搜索预设处理器
- `service/` - 搜索服务、预设服务
- `ui/` - 搜索侧边栏面板

### `layout` — 布局引擎插件

- `command/layout_commands.dart` - 布局命令
- `handler/apply_layout_handler.dart` - 布局处理器
- `service/` - 布局服务、增量布局引擎
- `ui/layout_menu.dart` - 布局菜单

### `folder` — 文件夹管理插件

- `ui/` - 文件夹树视图、选择器、节点列表
- `folder_node_template.dart` - 文件夹节点模板
- `folder_sidebar_tab_hook.dart` - 侧边栏 Tab Hook

### `lua` — Lua 脚本插件

- `bloc/` - Lua 脚本 BLoC
- `command/` - Lua 脚本 CRUD + 执行命令
- `handler/` - Lua 命令处理器
- `models/` - Lua 脚本模型、执行结果
- `service/` - Lua 引擎、安全沙箱、命令服务器、动态 Hook、函数注册

### `i18n` — 国际化插件

- `i18n/translations.dart` - 翻译管理
- `hooks/language_toggle_hook.dart` - 语言切换 Hook
- `service/i18n_service_binding.dart` - 服务绑定

### `settings_plugin` — 设置插件

- `ui/settings_dialog.dart` - 设置对话框
- `settings_toolbar_hook.dart` - 工具栏 Hook
- `settings_hook_base.dart` - 设置 Hook 基类

### `market` — 插件市场插件

- `market_plugin.dart` - 市场插件
- `market_toolbar_hook.dart` - 工具栏 Hook

### `data_recovery_plugin` — 数据恢复插件

- `command/` - 备份、修复、验证命令
- `handler/` - 备份、修复、验证处理器

## Dependency Injection Order

The application initializes dependencies in strict layers in `packages/app/lib/app.dart`:

1. **SharedPreferences** - 本地存储
2. **StoragePathService** - 存储路径管理
3. **Repositories** - FileSystemNodeRepository, FileSystemGraphRepository (from repository_fs)
4. **CommandBus** - 命令总线 + 中间件 (Logging, Transaction, Validation, Undo)
5. **Registries** - TaskRegistry, SettingsRegistry, ThemeRegistry
6. **ExecutionEngine** - 任务执行引擎
7. **UILayoutService** - 中央布局管理
8. **ServiceRegistry** - 统一 DI 容器 (TypeRegistry + coreDependencies)
9. **AdjacencyList** - 图邻接表
10. **QueryBus** - 查询总线 + 处理器注册
11. **I18n** - 国际化服务
12. **PluginManager** - 插件管理器
13. **Standard Hook Points** - 标准 Hook 点注册
14. **BuiltinPluginLoader** - 内置插件加载

**Provider Tree** (in `DynamicProviderWidget`):
1. `coreProviders` - 核心依赖 (Settings, Theme, Repositories, CommandBus, QueryBus, UILayoutService, I18n, HookRegistry, PluginManager) — 不重建
2. `serviceProviders` - 插件服务 (由 ServiceRegistry 动态生成) — 可重建
3. `blocProviders` - 插件 BLoC (由 PluginManager 动态生成) — 可重建

## Data Persistence

- **Nodes**: Markdown files with YAML frontmatter in `data/nodes/`
- **Graphs**: JSON files defining node connections in `data/graphs/`
- **Settings**: SharedPreferences for app configuration
- **Lua Scripts**: Stored in `data/lua_scripts/` and `data/scripts/`
- **Search Presets**: Stored in SharedPreferences via SearchPresetService

## BLoC Pattern

**BLoC Responsibilities:**

```dart
// ✅ CORRECT: BLoC manages UI state only
class NodeBloc extends Bloc<NodeEvent, NodeState> {
  Future<void> _onCreateNode(NodeCreateEvent event, Emitter emit) async {
    emit(state.copyWith(isLoading: true));

    final result = await _commandBus.dispatch(CreateNodeCommand(...));

    if (result.isSuccess) {
      emit(state.copyWith(
        nodes: [...state.nodes, result.data],
        isLoading: false,
      ));
    } else {
      emit(state.copyWith(isLoading: false, error: result.error));
    }
  }

  Future<void> _onLoadNodes(NodeLoadEvent event, Emitter emit) async {
    final nodes = await _nodeRepository.queryAll();
    emit(state.copyWith(nodes: nodes));
  }
}

// ❌ WRONG: Business logic in BLoC
class NodeBloc extends Bloc<NodeEvent, NodeState> {
  Future<void> _onCreateNode(NodeCreateEvent event, Emitter emit) async {
    final node = Node(id: uuid.v4(), title: event.title);
    await _nodeRepository.save(node);
    emit(state.copyWith(nodes: [...state.nodes, node]));
  }
}
```

**Event Bus Pattern:**

```dart
// Command Handlers automatically publish events via CommandBus
// BLoCs subscribe to CommandBus.eventStream for updates
commandBus.eventStream.listen((event) {
  if (event is NodeDataChangedEvent) {
    add(NodeDataChangedInternalEvent(...));
  }
});
```

## Plugin Development

### Plugin Structure

Plugins are self-contained packages under `packages/`:

```
packages/{plugin_name}/
├── lib/
│   ├── command/        # Command definitions (optional)
│   ├── handler/        # Command handlers (optional)
│   ├── service/        # Business logic services (optional)
│   ├── bloc/           # State management BLoCs (optional)
│   ├── ui/             # UI components (optional)
│   ├── models/         # Plugin-specific models (optional)
│   ├── hooks/          # UI hook registrations (optional)
│   ├── {name}.dart     # Library barrel file
│   └── {name}_plugin.dart  # Main plugin class
└── pubspec.yaml
```

### Quick Plugin Template

```dart
class MyPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.myPlugin',
    name: 'My Plugin',
    version: '1.0.0',
    dependencies: [],
  );

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  List<CommandHandlerBinding> registerCommandHandlers() => [];

  @override
  List<ServiceBinding> registerServices() => [];
}
```

### Adding a New Plugin

1. Create package directory under `packages/`
2. Add `pubspec.yaml` with `resolution: workspace` and dependencies on `core`, `appframe`, `core_data`
3. Add package path to root `pubspec.yaml` workspace list
4. Add dependency in `packages/app/pubspec.yaml`
5. Import and register in `packages/app/lib/builtin_plugin_loader.dart`
6. Run `dart pub get` from workspace root

### UI Hook System

**Available Hook Points:**
- `main.toolbar` - 主工具栏
- `graph.toolbar` - 图工具栏
- `context_menu.node` / `context_menu.graph` - 上下文菜单
- `sidebar.bottom` - 侧边栏底部
- `status.bar` - 状态栏
- `help` - 帮助

**Lua Dynamic Hooks:**
```lua
registerHook("main.toolbar", function(ctx)
    ctx:addButton("myButton", "Click Me", function()
        print("Button clicked!")
    end)
end)
```

## Coding Standards

This project follows strict coding standards defined in `docs/coding_standards.md`. Key points:

### Type Annotations
- **Public APIs MUST have type annotations**
- Private methods may omit types for brevity
- Use `??` for null-aware operations

### Flutter/Flame Specific
- Use `const` constructors wherever possible
- Flame components: cache Paint/Text objects, don't allocate in `render()`
- Use `existsSync()` instead of `await exists()`
- `withOpacity()` → use `withValues(alpha:)`
- `HasGameRef` → use `HasGameReference`

### Error Handling
- Use typed exceptions, not generic `Exception`
- Avoid catching generic `Exception` - catch specific types
- Implement proper error recovery

### Code Organization
- **Constructors first** - before any class members
- One class per file
- Import order: Dart SDK → Flutter → Third-party → Project → Relative

### Documentation & Comments
- **Public APIs MUST have documentation comments**
- **Complex logic MUST include inline comments** explaining the "why"
- **Architectural decisions MUST be documented**

## Important Notes

### Architecture Patterns
1. **CQRS Pattern**: Separate read (QueryBus with caching) and write (CommandBus with auto-events) operations
2. **Event-Driven**: CommandBus automatically publishes events to eventStream after command execution
3. **Plugin Architecture**: Extend functionality via plugins, not direct modifications
4. **Unified DI**: Single DI container (ServiceRegistry) supporting both Provider and dynamic plugin loading
5. **UI Layout System**: Flexible rendering with multiple backends (Flame/Flutter)
6. **Workspace Monorepo**: All packages share a single Dart workspace

### Development Guidelines
1. **Always regenerate code** after modifying models with `@JsonSerializable` annotation
2. **Provider dependency order is critical** - see dependency injection order above
3. **Don't use `print()`** - use `debugPrint()` or LoggingMiddleware
4. **File I/O should be async** - avoid blocking the UI thread
5. **Flame performance** - cache resources, don't allocate in render()
6. **Error recovery** - app has built-in data recovery on initialization failures
7. **Workspace commands** - run `dart pub get` from workspace root, `flutter run` from `packages/app`

### Command Bus Usage
1. **Write operations** → Always use `CommandBus.dispatch(command)`
2. **Read operations** → Use `QueryBus.dispatch(query)` for complex queries with caching, or Repository directly for simple queries
3. **Business logic** → Implement in Command Handlers, not in BLoCs or Services
4. **Event publishing** → Automatic via CommandBus.eventStream
5. **Undo support** → Implement `undo()` method in Command if operation should be undoable

### BLoC Best Practices
1. **BLoC responsibilities** → Only manage UI state (isLoading, error, selection)
2. **No business logic in BLoCs** → Delegate to CommandBus
3. **Subscribe to CommandBus.eventStream** → React to data changes from other components
4. **Initial events** → Always add initial events when creating BLoCs
5. **State updates** → Update state based on CommandResult, not directly

### Plugin Development
1. **Plugin location** → Create as a separate package under `packages/`
2. **Plugin dependencies** → Always declare in metadata to ensure correct load order
3. **Plugin lifecycle** → Use `onLoad()` for initialization, `onEnable()` for activation
4. **Service registration** → Use `registerServices()` to provide plugin services
5. **Command handlers** → Register via `registerCommandHandlers()` method
6. **UI Hooks** → Extend UI at specific hook points via HookRegistry
7. **API exports** → Export APIs via `exportAPIs()` for inter-plugin communication

### Lua Scripting
1. **Script location** → Store scripts in `data/lua_scripts/` or `data/scripts/`
2. **Security** → Lua scripts run in sandboxed environment with limited APIs
3. **Dynamic hooks** → Scripts can register UI hooks at runtime
4. **Event handling** → Scripts can listen to and emit events
5. **API access** → Available APIs: node operations, graph operations, UI hooks, messaging

See `docs/COMMAND_LINE_GUIDE.md` for complete Lua scripting documentation.

## Additional Documentation

- `docs/coding_standards.md` - Detailed coding standards and conventions
- `docs/COMMAND_LINE_GUIDE.md` - Command line and Lua scripting guide
- `docs/flowing_ui_architecture.md` - Flowing UI architecture design
- `docs/project_module_report.md` - Project module report
- `docs/use_cases/` - Use case documentation
