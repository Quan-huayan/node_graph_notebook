# Node Graph Notebook 项目模块分工报告

> 生成日期：2026-03-30  
> 项目技术栈：Flutter / Dart  
> 架构模式：CQRS + 插件化架构

---

## 目录

1. [项目概述](#一项目概述)
2. [架构总览](#二架构总览)
3. [核心层模块](#三核心层core)
4. [插件层模块](#四插件层plugins)
5. [UI层模块](#五ui层)
6. [测试覆盖](#六测试覆盖)
7. [模块依赖关系](#七模块依赖关系)
8. [团队分工建议](#八团队分工建议)

---

## 一、项目概述

**Node Graph Notebook** 是一个基于 Flutter 的节点图笔记本应用，支持：

- 可视化节点编辑与连接
- Markdown 内容编辑
- Lua 脚本扩展
- AI 功能集成
- 多格式数据导入导出

**代码规模**：约 200+ Dart 源文件

---

## 二、架构总览

### 2.1 分层架构图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            应用入口层                                    │
│                         main.dart / app.dart                            │
│                    (应用初始化、服务启动、插件加载)                        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              UI 层                                       │
│              ┌──────────┬──────────┬──────────┬──────────┐             │
│              │   bars   │   bloc   │ dialogs  │  pages   │             │
│              │ (工具栏) │(状态管理)│ (对话框) │  (页面)  │             │
│              └──────────┴──────────┴──────────┴──────────┘             │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                             插件层                                       │
│  ┌────────┬──────────┬─────────┬────────┬────────┬────────┬────────┐  │
│  │   ai   │converter │ editor  │ folder │ graph  │  lua   │ search │  │
│  │(AI功能)│(导入导出)│(编辑器) │(文件夹)│(图形)  │(脚本)  │ (搜索) │  │
│  └────────┴──────────┴─────────┴────────┴────────┴────────┴────────┘  │
│  ┌────────┬──────────┬─────────┬────────┬────────┐                    │
│  │  i18n  │  layout  │ market  │settings│delete  │                    │
│  │(国际化)│ (布局)   │ (市场)  │ (设置) │(删除)  │                    │
│  └────────┴──────────┴─────────┴────────┴────────┘                    │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                             核心层                                       │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                        基础设施层                                │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │   │
│  │  │ commands │ │   cqrs   │ │  events  │ │middleware│           │   │
│  │  │(命令总线)│ │(查询系统)│ │(事件系统)│ │(中间件)  │           │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                         插件框架层                               │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │   │
│  │  │  plugin  │ │ service  │ │   api    │ │ ui_hooks │           │   │
│  │  │(插件管理)│ │(服务注册)│ │(API注册) │ │(UI钩子)  │           │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                         数据层                                   │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │   │
│  │  │  models  │ │repositories│ │  graph  │ │metadata │           │   │
│  │  │(数据模型)│ │ (仓储层)  │ │(图结构)  │ │(元数据)  │           │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                         服务层                                   │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │   │
│  │  │ settings │ │  theme   │ │   i18n   │ │shortcut  │           │   │
│  │  │(设置服务)│ │(主题服务)│ │(国际化)  │ │(快捷键)  │           │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                         UI布局层                                 │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │   │
│  │  │ui_layout │ │coordinate│ │ renderer │ │  hook    │           │   │
│  │  │(布局服务)│ │(坐标系统)│ │ (渲染器) │ │(Hook树)  │           │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 数据流向图

```
┌─────────────┐     命令      ┌─────────────┐     执行     ┌─────────────┐
│    用户     │ ───────────▶ │  命令总线   │ ───────────▶ │  处理器     │
│  (UI交互)   │              │ CommandBus  │              │  Handler    │
└─────────────┘              └─────────────┘              └─────────────┘
      ▲                            │                            │
      │                            │                            │
      │                            ▼                            │
      │                     ┌─────────────┐                     │
      │                     │  中间件链   │                     │
      │                     │ Middleware  │                     │
      │                     └─────────────┘                     │
      │                            │                            │
      │                            ▼                            ▼
      │                     ┌─────────────┐              ┌─────────────┐
      │                     │  事件发布   │              │  仓储层     │
      │                     │   Events    │              │ Repository  │
      │                     └─────────────┘              └─────────────┘
      │                            │                            │
      │                            │                            │
      └────────────────────────────┴────────────────────────────┘
                          状态更新通知
```

### 2.3 插件系统架构图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          PluginManager                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │  PluginRegistry │  │ ServiceRegistry │  │    ApiRegistry   │         │
│  │   (插件注册表)   │  │   (服务注册表)   │  │   (API注册表)    │         │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘         │
│           │                    │                    │                   │
│           └────────────────────┼────────────────────┘                   │
│                                │                                        │
│                                ▼                                        │
│                    ┌─────────────────────┐                              │
│                    │ DependencyResolver  │                              │
│                    │    (依赖解析器)      │                              │
│                    │   - 拓扑排序        │                              │
│                    │   - 循环依赖检测     │                              │
│                    └─────────────────────┘                              │
└─────────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           插件生命周期                                   │
│                                                                         │
│   ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐            │
│   │ Discovered│──▶│ Loaded  │──▶│ Enabled │──▶│ Active  │            │
│   │  (发现)   │    │ (加载)  │    │ (启用)  │    │ (激活)  │            │
│   └─────────┘    └─────────┘    └─────────┘    └─────────┘            │
│        │                              │                                │
│        │         ┌─────────┐          │         ┌─────────┐           │
│        └────────▶│  Error  │◀─────────┴────────▶│Disabled │           │
│                  │  (错误)  │                    │ (禁用)  │           │
│                  └─────────┘                    └─────────┘           │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 三、核心层（core）

### 3.1 命令系统 (commands)

```
core/commands/
├── command_bus.dart              # 命令总线核心
├── command_handler_registry.dart # 处理器注册表
└── models/
    ├── command.dart              # 命令基类
    ├── command_handler.dart      # 处理器接口
    ├── command_context.dart      # 命令上下文
    └── middleware.dart           # 中间件接口
```

**职责**：实现命令的分发、中间件执行、事件发布

**核心类**：
| 类名 | 职责 |
|------|------|
| `CommandBus` | 命令总线核心，提供统一的分发点 |
| `Command` | 命令基类，所有业务操作的抽象 |
| `CommandHandler<T>` | 命令处理器接口 |
| `CommandResult` | 命令执行结果封装 |
| `CommandContext` | 命令执行上下文 |

**关键路径**：`Command` -> `CommandBus` -> `Middleware` -> `Handler` -> `CommandResult`

---

### 3.2 CQRS 查询系统 (cqrs)

```
core/cqrs/
├── query/
│   ├── query_bus.dart          # 查询总线
│   ├── query.dart              # 查询基类
│   └── query_cache.dart        # 查询缓存
├── handlers/                    # 查询处理器
│   ├── advanced_search_handler.dart
│   ├── graph_query_handler.dart
│   ├── load_node_handler.dart
│   ├── list_nodes_handler.dart
│   └── search_index_handler.dart
├── queries/                    # 查询定义
│   ├── advanced_search_query.dart
│   ├── graph_query.dart
│   ├── load_node_query.dart
│   └── search_nodes_query.dart
├── read_models/
│   └── node_read_model.dart
└── materialized_views/
    └── search_index_view.dart
```

**职责**：查询调度、缓存、读模型和物化视图

**核心类**：
| 类名 | 职责 |
|------|------|
| `QueryBus` | 查询总线，调度和执行查询 |
| `Query` | 查询基类 |
| `QueryCache` | 查询结果缓存 |
| `NodeReadModel` | 节点读模型 |
| `SearchIndexView` | 搜索索引物化视图 |

---

### 3.3 事件系统 (events)

```
core/events/
├── app_events.dart             # 应用事件定义
└── event_subscription_manager.dart # 订阅管理
```

**职责**：定义事件类型和管理事件订阅

**核心事件**：
| 事件名 | 触发时机 |
|--------|----------|
| `NodeDataChangedEvent` | 节点数据变化 |
| `GraphNodesChangedEvent` | 图节点关系变化 |
| `PluginLoadedEvent` | 插件加载完成 |
| `ConnectionCreatedEvent` | 连接创建 |
| `NodeMovedEvent` | 节点移动 |

---

### 3.4 执行引擎

```
core/execution/
├── execution_engine.dart        # 跨Isolate执行引擎
├── cpu_task.dart               # CPU任务定义
├── gpu_executor.dart           # GPU执行器
└── task_registry.dart          # 任务注册表
```

**职责**：跨Isolate的CPU密集型任务执行

**核心类**：
| 类名 | 职责 |
|------|------|
| `ExecutionEngine` | 执行引擎核心 |
| `CpuTask` | CPU任务抽象 |
| `GpuExecutor` | GPU计算执行 |
| `TaskRegistry` | 任务注册管理 |

---

### 3.5 图数据结构

```
core/graph/
├── adjacency_list.dart         # 邻接表实现
├── spatial/
│   └── quad_tree.dart          # 四叉树空间索引
└── partition/
    ├── graph_partitioner.dart  # 图分区器
    └── subgraph_cache.dart     # 子图缓存
```

**职责**：图邻接关系维护、空间索引、图分区

**核心类**：
| 类名 | 职责 |
|------|------|
| `AdjacencyList` | 邻接表，维护图的邻接关系 |
| `QuadTree` | 四叉树空间索引 |
| `GraphPartitioner` | 图分区算法 |
| `SubgraphCache` | 子图缓存 |

---

### 3.6 元数据系统

```
core/metadata/
├── metadata_schema.dart        # Schema定义
├── metadata_validator.dart     # 验证器
└── standard_metadata.dart      # 标准元数据
```

**职责**：元数据Schema定义和验证

**核心类**：
| 类名 | 职责 |
|------|------|
| `MetadataSchema` | 元数据Schema定义 |
| `MetadataValidator` | 元数据验证逻辑 |
| `StandardMetadata` | 标准元数据常量 |

---

### 3.7 中间件系统

```
core/middleware/
├── cache_middleware.dart       # 缓存中间件
├── logging_middleware.dart     # 日志中间件
├── performance_middleware.dart # 性能监控
├── transaction_middleware.dart # 事务中间件
├── undo_middleware.dart        # 撤销/重做
└── validation_middleware.dart  # 验证中间件
```

**职责**：命令执行的横切关注点

**核心类**：
| 类名 | 职责 |
|------|------|
| `CacheMiddleware` | 命令结果缓存 |
| `LoggingMiddleware` | 操作日志记录 |
| `PerformanceMiddleware` | 性能监控统计 |
| `TransactionMiddleware` | 事务管理 |
| `UndoMiddleware` | 撤销/重做支持 |
| `ValidationMiddleware` | 命令验证 |

---

### 3.8 数据模型

```
core/models/
├── graph.dart                  # 图模型
├── node.dart                   # 节点模型
├── connection.dart             # 连接模型
├── node_reference.dart         # 节点引用
├── node_rendering.dart         # 节点渲染配置
├── enums.dart                  # 枚举定义
├── converters.dart             # 数据转换器
└── models.dart                 # 模型导出
```

**职责**：定义核心数据结构

**核心类**：
| 类名 | 职责 |
|------|------|
| `Graph` | 图模型，包含节点和连接 |
| `Node` | 节点模型 |
| `Connection` | 节点连接关系 |
| `NodeReference` | 节点引用 |
| `NodeRendering` | 节点渲染配置 |

---

### 3.9 插件系统核心

```
core/plugin/
├── plugin_manager.dart          # 插件管理器
├── plugin_base.dart             # 插件基类
├── plugin_registry.dart         # 插件注册表
├── plugin_lifecycle.dart        # 生命周期管理
├── plugin_metadata.dart         # 插件元数据
├── plugin_exception.dart        # 插件异常
├── plugin_discoverer.dart       # 插件发现
├── plugin_communication.dart    # 插件通信
├── dependency_resolver.dart     # 依赖解析器
├── service_registry.dart        # 服务注册表
├── service_binding.dart         # 服务绑定
├── builtin_plugin_loader.dart   # 内置插件加载器
├── dynamic_provider_widget.dart # 动态Provider组件
├── api/
│   └── api_registry.dart        # API注册表
├── middleware/
│   ├── middleware_pipeline.dart
│   ├── middleware_plugin.dart
│   └── middleware_registry.dart
└── ui_hooks/
    ├── hook_base.dart
    ├── hook_context.dart
    ├── hook_lifecycle.dart
    ├── hook_metadata.dart
    ├── hook_priority.dart
    ├── hook_registry.dart
    ├── hook_point_registry.dart
    ├── hook_api_registry.dart
    └── sidebar_tab_hook_base.dart
```

**职责**：插件生命周期管理、依赖解析、服务注册、UI钩子

**核心类**：
| 类名 | 职责 |
|------|------|
| `PluginManager` | 插件管理器核心 |
| `PluginBase` | 插件基类 |
| `PluginRegistry` | 插件注册表 |
| `DependencyResolver` | 依赖解析（拓扑排序） |
| `ServiceRegistry` | 服务注册表 |
| `HookRegistry` | UI钩子注册表 |

---

### 3.10 仓储层

```
core/repositories/
├── exceptions.dart             # 仓储异常
├── graph_repository.dart       # 图仓库
├── metadata_index.dart         # 元数据索引
├── node_repository.dart        # 节点仓库
└── repositories.dart           # 仓储导出
```

**职责**：数据持久化和检索

**核心类**：
| 类名 | 职责 |
|------|------|
| `GraphRepository` | 图数据持久化 |
| `NodeRepository` | 节点数据持久化 |
| `MetadataIndex` | 元数据索引 |
| `RepositoryException` | 仓储异常 |

---

### 3.11 服务层

```
core/services/
├── settings_service.dart       # 设置服务
├── theme_service.dart          # 主题服务
├── shortcut_manager.dart       # 快捷键管理
├── i18n.dart                   # 国际化
├── data_recovery_service.dart  # 数据恢复
├── i18n/
│   └── translations.dart       # 翻译
├── infrastructure/
│   ├── settings_registry.dart
│   ├── storage_path_service.dart
│   └── theme_registry.dart
└── theme/
    └── app_theme.dart          # 主题定义
```

**职责**：应用级服务

**核心类**：
| 类名 | 职责 |
|------|------|
| `SettingsService` | 应用设置管理 |
| `ThemeService` | 主题管理 |
| `ShortcutManager` | 快捷键管理 |
| `I18n` | 国际化服务 |
| `DataRecoveryService` | 数据恢复 |

---

### 3.12 UI布局服务 (ui_layout)

```
core/ui_layout/
├── ui_layout_service.dart      # 核心布局服务
├── coordinate_system.dart      # 坐标系统
├── layout_strategy.dart        # 布局策略
├── node_template.dart          # 节点模板
├── node_attachment.dart        # 节点附着
├── ui_hook_tree.dart           # UI Hook树
├── rendering/
│   ├── flame_renderer.dart     # Flame渲染器
│   ├── flutter_renderer.dart   # Flutter渲染器
│   └── renderer_base.dart      # 渲染器基类
└── events/
    ├── layout_events.dart      # 布局事件
    └── node_events.dart        # 节点事件
```

**职责**：UI布局管理、Hook树、节点附着、渲染

**核心类**：
| 类名 | 职责 |
|------|------|
| `UILayoutService` | 布局服务核心 |
| `CoordinateSystem` | 坐标系统 |
| `LayoutStrategy` | 布局策略 |
| `NodeTemplate` | 节点模板 |
| `FlameRenderer` | Flame渲染器 |

---

### 3.13 工具类

```
core/utils/
├── logger.dart                 # 日志工具
└── yaml_utils.dart             # YAML处理
```

---

### 3.14 并发控制

```
core/concurrency/
├── automatic_batching_middleware.dart  # 自动批处理
└── event_aggregation_middleware.dart   # 事件聚合
```

---

## 四、插件层 (plugins)

### 4.1 插件总览图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           插件生态系统                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐        │
│  │   Graph Plugin  │  │   Lua Plugin    │  │    AI Plugin    │        │
│  │   (核心插件)     │  │   (脚本扩展)     │  │   (AI功能)      │        │
│  │                 │  │                 │  │                 │        │
│  │ - 节点管理      │  │ - 脚本执行      │  │ - 函数调用      │        │
│  │ - 连接管理      │  │ - 动态钩子      │  │ - 节点分析      │        │
│  │ - Flame渲染     │  │ - 命令服务器     │  │ - AI对话        │        │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘        │
│                                                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐        │
│  │Converter Plugin │  │  Search Plugin  │  │  Editor Plugin  │        │
│  │   (导入导出)     │  │   (搜索功能)     │  │   (编辑器)      │        │
│  │                 │  │                 │  │                 │        │
│  │ - Markdown转换  │  │ - 节点搜索      │  │ - Markdown编辑  │        │
│  │ - 数据导入      │  │ - 预设管理      │  │ - 内容预览      │        │
│  │ - 数据导出      │  │ - 高级搜索      │  │                 │        │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘        │
│                                                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐        │
│  │ Folder Plugin   │  │ Layout Plugin   │  │  I18n Plugin    │        │
│  │   (文件夹)       │  │   (布局算法)     │  │   (国际化)      │        │
│  │                 │  │                 │  │                 │        │
│  │ - 文件夹管理    │  │ - 自动布局      │  │ - 多语言支持    │        │
│  │ - 节点组织      │  │ - 增量布局      │  │ - 语言切换      │        │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘        │
│                                                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐        │
│  │DataRecovery Plg │  │ Settings Plugin │  │  Market Plugin  │        │
│  │   (数据恢复)     │  │   (设置)        │  │   (插件市场)    │        │
│  │                 │  │                 │  │                 │        │
│  │ - 数据验证      │  │ - 设置入口      │  │ - 市场入口      │        │
│  │ - 数据修复      │  │                 │  │                 │        │
│  │ - 数据备份      │  │                 │  │                 │        │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘        │
│                                                                         │
│  ┌─────────────────┐  ┌─────────────────┐                             │
│  │ Delete Plugin   │  │SidebarNode Plg  │                             │
│  │   (删除)        │  │   (侧边栏节点)   │                             │
│  │                 │  │                 │                             │
│  │ - 节点删除      │  │ - 节点展示      │                             │
│  └─────────────────┘  └─────────────────┘                             │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### 4.2 AI 插件

```
plugins/ai/
├── ai_plugin.dart              # AI插件主类
├── ai_settings_hook.dart       # 设置钩子
├── ai_toolbar_hook.dart        # 工具栏钩子
├── command/
│   └── ai_commands.dart        # AI命令
├── function_calling/
│   ├── function_calling.dart
│   ├── service/
│   │   └── ai_function_calling_service.dart
│   ├── tool/
│   │   ├── ai_tool.dart
│   │   └── ai_tool_registry.dart
│   ├── tools/
│   │   ├── connect_nodes_tool.dart
│   │   ├── create_node_tool.dart
│   │   ├── delete_node_tool.dart
│   │   ├── list_nodes_tool.dart
│   │   ├── search_nodes_tool.dart
│   │   └── update_node_tool.dart
│   └── validation/
│       └── ai_tool_parameter_validator.dart
├── handler/
│   └── analyze_node_handler.dart
├── service/
│   ├── ai_service.dart
│   └── ai_service_bindings.dart
└── ui/
    ├── ai_chat_dialog.dart
    ├── ai_config_dialog.dart
    └── ai_test_dialog.dart
```

**职责**：AI对话、函数调用、节点分析

**核心类**：`AiPlugin`, `AiFunctionCallingService`, `AiToolRegistry`, `AiService`

---

### 4.3 转换器插件

```
plugins/converter/
├── converter_plugin.dart
├── converter_toolbar_hook.dart
├── export_plugin.dart
├── bloc/
│   ├── converter_bloc.dart
│   ├── converter_event.dart
│   └── converter_state.dart
├── models/
│   ├── conversion_config.dart
│   ├── conversion_result.dart
│   ├── conversion_rule.dart
│   ├── conversion_validation.dart
│   ├── converter_exception.dart
│   ├── merge_rules.dart
│   ├── models.dart
│   └── split_rules.dart
├── service/
│   ├── converter_service.dart
│   ├── converter_service_bindings.dart
│   ├── converter_service_impl.dart
│   ├── export_service.dart
│   └── import_export_service.dart
└── ui/
    ├── convert_config_panel.dart
    ├── convert_preview_panel.dart
    ├── converter_page.dart
    ├── export_dialog.dart
    ├── export_markdown_dialog.dart
    ├── import_export_page.dart
    └── import_markdown_dialog.dart
```

**职责**：数据导入导出、Markdown转换

**核心类**：`ConverterPlugin`, `ConverterBloc`, `ConverterService`, `ImportExportService`

---

### 4.4 数据恢复插件 (data_recovery)

```
plugins/data_recovery/
├── data_recovery.dart
├── data_recovery_plugin.dart
├── command/
│   ├── backup_data_command.dart
│   ├── repair_data_command.dart
│   └── validate_data_command.dart
└── handler/
    ├── backup_data_handler.dart
    ├── repair_data_handler.dart
    └── validate_data_handler.dart
```

**职责**：数据验证、修复、备份

**核心类**：`DataRecoveryPlugin`, `BackupDataCommand`, `RepairDataCommand`, `ValidateDataCommand`

---

### 4.5 删除插件

```
plugins/delete/
└── delete_plugin.dart
```

**职责**：节点删除功能（通过UI钩子集成到上下文菜单）

---

### 4.6 编辑器插件

```
plugins/editor/
├── editor_plugin.dart
└── ui/
    ├── markdown_editor_page.dart
    └── markdown_preview_widget.dart
```

**职责**：节点内容编辑、Markdown预览

**核心类**：`EditorPlugin`, `MarkdownEditorPage`, `MarkdownPreviewWidget`

---

### 4.7 文件夹插件

```
plugins/folder/
├── folder_plugin.dart
├── folder_node_template.dart
├── folder_sidebar_tab_hook.dart
└── ui/
    ├── folder_item.dart
    ├── folder_selector.dart
    └── folder_tree_view.dart
```

**职责**：文件夹管理、组织节点

**核心类**：`FolderPlugin`, `FolderNodeTemplate`, `FolderSidebarTabHook`

---

### 4.8 图插件 (graph) - **核心插件**

```
plugins/graph/
├── graph_plugin.dart
├── graph_nodes_toolbar_hook.dart
├── refresh_graph_toolbar_hook.dart
├── toggle_connections_toolbar_hook.dart
├── bloc/
│   ├── graph_bloc.dart
│   ├── graph_event.dart
│   ├── graph_state.dart
│   ├── node_bloc.dart
│   ├── node_event.dart
│   └── node_state.dart
├── command/
│   ├── graph_commands.dart
│   └── node_commands.dart
├── flame/
│   ├── flame.dart
│   ├── graph_widget.dart
│   ├── graph_world.dart
│   ├── spatial_index_manager.dart
│   ├── view_frustum_culler.dart
│   ├── components/
│   │   ├── connection_renderer.dart
│   │   └── node_component.dart
│   ├── lod/
│   │   └── lod_manager.dart
│   └── mixins/
│       └── bloc_consumer.dart
├── handler/
│   ├── add_node_to_graph_handler.dart
│   ├── connect_nodes_handler.dart
│   ├── create_graph_handler.dart
│   ├── create_node_handler.dart
│   ├── delete_node_handler.dart
│   ├── disconnect_nodes_handler.dart
│   ├── load_graph_handler.dart
│   ├── move_node_handler.dart
│   ├── remove_node_from_graph_handler.dart
│   ├── rename_graph_handler.dart
│   ├── resize_node_handler.dart
│   ├── update_graph_handler.dart
│   ├── update_node_handler.dart
│   └── update_node_position_handler.dart
├── service/
│   ├── graph_service.dart
│   ├── graph_service_bindings.dart
│   ├── node_context_menu.dart
│   ├── node_service.dart
│   └── toolbar_settings_service.dart
├── tasks/
│   ├── connection_path_task.dart
│   ├── node_sizing_task.dart
│   └── text_layout_task.dart
└── ui/
    ├── batch_operation_dialog.dart
    ├── create_node_dialog.dart
    ├── delete_node_dialog.dart
    ├── draggable_toolbar.dart
    ├── graph_nodes_dialog.dart
    ├── graph_preview_widget.dart
    ├── graph_view.dart
    ├── node_icon_dialog.dart
    ├── node_menu.dart
    ├── node_metadata_dialog.dart
    └── node_selector_widget.dart
```

**职责**：图形编辑、节点管理、连接管理、Flame渲染

**核心类**：`GraphPlugin`, `GraphBloc`, `NodeBloc`, `GraphService`, `NodeService`, `GraphWorld`

---

### 4.9 国际化插件 (i18n)

```
plugins/i18n/
├── i18n_plugin.dart
├── hooks/
│   └── language_toggle_hook.dart
└── service/
    └── i18n_service_binding.dart
```

**职责**：多语言支持、界面汉化

**核心类**：`I18nPlugin`, `LanguageToggleHook`

---

### 4.10 布局插件

```
plugins/layout/
├── layout_plugin.dart
├── layout_toolbar_hook.dart
├── command/
│   └── layout_commands.dart
├── event/
│   └── layout_events.dart
├── handler/
│   └── apply_layout_handler.dart
├── service/
│   ├── incremental_layout_engine.dart
│   ├── layout_service.dart
│   └── layout_service_bindings.dart
└── ui/
    └── layout_menu.dart
```

**职责**：图形布局算法、自动排列

**核心类**：`LayoutPlugin`, `IncrementalLayoutEngine`, `LayoutService`

---

### 4.11 Lua 脚本插件 (lua) - **重要插件**

```
plugins/lua/
├── lua_plugin.dart
├── bloc/
│   ├── lua_script_bloc.dart
│   ├── lua_script_event.dart
│   └── lua_script_state.dart
├── command/
│   ├── create_lua_script_command.dart
│   ├── delete_lua_script_command.dart
│   ├── execute_lua_script_command.dart
│   ├── lua_commands.dart
│   ├── toggle_lua_script_command.dart
│   └── update_lua_script_command.dart
├── handler/
│   ├── create_lua_script_handler.dart
│   ├── delete_lua_script_handler.dart
│   ├── execute_lua_script_handler.dart
│   ├── toggle_lua_script_handler.dart
│   └── update_lua_script_handler.dart
├── models/
│   ├── lua_execution_result.dart
│   └── lua_script.dart
└── service/
    ├── global_message_service.dart
    ├── lua_api_implementation.dart
    ├── lua_command_server.dart
    ├── lua_dynamic_hook_manager.dart
    ├── lua_engine.dart
    ├── lua_engine_service.dart
    ├── lua_error_handler.dart
    ├── lua_function_registry.dart
    ├── lua_function_schema.dart
    ├── lua_script_service.dart
    ├── lua_security_manager.dart
    └── lua_service_bindings.dart
```

**职责**：Lua脚本执行、动态钩子、命令服务器

**核心类**：`LuaPlugin`, `LuaEngine`, `LuaScriptService`, `LuaSecurityManager`, `LuaCommandServer`

---

### 4.12 市场插件

```
plugins/market/
├── market_plugin.dart
└── market_toolbar_hook.dart
```

**职责**：插件市场入口

---

### 4.13 搜索插件

```
plugins/search/
├── search_plugin.dart
├── search_sidebar_hook.dart
├── bloc/
│   ├── search_bloc.dart
│   ├── search_event.dart
│   └── search_state.dart
├── command/
│   └── search_commands.dart
├── handler/
│   ├── delete_search_preset_handler.dart
│   └── save_search_preset_handler.dart
├── model/
│   ├── search_preset_model.dart
│   └── search_query.dart
├── service/
│   ├── search_preset_service.dart
│   └── search_service_bindings.dart
└── ui/
    ├── search_sidebar_panel.dart
    └── searched_node_item.dart
```

**职责**：节点搜索、搜索预设管理

**核心类**：`SearchPlugin`, `SearchBloc`, `SearchPresetService`

---

### 4.14 设置插件

```
plugins/settings/
├── settings_plugin.dart
└── settings_toolbar_hook.dart
```

**职责**：应用设置入口

---

### 4.15 侧边栏节点插件

```
plugins/sidebarNode/
├── sidebar_node_plugin.dart
├── sidebar_plugin.dart
└── ui/
    └── node_item.dart
```

**职责**：侧边栏节点展示

---

## 五、UI层

### 5.1 目录结构

```
ui/
├── bars/
│   ├── core_toolbar.dart        # 核心工具栏
│   ├── note_app_bar.dart        # 应用栏
│   └── sidebar.dart             # 侧边栏
├── bloc/
│   ├── ui_bloc.dart             # UI BLoC
│   ├── ui_event.dart            # UI事件
│   └── ui_state.dart            # UI状态
├── dialogs/
│   ├── settings_dialog.dart     # 设置对话框
│   └── shortcut_help_dialog.dart
├── pages/
│   ├── home_page.dart           # 主页
│   └── plugin_market_page.dart  # 插件市场
├── utilwidgets/
│   └── highlight_text.dart      # 高亮文本
└── widgets/
    └── plugin_item.dart         # 插件项
```

### 5.2 模块职责

| 模块 | 文件 | 职责 |
|------|------|------|
| 核心工具栏 | `core_toolbar.dart` | 主要操作按钮（新建、保存、撤销等） |
| 应用栏 | `note_app_bar.dart` | 应用标题和基本导航 |
| 侧边栏 | `sidebar.dart` | 左侧导航和功能面板 |
| UI状态管理 | `ui_bloc.dart` | UI状态BLoC管理 |
| 设置对话框 | `settings_dialog.dart` | 应用配置选项 |
| 主页 | `home_page.dart` | 应用主要展示页面 |
| 插件市场 | `plugin_market_page.dart` | 插件市场页面 |

---

## 六、测试覆盖

### 6.1 测试目录结构

```
test/
├── core/                        # 核心模块测试
│   ├── commands/                # 命令系统测试
│   ├── cqrs/                    # CQRS测试
│   ├── events/                  # 事件系统测试
│   ├── execution/               # 执行引擎测试
│   ├── graph/                   # 图结构测试
│   ├── middleware/              # 中间件测试
│   ├── plugin/                  # 插件系统测试
│   ├── repositories/            # 仓储层测试
│   ├── services/                # 服务层测试
│   └── ui_layout/               # UI布局测试
├── integration/                 # 集成测试
│   ├── graph_integration_test.dart
│   └── graph_workflow_integration_test.dart
├── performance/                 # 性能测试
│   ├── cqrs_performance_test.dart
│   └── graph_performance_test.dart
└── plugins/                     # 插件测试
    ├── ai/                      # AI测试
    ├── converter/               # 转换器测试
    ├── data_recovery/           # 数据恢复测试
    ├── editor/                  # 编辑器测试
    ├── folder/                  # 文件夹测试
    ├── graph/                   # 图测试
    ├── i18n/                    # 国际化测试
    ├── lua/                     # Lua测试
    └── search/                  # 搜索测试
```

### 6.2 测试覆盖统计

| 测试类型 | 目录 | 覆盖模块 |
|----------|------|----------|
| 单元测试 | test/core/ | 命令、CQRS、事件、执行引擎、中间件、插件、仓储、服务 |
| 插件测试 | test/plugins/ | AI、转换器、数据恢复、编辑器、文件夹、图、国际化、Lua、搜索 |
| 集成测试 | test/integration/ | 图工作流集成 |
| 性能测试 | test/performance/ | CQRS性能、图性能 |

---

## 七、模块依赖关系

### 7.1 依赖层次图

```
                    ┌─────────────┐
                    │   main.dart │
                    │   app.dart  │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
    ┌─────────┐      ┌─────────┐      ┌─────────┐
    │   UI    │      │ Plugins │      │ Services│
    │  Layer  │      │  Layer  │      │  Layer  │
    └────┬────┘      └────┬────┘      └────┬────┘
         │                │                 │
         │                │                 │
         └────────────────┼─────────────────┘
                          │
                          ▼
                    ┌─────────────┐
                    │    Core     │
                    │   Layer     │
                    ├─────────────┤
                    │ - Commands  │
                    │ - CQRS      │
                    │ - Events    │
                    │ - Models    │
                    │ - Plugin    │
                    │ - Middleware│
                    │ - Repos     │
                    └─────────────┘
```

### 7.2 核心模块依赖

```
┌───────────────────────────────────────────────────────────┐
│                      PluginManager                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │PluginRegistry│  │ServiceRegistry│ │ ApiRegistry │      │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘      │
│         │                │                │              │
│         └────────────────┼────────────────┘              │
│                          ▼                               │
│                ┌─────────────────┐                       │
│                │DependencyResolver│                      │
│                │  (拓扑排序)      │                      │
│                └─────────────────┘                       │
└───────────────────────────────────────────────────────────┘
```

### 7.3 数据流依赖

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│   User   │───▶│ Command  │───▶│ Handler  │───▶│Repository│
│  Action  │    │   Bus    │    │          │    │          │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
                     │
                     │ Events
                     ▼
               ┌──────────┐
               │  Event   │
               │   Bus    │
               └──────────┘
                     │
                     ▼
               ┌──────────┐
               │    UI    │
               │  Update  │
               └──────────┘
```

---

## 八、团队分工建议

### 8.1 角色分工

| 团队角色 | 负责模块 | 主要职责 | 关键文件 |
|----------|----------|----------|----------|
| **架构师** | core/commands, core/cqrs, core/events, core/plugin | 命令系统、CQRS架构、事件系统、插件框架 | command_bus.dart, query_bus.dart, plugin_manager.dart |
| **核心开发** | core/models, core/repositories, core/graph | 数据模型、仓储层、图数据结构 | graph.dart, node.dart, graph_repository.dart |
| **服务开发** | core/services, core/middleware | 服务层、中间件系统 | settings_service.dart, theme_service.dart, cache_middleware.dart |
| **插件开发** | plugins/* | 各业务插件开发 | graph_plugin.dart, lua_plugin.dart, ai_plugin.dart |
| **UI开发** | ui/*, core/ui_layout | 用户界面、布局服务 | home_page.dart, ui_layout_service.dart |
| **测试工程师** | test/* | 测试用例编写、性能测试 | *_test.dart |

### 8.2 模块负责人建议

```
┌─────────────────────────────────────────────────────────────┐
│                      项目经理 / Tech Lead                   │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│   架构师      │     │  插件负责人   │     │   UI负责人    │
│               │     │               │     │               │
│ - commands    │     │ - graph       │     │ - ui/*        │
│ - cqrs        │     │ - lua         │     │ - ui_layout   │
│ - events      │     │ - ai          │     │               │
│ - plugin core │     │ - converter   │     │               │
└───────────────┘     │ - others...   │     └───────────────┘
                      └───────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
       ┌───────────┐   ┌───────────┐   ┌───────────┐
       │ 核心开发  │   │ 服务开发  │   │ 测试工程师│
       │           │   │           │   │           │
       │ - models  │   │ - services│   │ - unit    │
       │ - repos   │   │ - middleware│  │ - integ.  │
       │ - graph   │   │           │   │ - perf.   │
       └───────────┘   └───────────┘   └───────────┘
```

---

## 九、附录

### 9.1 文件统计

| 层级 | 目录 | 文件数量 | 主要职责 |
|------|------|----------|----------|
| 核心层 | lib/core/ | ~90 | 基础设施、插件框架、数据层 |
| 插件层 | lib/plugins/ | ~80 | 业务功能插件 |
| UI层 | lib/ui/ | ~15 | 用户界面 |
| 工具层 | lib/utils/ | ~2 | 工具类 |
| 入口 | lib/ | 2 | 应用入口 |
| 测试 | test/ | ~60 | 测试代码 |

### 9.2 关键技术点

1. **CQRS架构**：命令查询职责分离，通过CommandBus和QueryBus实现
2. **插件系统**：支持动态加载、依赖解析、生命周期管理
3. **UI Hook机制**：允许插件扩展界面
4. **中间件链**：缓存、日志、事务、撤销等功能横切
5. **Flame渲染**：高性能图形渲染引擎

### 9.3 插件依赖关系

```
                    ┌─────────────┐
                    │   Graph     │ (核心)
                    │  Plugin     │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
    ┌─────────┐      ┌─────────┐      ┌─────────┐
    │  Lua    │      │   AI    │      │ Layout  │
    │ Plugin  │      │ Plugin  │      │ Plugin  │
    └────┬────┘      └────┬────┘      └─────────┘
         │                │
         │                │
    ┌────┴────┐     ┌────┴────┐
    │ Search  │     │Converter│
    │ Plugin  │     │ Plugin  │
    └─────────┘     └─────────┘
         │
         ▼
    ┌─────────┐
    │ Folder  │
    │ Plugin  │
    └─────────┘
```

---

*报告生成完毕*
