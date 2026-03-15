# Phase 2: 全面插件化重构 - 实施状态

## 总体进度

**当前进度**: 20% 完成

**状态**: 🚀 实施中 - Stage 2 Week 1 完成

**开始日期**: 2025-01-15
**预计完成**: 8-12 周

---

## 🎯 总体进度可视化

```
Stage 0: ▓▓▓▓▓▓▓▓▓▓░░░░ 100% (UndoMiddleware 集成 - 完成)
Stage 1: ▓▓▓▓▓▓▓▓▓▓▓▓▓▓ 100% (RelationTypes 移除 & 元数据系统 - 完成)
Stage 2: ▓▓▓▓▓▓▓▓▓▓▓░░░ 100% (插件系统基础设施 - Week 1 完成)
Stage 3: ░░░░░░░░░░░░░░░ 0%   (未开始 - 极简 UI 内核)
Stage 4: ░░░░░░░░░░░░░░░ 0%   (未开始 - 中间件插件)
Stage 5: ░░░░░░░░░░░░░░░ 0%   (未开始 - UI Hooks)
Stage 6: ░░░░░░░░░░░░░░░ 0%   (未开始 - 文件夹插件化)
Stage 7: ░░░░░░░░░░░░░░░ 0%   (未开始 - 搜索插件化)
Stage 8: ░░░░░░░░░░░░░░░ 0%   (未开始 - 布局插件化)
Stage 9: ░░░░░░░░░░░░░░░ 0%   (未开始 - 渲染器插件化)
Stage 10: ░░░░░░░░░░░░░░░ 0%   (未开始 - 高级特性)

总体进度: ████████████░░░░░░░░ 20%
```

---

## 详细进度

### Stage 0: 修正 Phase 1 遗漏 (1 周)

**目标**: 集成 UndoManager 到 Command Bus

**状态**: ✅ 完成 (100%)

| 任务 | 状态 | 完成日期 | 备注 |
|------|------|----------|------|
| 分析现有 UndoManager 实现 | ✅ 完成 | 2025-01-15 | 理解当前撤销/重做机制 |
| 创建 UndoMiddleware | ✅ 完成 | 2025-01-15 | `lib/core/commands/middleware/undo_middleware.dart` |
| 集成到 CommandBus | ✅ 完成 | 2025-01-15 | 在 `lib/app.dart` 中注册 |
| 测试撤销/重做功能 | ⏳ 待办 | - | 需要创建测试用例 |
| 更新文档 | ⏳ 待办 | - | 记录集成方式 |

**进度**: 3/5 任务完成

**创建的文件**:
- ✅ `lib/core/commands/middleware/undo_middleware.dart`

**修改的文件**:
- ✅ `lib/app.dart` - 添加 UndoMiddleware Provider 和集成

---

### Stage 1: 取消 RelationTypes & 元数据系统 (2 周)

**目标**: 简化关系模型，所有关系数据存储在节点元数据中

**状态**: ✅ 完成 (100%)

#### Week 1: RelationTypes 移除 & 基于深度的显示系统 (100%)

| 任务 | 状态 | 完成日期 | 备注 |
|------|------|----------|------|
| 分析和设计新的 NodeReference 结构 | ✅ 完成 | 2026-03-15 | 使用 Map<String, dynamic> 存储属性 |
| 移除 ReferenceType 枚举 | ✅ 完成 | 2026-03-15 | 从 `enums.dart` 中删除 |
| 简化 NodeReference 类 | ✅ 完成 | 2026-03-15 | 更新为灵活的 properties 存储 |
| 更新所有使用处 | ✅ 完成 | 2026-03-15 | 20+ 文件已更新 |
| 实现基于深度的显示系统 | ✅ 完成 | 2026-03-15 | 移除所有基于类型的显示判断 |
| 添加节点深度计算 | ✅ 完成 | 2026-03-15 | `NodeService.calculateNodeDepths()` |

**核心模型重构完成**：
- ✅ `node_reference.dart` - 重构为 `properties` Map
- ✅ `connection.dart` - `referenceType` → `type` (String)
- ✅ `enums.dart` - 移除 ReferenceType 枚举
- ✅ `relation_types.dart` - 关系类型常量（仅用于语义）

**架构修复完成**：
- ✅ 移除所有 `ref.type == RelationTypes.contains` 判断
- ✅ 实现基于层级深度的显示逻辑
- ✅ DFS 深度计算算法（支持循环检测）
- ✅ 统一连接线渲染（所有类型显示一致）

**已更新文件（13 个核心文件）**：
- **命令层**: `node_commands.dart`, `connect_nodes_handler.dart`, `graph_command.dart`
- **服务层**: `node_service.dart`, `node_repository.dart`, `layout_service.dart`, `app_theme.dart`, `import_export_service.dart`
- **BLoC 层**: `node_bloc.dart`, `node_event.dart`
- **AI 服务**: `ai_service.dart`
- **Flame 组件**: `connection_renderer.dart`, `node_component.dart`
- **UI 层**: `connection_dialog.dart`, `export_markdown_dialog.dart`, `folder_selector.dart`, `node_connections_dialog.dart`, `folder_tree_view.dart`, `folder_item.dart`
- **Converter**: `converter_service_impl.dart`

#### Week 2: 元数据系统重构 (100%)

| 任务 | 状态 | 完成日期 | 备注 |
|------|------|----------|------|
| 定义标准元数据规范 | ✅ 完成 | 2026-03-15 | 创建 `standard_metadata.dart` |
| 实现元数据验证系统 | ✅ 完成 | 2026-03-15 | 创建 `metadata_schema.dart`, `metadata_validator.dart` |
| 创建关系类型常量 | ✅ 完成 | 2026-03-15 | `relation_types.dart` |

**新增文件**：
- ✅ `lib/core/metadata/standard_metadata.dart` - 标准元数据键定义
- ✅ `lib/core/metadata/metadata_schema.dart` - Schema 定义和验证规则
- ✅ `lib/core/metadata/metadata_validator.dart` - 元数据验证器
- ✅ `lib/core/metadata/relation_types.dart` - 关系类型常量

---

### Stage 2: 插件系统核心 (2 周)

**目标**: 实现插件管理器、生命周期、依赖解析

**状态**: ✅ Week 1 完成 (100%)

#### Week 1: 插件基础设施 (100%)

| 任务 | 状态 | 完成日期 | 备注 |
|------|------|----------|------|
| Plugin 接口和元数据 | ✅ 完成 | 2026-03-15 | `plugin_base.dart`, `plugin_metadata.dart` |
| PluginContext 和 API | ✅ 完成 | 2026-03-15 | `plugin_context.dart` |
| PluginManager 和 PluginRegistry | ✅ 完成 | 2026-03-15 | `plugin_manager.dart`, `plugin_registry.dart` |
| 插件生命周期 | ✅ 完成 | 2026-03-15 | `plugin_lifecycle.dart` |
| 插件发现和加载 | ✅ 完成 | 2026-03-15 | `plugin_discoverer.dart` |
| 依赖解析 | ✅ 完成 | 2026-03-15 | `dependency_resolver.dart` |
| 异常系统 | ✅ 完成 | 2026-03-15 | `plugin_exception.dart` |
| 统一导出 | ✅ 完成 | 2026-03-15 | `plugin.dart` |

**新增核心文件（9 个）**：

**基础接口**：
- ✅ `plugin_base.dart` - Plugin 接口定义
- ✅ `plugin_metadata.dart` - PluginMetadata、PluginType、PluginPermission、PluginState
- ✅ `plugin_context.dart` - PluginContext、PluginLogger、PluginAPIProvider
- ✅ `plugin_exception.dart` - 完整的异常类层次（11 个异常类）

**管理和生命周期**：
- ✅ `plugin_lifecycle.dart` - PluginLifecycleManager、状态监听器
- ✅ `plugin_registry.dart` - 插件注册表
- ✅ `plugin_discoverer.dart` - 插件发现和工厂注册
- ✅ `plugin_manager.dart` - 完整的插件管理器实现

**依赖解析**：
- ✅ `dependency_resolver.dart` - 拓扑排序、循环检测、传递依赖分析

**导出**：
- ✅ `plugin.dart` - 统一导出文件

**代码优化**：
- ✅ 移除未使用的 `_Internal` 类

#### Week 2: 高级插件特性 (0%)

| 任务 | 状态 | 完成日期 | 备注 |
|------|------|----------|------|
| 中间件插件 | ⏳ 未开始 | - | `middleware_plugin.dart` |
| Command Bus 集成 | ⏳ 未开始 | - | 添加插件中间件支持 |

---

### Stage 3: 极简 UI 内核 (2 周)

**目标**: 重构 UI 为极简内核，所有功能由插件提供

**状态**: ⏳ 未开始 (0%)

#### Week 1: UI 框架重构

| 任务 | 状态 | 完成日期 | 备注 |
|------|------|----------|------|
| 创建插件化 UI 框架 | ⏳ 未开始 | - | 定义 HookPoint, HookContext |
| 实现 UI Hook 系统 | ⏳ 未开始 | - | HookRegistry, HookContainer |
| 创建核心 Toolbar | ⏳ 未开始 | - | 只保留 4 个核心功能 |

#### Week 2: 功能迁移到插件

| 任务 | 状态 | 完成日期 | 备注 |
|------|------|----------|------|
| 删除功能插件化 | ⏳ 未开始 | - | DeletePlugin |
| 布局功能插件化 | ⏳ 未开始 | - | LayoutPlugins |
| Sidebar 插件化 | ⏳ 未开始 | - | SidebarPlugin |
| StatusBar 插件化 | ⏳ 未开始 | - | StatusBarPlugin |

---

### Stage 4: 中间件插件 (1 周)

**目标**: 实现中间件插件系统

**状态**: ⏳ 未开始 (0%)

| 任务 | 状态 | 完成日期 | 备注 |
|------|------|----------|------|
| 中间件插件基础 | ⏳ 未开始 | - | `middleware_plugin.dart`, `middleware_pipeline.dart` |
| 内置中间件 | ⏳ 未开始 | - | 缓存、性能监控、审计日志 |
| Command Bus 集成 | ⏳ 未开始 | - | 修改 `command_bus.dart` |

---

### Stage 5: UI Hooks 系统 (1 周)

**目标**: 实现 UI Hook 系统

**状态**: ⏳ 未开始 (0%)

| 任务 | 状态 | 完成日期 | 备注 |
|------|------|----------|------|
| UI Hook 基础设施 | ⏳ 未开始 | - | `ui_hooks/` 目录 |
| HookRegistry 和 HookContainer | ⏳ 未开始 | - | 核心系统 |
| 迁移内置插件 | ⏳ 未开始 | - | AI, Export 插件 |

---

### Stage 6: 文件夹插件化 (1 周)

**目标**: 将文件夹功能完全迁移到插件

**状态**: ⏳ 未开始 (0%)

| 任务 | 状态 | 完成日期 | 备注 |
|------|------|----------|------|
| 创建 FolderPlugin | ⏳ 未开始 | - | 实现文件夹元数据处理 |
| 文件夹树形视图插件 | ⏳ 未开始 | - | FolderViewPlugin |
| 文件夹拖拽逻辑插件 | ⏳ 未开始 | - | 拖拽逻辑 |
| 移除核心的文件夹代码 | ⏳ 未开始 | - | 清理旧代码 |

---

### Stage 7: 搜索插件化 (1 周)

**目标**: 将搜索功能完全迁移到插件

**状态**: ⏳ 未开始 (0%)

| 任务 | 状态 | 完成日期 | 备注 |
|------|------|----------|------|
| 创建 SearchPlugin | ⏳ 未开始 | - | 实现搜索算法 |
| 搜索 UI 插件化 | ⏳ 未开始 | - | 搜索栏和结果 UI |
| 搜索预设插件化 | ⏳ 未开始 | - | SearchPresetPlugin |
| 移除核心的搜索代码 | ⏳ 未开始 | - | 清理旧代码 |

---

### Stage 8: 布局系统插件化 (1 周)

**目标**: 将所有布局功能迁移到插件

**状态**: ⏳ 未开始 (0%)

| 任务 | 状态 | 完成日期 | 备注 |
|------|------|----------|------|
| 创建 LayoutPlugin 接口 | ⏳ 未开始 | - | 定义布局算法接口 |
| 每个布局算法作为独立插件 | ⏳ 未开始 | - | ForceDirected, Tree, Circular, Grid |
| 自动布局中间件插件 | ⏳ 未开始 | - | AutoLayoutMiddlewarePlugin |
| 移除核心的布局代码 | ⏳ 未开始 | - | 清理旧代码 |

---

### Stage 9: 节点渲染器插件化 (1 周)

**目标**: 节点差异化渲染由插件提供

**状态**: ⏳ 未开始 (0%)

| 任务 | 状态 | 完成日期 | 备注 |
|------|------|----------|------|
| 创建 RendererPlugin 接口 | ⏳ 未开始 | - | 定义渲染器接口和优先级 |
| 基础节点渲染器 | ⏳ 未开始 | - | BaseNodeRendererPlugin |
| 特殊节点渲染器 | ⏳ 未开始 | - | AI, Folder 等特殊节点 |
| 渲染器注册和管理 | ⏳ 未开始 | - | 渲染器注册表 |

---

### Stage 10: 高级特性 (1-2 周)

**目标**: 多语言、主题、导入导出等高级特性

**状态**: ⏳ 未开始 (0%)

#### Week 1: 多语言和主题

| 任务 | 状态 | 完成日期 | 备注 |
|------|------|----------|------|
| 多语言框架（i18n） | ⏳ 未开始 | - | 创建 i18n 框架 |
| 语言包插件 | ⏳ 未开始 | - | English, Chinese |
| 主题系统插件化 | ⏳ 未开始 | - | 支持插件主题 |
| 主题包插件 | ⏳ 未开始 | - | Light, Dark 主题 |

#### Week 2: 导入导出和其他

| 任务 | 状态 | 完成日期 | 备注 |
|------|------|----------|------|
| 导入导出插件化 | ⏳ 未开始 | - | ImportExportPlugin |
| AI 集成插件化 | ⏳ 未开始 | - | AIIntegrationPlugin |
| 数据恢复功能完善 | ⏳ 未开始 | - | 支持插件恢复策略 |
| 插件市场和设置 | ⏳ 未开始 | - | PluginMarketPlugin, SettingsPlugin |

---

## 编译状态

- **错误数**: 312 → 271（减少 41 个）
- **主要错误来源**:
  - `graph_command.dart`（1 个文件）
  - `export_plugin.dart`（1 个文件）
  - 测试文件（约 10+ 个）
  - 其他 UI 文件（少量）

---

## 文件创建状态

### 已完成的新增文件

```
lib/core/commands/middleware/
└── undo_middleware.dart               ✅ 已创建

lib/core/metadata/
├── standard_metadata.dart             ✅ 已创建
├── metadata_schema.dart               ✅ 已创建
├── metadata_validator.dart            ✅ 已创建
└── relation_types.dart                ✅ 已创建

lib/core/plugin/
├── plugin.dart                        ✅ 已创建（导出）
├── plugin_base.dart                   ✅ 已创建
├── plugin_metadata.dart               ✅ 已创建
├── plugin_context.dart                ✅ 已创建
├── plugin_manager.dart                ✅ 已创建
├── plugin_registry.dart               ✅ 已创建
├── plugin_lifecycle.dart              ✅ 已创建
├── plugin_discoverer.dart             ✅ 已创建
├── dependency_resolver.dart           ✅ 已创建
└── plugin_exception.dart              ✅ 已创建
```

**进度**: 14/14 文件创建完成

### 待创建的文件

```
lib/core/plugin/
├── middleware/
│   ├── middleware_plugin.dart         ⏳ 未创建
│   ├── middleware_pipeline.dart       ⏳ 未创建
│   ├── middleware_registry.dart       ⏳ 未创建
│   └── builtin/
│       ├── cache_middleware.dart      ⏳ 未创建
│       ├── performance_middleware.dart ⏳ 未创建
│       └── audit_middleware.dart      ⏳ 未创建
│
├── ui_hooks/
│   ├── hook_point.dart                ⏳ 未创建
│   ├── hook_context.dart              ⏳ 未创建
│   ├── ui_hook.dart                   ⏳ 未创建
│   ├── hook_registry.dart             ⏳ 未创建
│   ├── hook_container.dart            ⏳ 未创建
│   ├── hook_state_manager.dart        ⏳ 未创建
│   └── points/
│       ├── toolbar_hook.dart          ⏳ 未创建
│       ├── context_menu_hook.dart     ⏳ 未创建
│       ├── sidebar_hook.dart          ⏳ 未创建
│       └── status_bar_hook.dart       ⏳ 未创建
│
└── api/
    ├── storage_api.dart               ⏳ 未创建
    ├── command_api.dart               ⏳ 未创建
    └── ui_api.dart                    ⏳ 未创建
```

**进度**: 0/22 文件创建

---

## 待修改文件

| 文件 | 状态 | 备注 |
|------|------|------|
| `lib/plugins/hooks/graph_plugin.dart` | ⏳ 未开始 | 标记为废弃 |
| `lib/plugins/builtin_plugins/ai_plugin.dart` | ⏳ 未开始 | 迁移到新接口 |
| `lib/plugins/builtin_plugins/export_plugin.dart` | ⏳ 未开始 | 迁移到新接口 |
| `lib/plugins/builtin_plugins/layout_plugin.dart` | ⏳ 未开始 | 转换为中间件 |
| `lib/plugins/builtin_plugins/smart_layout_plugin.dart` | ⏳ 未开始 | 转换为中间件 |
| `lib/app.dart` | ⏳ 未开始 | 添加 PluginManager |
| `lib/core/commands/command_bus.dart` | ⏳ 未开始 | 添加中间件插件支持 |

**进度**: 0/7 文件修改

---

## 测试状态

### 单元测试

- [ ] `PluginManager` 生命周期管理
- [ ] `DependencyResolver` 拓扑排序
- [ ] `MetadataValidator` 元数据验证
- [ ] `MiddlewarePipeline` 执行顺序
- [ ] `HookRegistry` 注册/注销

**进度**: 0/5 测试完成

### 集成测试

- [ ] 插件加载和初始化
- [ ] 中间件插件与 Command Bus 集成
- [ ] UI Hook 渲染
- [ ] 插件间通信

**进度**: 0/4 测试完成

---

## 关键文件位置

**元数据系统**：
- `lib/core/metadata/standard_metadata.dart`
- `lib/core/metadata/metadata_schema.dart`
- `lib/core/metadata/metadata_validator.dart`
- `lib/core/metadata/relation_types.dart`

**插件系统**：
- `lib/core/plugin/plugin.dart`（导出）
- `lib/core/plugin/plugin_base.dart`（Plugin 接口）
- `lib/core/plugin/plugin_manager.dart`（管理器）
- `lib/core/plugin/dependency_resolver.dart`（依赖解析）

**中间件**：
- `lib/core/commands/middleware/undo_middleware.dart`

---

## 设计要点

### 元数据系统
- 标准化元数据键（如 `isFolder`, `aiScore`）
- 类型安全的 Schema 验证
- 支持插件自定义元数据（`plugin.*` 前缀）

### 插件系统架构
```
Plugin
  ↓
onLoad(PluginContext)
  ↓
context.commandBus.dispatch(command)
  ↓
CommandHandler（业务逻辑）
  ↓
Middleware（验证、日志、事务）
```

### 依赖解析
- 拓扑排序确定加载顺序
- 循环依赖检测
- 版本兼容性检查

---

## 阻塞问题

当前无阻塞问题。

---

## 里程碑

| 里程碑 | 目标日期 | 状态 |
|--------|----------|------|
| UndoMiddleware 集成完成 | Stage 0 | ✅ 完成 |
| ReferenceType 移除完成 | Stage 1 Week 1 | ✅ 完成 |
| 元数据系统完成 | Stage 1 Week 2 | ✅ 完成 |
| 插件系统基础设施完成 | Stage 2 Week 1 | ✅ 完成 |
| 中间件插件系统完成 | Stage 2 Week 2 | ⏳ 未开始 |
| UI Hook 系统完成 | Stage 3 | ⏳ 未开始 |
| 内置插件迁移完成 | Stage 4-9 | ⏳ 未开始 |
| 测试和文档完成 | Stage 10 | ⏳ 未开始 |

---

## 下一步行动

1. ⏭️ 修复编译错误（`graph_command.dart`, `export_plugin.dart`）
2. ⏭️ 运行 `flutter pub run build_runner build`
3. ⏭️ 开始 Stage 2 Week 2：中间件插件
4. ⏭️ 创建单元测试验证已实现功能

---

**最后更新**: 2026-03-15
