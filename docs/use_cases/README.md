# Node Graph Notebook 用例流程规范

## 概述

本文档定义了 Node Graph Notebook 应用程序的完整用户用例流程，包括调用链和数据流规范。适用于 AIGC 软件工程师理解系统架构、开发新功能和排查问题。

## 项目架构

Node Graph Notebook 采用**插件化架构**和 **CQRS 模式**，主要包含以下层次：

```
┌─────────────────────────────────────────────────┐
│                  UI Layer (Flutter)              │
│  HomePage, Toolbars, Sidebars, Dialogs, Views    │
└──────────────────────────────────────────────────┘
                        │
┌──────────────────────────────────────────────────┐
│              Plugin System (Hooks/BLoC)           │
│  Graph, AI, Lua, Converter, Search, Editor...    │
└──────────────────────────────────────────────────┘
                        │
┌──────────────────────────────────────────────────┐
│            CQRS Layer (Command/Query)             │
│  CommandBus, QueryBus, CommandHandlers,           │
│  QueryHandlers, Middleware Pipeline               │
└──────────────────────────────────────────────────┘
                        │
┌──────────────────────────────────────────────────┐
│              Core Services Layer                  │
│  NodeService, GraphService, AIService,            │
│  LuaEngineService, ConverterService...            │
└──────────────────────────────────────────────────┘
                        │
┌──────────────────────────────────────────────────┐
│              Repository Layer                     │
│  NodeRepository, GraphRepository                  │
│  (File System based storage)                      │
└──────────────────────────────────────────────────┘
```

## 核心组件

| 组件 | 职责 | 位置 |
|------|------|------|
| **CommandBus** | 命令分发、中间件管道、事件发布 | `lib/core/cqrs/commands/command_bus.dart` |
| **QueryBus** | 查询分发、查询缓存、读模型 | `lib/core/cqrs/query/query_bus.dart` |
| **PluginManager** | 插件生命周期管理、依赖注入 | `lib/core/plugin/plugin_manager.dart` |
| **ExecutionEngine** | CPU密集型任务执行（worker pool） | `lib/core/execution/execution_engine.dart` |
| **ServiceRegistry** | 服务注册与依赖注入 | `lib/core/plugin/service_registry.dart` |
| **HookRegistry** | UI Hook 注册与执行 | `lib/core/plugin/ui_hooks/hook_registry.dart` |

## 用例流程文档索引

| 文档 | 描述 | 适用场景 |
|------|------|----------|
| [01_node_management.md](./01_node_management.md) | 节点的创建、更新、删除、查询等操作的完整调用链 | 知识管理、笔记编辑 |
| [02_graph_management.md](./02_graph_management.md) | 图的创建、加载、节点连接、布局等操作 | 知识图谱可视化 |
| [03_ai_integration.md](./03_ai_integration.md) | AI对话、Function Calling、节点分析等AI功能 | AI辅助知识整理 |
| [04_plugin_system.md](./04_plugin_system.md) | 插件加载、卸载、启用、禁用、Hook注册等 | 系统扩展、插件开发 |
| [05_import_export.md](./05_import_export.md) | Markdown导入导出、数据转换等操作 | 数据迁移、备份 |
| [06_lua_automation.md](./06_lua_automation.md) | Lua脚本编写、执行、动态Hook等自动化功能 | 工作流自动化 |
| [07_search_query.md](./07_search_query.md) | 节点搜索、高级查询、搜索索引等 | 知识检索 |

## 数据流规范

### 写操作流（Command）

```
用户操作 → UI组件 → BLoC Event → Command → CommandBus
  → Middleware Pipeline → CommandHandler → Service → Repository
  → 文件系统 → CommandResult → AppEvent → BLoC State → UI更新
```

### 读操作流（Query）

```
用户操作 → UI组件 → BLoC Event → Query → QueryBus
  → Query Cache (可选) → QueryHandler → Repository
  → 文件系统 → QueryResult → BLoC State → UI更新
```

### 事件流

```
CommandHandler/QueryHandler → CommandContext.publishEvent()
  → CommandBus.eventStream → BLoC订阅 → State更新 → UI重建
```

## 中间件链

CommandBus 中间件按以下顺序执行：

1. **LoggingMiddleware** - 日志记录（包含时间戳和耗时）
2. **TransactionMiddleware** - 事务管理
3. **ValidationMiddleware** - 命令验证
4. **UndoMiddleware** - 撤销/重做支持

## 插件Hook点

系统提供以下标准Hook点：

| Hook点 | 描述 | 上下文类型 |
|--------|------|------------|
| `main.toolbar` | 主工具栏 | MainToolbarHookContext |
| `graph.toolbar` | 图工具栏（可拖动） | MainToolbarHookContext |
| `context_menu.node` | 节点右键菜单 | NodeContextMenuHookContext |
| `context_menu.graph` | 图右键菜单 | GraphContextMenuHookContext |
| `sidebar.bottom` | 侧边栏底部 | SidebarHookContext |
| `status.bar` | 状态栏 | StatusBarHookContext |
| `help` | 帮助菜单 | HelpHookContext |
| `lua.script_menu` | Lua脚本菜单 | HookContext |
| `import_export` | 导入导出 | ImportExportHookContext |

## 约定和术语

| 术语 | 定义 |
|------|------|
| **Command** | 写操作请求，改变系统状态 |
| **Query** | 读操作请求，不改变系统状态 |
| **Handler** | Command/Query 的具体执行逻辑 |
| **Middleware** | Command 执行的横切关注点（日志、事务等） |
| **Plugin** | 扩展系统功能的模块 |
| **Hook** | 插件插入UI的扩展点 |
| **BLoC** | 业务逻辑组件，管理UI状态 |
| **Service** | 业务服务层，封装复杂业务逻辑 |
| **Repository** | 数据访问层，负责数据持久化 |
