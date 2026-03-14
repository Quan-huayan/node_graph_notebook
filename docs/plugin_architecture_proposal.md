# Node Graph Notebook - 充分插件化架构重构建议

## 文档版本

- **版本**: 1.0.0
- **日期**: 2025-01-14
- **作者**: Claude Code
- **状态**: 提议中

---

## 1. 当前架构分析

### 1.1 现有架构优势

当前应用已经建立了良好的基础架构：

- ✅ **Clean Architecture 分层**: Repository → Service → BLoC → UI
- ✅ **抽象接口**: 所有关键服务都有接口定义
- ✅ **事件总线系统**: `AppEventBus` 实现 BLoC 间解耦通信
- ✅ **Provider 依赖注入**: 使用 `MultiProvider` 管理依赖
- ✅ **基础插件系统**: `GraphPlugin` 接口和 `PluginRegistry`
- ✅ **命令模式**: `UndoManager` 实现撤销/重做功能

### 1.2 当前架构限制

#### 1.2.1 插件系统限制

**问题**: 当前插件系统 (`lib/plugins/hooks/graph_plugin.dart`) 仅针对 `GraphBloc`，缺乏通用性。

```dart
// 当前设计：插件只能访问 GraphBloc
abstract class GraphPlugin {
  Future<void> initialize(GraphBloc bloc);
  Future<void> execute(Map<String, dynamic> data, GraphBloc bloc, Emitter<GraphState> emit);
}
```

**限制**:
- ❌ 无法扩展到其他 BLoC（NodeBloc, UIBloc, SearchBloc）
- ❌ 无法访问 Service 层
- ❌ 没有 UI 扩展能力
- ❌ 插件间通信机制缺失
- ❌ 无依赖管理
- ❌ 无版本控制

#### 1.2.2 服务耦合问题

**问题**: 服务通过构造函数硬依赖，形成紧密耦合。

```dart
// app.dart 中的服务注册
Provider<ImportExportService>(
  create: (ctx) => ImportExportServiceImpl(
    ctx.read<ConverterService>(),
    ctx.read<NodeService>(),
    ctx.read<GraphService>(),
  ),
),
```

**限制**:
- ❌ 添加新服务需要修改 `app.dart`
- ❌ 服务无法按需加载
- ❌ 无法替换服务实现（如云存储替代文件系统）
- ❌ 缺少生命周期管理
- ❌ 潜在的循环依赖风险

#### 1.2.3 AI 提供商集成限制

**问题**: AI 提供商切换需要修改服务代码。

```dart
// app.dart:152-165 - 硬编码的提供商选择
void update() {
  if (settings.isAIConfigured) {
    final provider = settings.aiProvider == 'anthropic'
        ? AnthropicProvider(...)
        : OpenAIProvider(...);
    ai.setProvider(provider);
  }
}
```

**限制**:
- ❌ 添加新 AI 提供商需要修改核心代码
- ❌ 无法动态发现和加载提供商
- ❌ 缺少提供商能力声明
- ❌ 无提供商版本管理

#### 1.2.4 Repository 层限制

**问题**: 当前只有文件系统实现。

```dart
// app.dart 中硬编码的 Repository
Provider<NodeRepository>.value(value: FileSystemNodeRepository()),
Provider<GraphRepository>.value(value: FileSystemGraphRepository()),
```

**限制**:
- ❌ 无法同时支持多种存储后端
- ❌ 无法动态切换存储方式
- ❌ 缺少远程存储支持（云同步）
- ❌ 缺少缓存层抽象

---

## 2. 插件化重构目标

### 2.1 核心目标

1. **全功能插件系统**: 支持功能、数据、UI、服务等多类型插件
2. **热插拔支持**: 运行时动态加载/卸载插件
3. **松耦合架构**: 核心系统与插件完全解耦
4. **依赖管理**: 插件间依赖解析和版本控制
5. **服务可替换**: 所有核心服务可被插件替换
6. **UI 可扩展**: 插件可添加自定义 UI 组件
7. **向后兼容**: 现有功能平滑迁移

### 2.2 非目标

- ❌ 插件沙箱隔离（安全隔离不在第一阶段）
- ❌ 远程插件市场（初期仅本地插件）
- ❌ 插件权限系统（后续版本考虑）

---

## 3. 核心设计原则

### 3.1 SOLID 原则应用

| 原则 | 应用场景 |
|------|----------|
| **单一职责** | 每个插件只负责一个功能域 |
| **开闭原则** | 核心系统对扩展开放，对修改封闭 |
| **里氏替换** | 所有服务可被插件实现替换 |
| **接口隔离** | 插件接口按功能域细分 |
| **依赖倒置** | 核心依赖抽象接口，不依赖具体插件 |

### 3.2 插件化核心原则

1. **约定优于配置**: 插件通过标准化元数据声明能力
2. **显式声明**: 插件必须明确声明所需服务和提供的服务
3. **故障隔离**: 插件崩溃不影响核心系统
4. **渐进式迁移**: 现有功能逐步迁移到插件

---

## 4. 详细架构设计

### 4.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                         UI Layer                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Pages      │  │   Widgets    │  │   Dialogs    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ UI Extension Points
                              │
┌─────────────────────────────────────────────────────────────────┐
│                      Plugin Layer (NEW)                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              PluginManager (Core)                          │  │
│  │  - PluginRegistry    - PluginLoader                        │  │
│  │  - DependencyResolver - LifecycleManager                   │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Plugin Types:                                                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
│  │ Service     │ │ UI          │ │ Data        │               │
│  │ Plugin      │ │ Plugin      │ │ Plugin      │               │
│  └─────────────┘ └─────────────┘ └─────────────┘               │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ Service Extension Points
                              │
┌─────────────────────────────────────────────────────────────────┐
│                       Service Layer                              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │            ServiceRegistry (NEW)                            │  │
│  │  - ServiceFactory  - ServiceLocator                        │  │
│  │  - ServiceResolver - ServiceLifecycle                      │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Core Services:                                                  │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐        │
│  │ Node │ │Graph │ │ AI   │ │Layout│ │Export│ │Import│        │
│  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘        │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ Repository Extension Points
                              │
┌─────────────────────────────────────────────────────────────────┐
│                      Repository Layer                            │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │          RepositoryFactory (NEW)                            │  │
│  │  - RepositoryProvider - RepositoryResolver                 │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Repository Implementations:                                     │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │
│  │ FileSystem   │ │ CloudStorage │ │ Database     │            │
│  └──────────────┘ └──────────────┘ └──────────────┘            │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ Event Bus Communication
                              │
┌─────────────────────────────────────────────────────────────────┐
│                      Event Bus Layer                             │
│                 AppEventBus (Enhanced)                           │
│  - Core Events       - Plugin Events                            │
│  - Service Events    - Lifecycle Events                         │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 新增核心组件

#### 4.2.1 PluginManager

**职责**: 插件生命周期管理、依赖解析、加载/卸载

```dart
/// 插件管理器（核心）
class PluginManager {
  /// 单例
  static final PluginManager instance = PluginManager._internal();
  factory PluginManager() => instance;
  PluginManager._internal();

  /// 插件注册表
  final PluginRegistry _registry = PluginRegistry();

  /// 依赖解析器
  final PluginDependencyResolver _dependencyResolver = PluginDependencyResolver();

  /// 服务定位器（用于访问核心服务）
  late final ServiceLocator _serviceLocator;

  /// 已加载的插件
  final Map<String, PluginInstance> _loadedPlugins = {};

  /// 加载插件
  Future<void> loadPlugin(PluginDescriptor descriptor);

  /// 卸载插件
  Future<void> unloadPlugin(String pluginId);

  /// 获取插件
  PluginInstance? getPlugin(String pluginId);

  /// 触发插件钩子
  Future<T> executeHook<T>(PluginHook hook);
}
```

#### 4.2.2 PluginDescriptor（插件元数据）

```dart
/// 插件描述符（声明式元数据）
class PluginDescriptor {
  /// 插件唯一标识
  final String id;

  /// 插件名称
  final String name;

  /// 插件版本（语义化版本）
  final String version;

  /// 插件描述
  final String description;

  /// 插件作者
  final String author;

  /// 插件类型
  final List<PluginType> types;

  /// 依赖的插件
  final List<PluginDependency> dependencies;

  /// 需要的核心服务
  final Set<String> requiredServices;

  /// 提供的服务（可选）
  final Set<String> providedServices;

  /// 提供的 UI 扩展点
  final List<UIExtensionPoint> uiExtensions;

  /// 提供的数据提供者
  final List<DataProvider> dataProviders;

  /// 插件入口点
  final PluginEntrypoint entrypoint;

  /// 兼容的核心版本
  final Version coreVersion;

  /// 插件配置 Schema
  final Map<String, dynamic>? configSchema;
}

/// 插件类型枚举
enum PluginType {
  /// 服务插件 - 替换或扩展核心服务
  service,

  /// UI 插件 - 添加 UI 组件
  ui,

  /// 数据插件 - 提供数据源或存储
  data,

  /// 转换器插件 - 格式转换
  converter,

  /// AI 提供商插件
  aiProvider,
}

/// 插件依赖声明
class PluginDependency {
  final String pluginId;
  final VersionConstraint versionConstraint;
  final bool isRequired;
}
```

#### 4.2.3 PluginInstance（插件实例）

```dart
/// 插件实例（运行时表示）
class PluginInstance {
  /// 插件描述符
  final PluginDescriptor descriptor;

  /// 插件实现对象
  final Plugin plugin;

  /// 插件状态
  PluginState state;

  /// 插件上下文
  final PluginContext context;

  /// 插件提供的扩展
  final Map<String, dynamic> extensions;

  /// 依赖的其他插件
  final Set<String> dependencies;
}

enum PluginState {
  loaded,
  initialized,
  active,
  suspended,
  failed,
  unloaded,
}
```

#### 4.2.4 PluginContext（插件上下文）

```dart
/// 插件上下文（提供给插件的 API）
class PluginContext {
  /// 访问核心服务（只读）
  T getService<T>();

  /// 发布事件到事件总线
  void publishEvent(AppEvent event);

  /// 订阅事件
  StreamSubscription<AppEvent> subscribeEvent<T>(EventHandler handler);

  /// 访问其他插件
  PluginInstance? getPlugin(String pluginId);

  /// 访问插件配置
  Future<Map<String, dynamic>> getConfig();

  /// 更新插件配置
  Future<void> updateConfig(Map<String, dynamic> config);

  /// 访问应用资源（国际化、主题等）
  AppResources get resources;
}
```

#### 4.2.5 Plugin（基础插件接口）

```dart
/// 插件基础接口（所有插件必须实现）
abstract class Plugin {
  /// 插件描述符
  PluginDescriptor get descriptor;

  /// 初始化插件
  Future<void> initialize(PluginContext context);

  /// 启动插件
  Future<void> start();

  /// 暂停插件
  Future<void> suspend();

  /// 恢复插件
  Future<void> resume();

  /// 停止插件
  Future<void> stop();

  /// 释放资源
  Future<void> dispose();

  /// 处理插件钩子
  Future<dynamic> handleHook(String hookName, Map<String, dynamic> params);
}

/// 服务插件接口
abstract class ServicePlugin extends Plugin {
  /// 提供的服务实现
  Map<Type, dynamic> get services;

  /// 服务优先级（数字越大优先级越高，用于替换默认服务）
  int get priority => 0;
}

/// UI 插件接口
abstract class UIPlugin extends Plugin {
  /// 提供的 UI 扩展
  List<UIExtension> get extensions;
}

/// 数据插件接口
abstract class DataPlugin extends Plugin {
  /// 提供的数据源或存储
  List<DataProvider> get dataProviders;
}

/// AI 提供商插件接口
abstract class AIProviderPlugin extends Plugin {
  /// AI 提供商实现
  AIProvider get provider;
}
```

### 4.3 ServiceRegistry（服务注册表）

**职责**: 管理所有服务（核心 + 插件提供）的注册、解析、生命周期

```dart
/// 服务注册表
class ServiceRegistry {
  final Map<Type, ServiceDescriptor> _services = {};
  final Map<Type, dynamic> _instances = {};

  /// 注册服务
  void register<T>(ServiceDescriptor<T> descriptor);

  /// 注册单例服务
  void registerSingleton<T>(T instance);

  /// 注册工厂方法
  void registerFactory<T>(T Function() factory, {bool lazy = true});

  /// 解析服务
  T resolve<T>();

  /// 尝试解析服务（可能返回 null）
  T? tryResolve<T>();

  /// 检查服务是否已注册
  bool isRegistered<T>();

  /// 获取所有服务
  List<Type> get registeredTypes;

  /// 清理所有服务
  Future<void> dispose();
}

/// 服务描述符
class ServiceDescriptor<T> {
  /// 服务类型
  final Type type;

  /// 服务名称（可选，用于同名多实现）
  final String? name;

  /// 服务实现工厂
  final T Function(ServiceLocator) factory;

  /// 生命周期
  final ServiceLifecycle lifecycle;

  /// 依赖的其他服务
  final List<Type> dependencies;

  /// 服务优先级（用于选择实现）
  final int priority;

  /// 是否延迟加载
  final bool lazy;
}

enum ServiceLifecycle {
  /// 单例（应用生命周期内唯一实例）
  singleton,

  /// 瞬态（每次解析创建新实例）
  transient,

  /// 作用域（在特定作用域内唯一）
  scoped,
}
```

### 4.4 RepositoryFactory（存储工厂）

```dart
/// 存储仓库工厂
class RepositoryFactory {
  final Map<String, RepositoryProvider> _providers = {};

  /// 注册存储提供者
  void registerProvider(RepositoryProvider provider);

  /// 创建 NodeRepository
  Future<NodeRepository> createNodeRepository(String providerId);

  /// 创建 GraphRepository
  Future<GraphRepository> createGraphRepository(String providerId);

  /// 获取默认提供者
  String get defaultProvider;

  /// 设置默认提供者
  set defaultProvider(String providerId);
}

/// 存储提供者接口
abstract class RepositoryProvider {
  /// 提供者 ID
  String get id;

  /// 提供者名称
  String get name;

  /// 创建 NodeRepository
  NodeRepository createNodeRepository();

  /// 创建 GraphRepository
  GraphRepository createGraphRepository();

  /// 提供者能力
  RepositoryCapabilities get capabilities;

  /// 配置 Schema
  Map<String, dynamic> get configSchema;
}

/// 存储能力声明
class RepositoryCapabilities {
  /// 是否支持并发访问
  final bool supportsConcurrency;

  /// 是否支持事务
  final bool supportsTransactions;

  /// 是否支持实时同步
  final bool supportsRealtimeSync;

  /// 是否支持离线模式
  final bool supportsOfflineMode;

  /// 读取延迟（毫秒）
  final int readLatency;

  /// 写入延迟（毫秒）
  final int writeLatency;
}
```

### 4.5 UI Extension System（UI 扩展系统）

#### 4.5.1 ExtensionPoint（扩展点）

```dart
/// UI 扩展点（定义可扩展的 UI 位置）
enum ExtensionPoint {
  /// 主页侧边栏顶部
  homeSidebarTop,

  /// 主页侧边栏底部
  homeSidebarBottom,

  /// 节点上下文菜单
  nodeContextMenu,

  /// 图形上下文菜单
  graphContextMenu,

  /// 工具栏
  toolbar,

  /// 设置页面
  settings,

  /// 导出菜单
  exportMenu,

  /// 导入菜单
  importMenu,

  /// AI 功能菜单
  aiMenu,
}

/// UI 扩展
abstract class UIExtension {
  /// 扩展点
  ExtensionPoint get point;

  /// 构建 UI
  Widget build(BuildContext context);

  /// 优先级（数字越大越靠前）
  int get priority => 0;

  /// 显示条件
  bool isVisible(BuildContext context) => true;
}

/// 菜单项扩展
class MenuItemExtension extends UIExtension {
  final String label;
  final String? icon;
  final VoidCallback onPressed;
  final String? shortcut;
  final bool Function(BuildContext context)? isVisible;

  @override
  ExtensionPoint get point;

  @override
  Widget build(BuildContext context) {
    return MenuItem(
      label: label,
      icon: icon,
      onPressed: onPressed,
      shortcut: shortcut,
    );
  }
}
```

#### 4.5.2 ExtensionRegistry（扩展注册表）

```dart
/// UI 扩展注册表
class ExtensionRegistry {
  final Map<ExtensionPoint, List<UIExtension>> _extensions = {};

  /// 注册扩展
  void register(UIExtension extension) {
    _extensions.putIfAbsent(extension.point, () => []).add(extension);
    _extensions[extension.point]!.sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// 注销扩展
  void unregister(UIExtension extension) {
    _extensions[extension.point]?.remove(extension);
  }

  /// 获取扩展点的所有扩展
  List<UIExtension> getExtensions(ExtensionPoint point, {BuildContext? context}) {
    final extensions = _extensions[point] ?? [];
    if (context != null) {
      return extensions.where((e) => e.isVisible(context)).toList();
    }
    return extensions;
  }

  /// 构建扩展点的 UI
  List<Widget> buildWidgets(ExtensionPoint point, BuildContext context) {
    return getExtensions(point, context: context)
        .map((e) => e.build(context))
        .toList();
  }
}
```

---

## 5. 扩展点设计

### 5.1 服务层扩展点

| 扩展点 | 接口 | 说明 |
|--------|------|------|
| **NodeService** | `NodeService` | 节点 CRUD 操作 |
| **GraphService** | `GraphService` | 图形管理操作 |
| **LayoutService** | `LayoutService` | 布局算法 |
| **ConverterService** | `ConverterService` | 格式转换 |
| **ImportExportService** | `ImportExportService` | 导入导出 |
| **AIService** | `AIService` | AI 功能集成 |
| **StorageProvider** | `RepositoryProvider` | 存储后端 |

### 5.2 UI 层扩展点

| 扩展点 | 位置 | 用途 |
|--------|------|------|
| **homeSidebarTop** | 主页侧边栏顶部 | 快捷操作、信息卡片 |
| **homeSidebarBottom** | 主页侧边栏底部 | 状态信息、设置入口 |
| **nodeContextMenu** | 节点右键菜单 | 节点特定操作 |
| **graphContextMenu** | 图形右键菜单 | 图形特定操作 |
| **toolbar** | 主工具栏 | 常用功能按钮 |
| **settings** | 设置页面 | 插件配置界面 |
| **exportMenu** | 导出菜单 | 自定义导出格式 |
| **importMenu** | 导入菜单 | 自定义导入格式 |
| **aiMenu** | AI 菜单 | AI 功能扩展 |

### 5.3 事件系统扩展

#### 5.3.1 核心事件（现有）

```dart
/// 节点数据变化事件
class NodeDataChangedEvent extends AppEvent {
  final List<Node> changedNodes;
  final DataChangeAction action;
}

/// 图形关系变化事件
class GraphNodeRelationChangedEvent extends AppEvent {
  final String graphId;
  final List<NodeReference> relations;
}
```

#### 5.3.2 插件事件（新增）

```dart
/// 插件加载事件
class PluginLoadedEvent extends AppEvent {
  final String pluginId;
  final String version;
}

/// 插件卸载事件
class PluginUnloadedEvent extends AppEvent {
  final String pluginId;
}

/// 插件错误事件
class PluginErrorEvent extends AppEvent {
  final String pluginId;
  final Object error;
  final StackTrace stackTrace;
}

/// 服务替换事件
class ServiceReplacedEvent extends AppEvent {
  final Type serviceType;
  final String? previousPluginId;
  final String? newPluginId;
}
```

---

## 6. 插件开发指南

### 6.1 插件结构

```
my_plugin/
├── lib/
│   ├── my_plugin.dart          # 插件入口
│   ├── models/                  # 插件数据模型
│   ├── services/                # 插件服务（可选）
│   ├── ui/                      # 插件 UI（可选）
│   └── plugin.yaml              # 插件元数据
├── pubspec.yaml                 # 依赖配置
└── README.md                    # 插件文档
```

### 6.2 插件元数据（plugin.yaml）

```yaml
id: com.example.my_plugin
name: My Plugin
version: 1.0.0
description: A sample plugin for Node Graph Notebook
author: Your Name <email@example.com>

# 插件类型
types:
  - service
  - ui

# 依赖的插件
dependencies:
  - pluginId: com.example.other_plugin
    version: ">=1.2.0"
    required: true

# 需要的核心服务
requiredServices:
  - NodeService
  - GraphService

# 提供的服务（可选）
providedServices:
  - MyCustomService

# 提供的 UI 扩展
uiExtensions:
  - point: homeSidebarTop
    priority: 100
  - point: nodeContextMenu
    priority: 50

# 兼容的核心版本
coreVersion: ">=1.0.0"

# 插件配置 Schema
configSchema:
  type: object
  properties:
    apiKey:
      type: string
      title: API Key
    enabled:
      type: boolean
      title: Enable Plugin
      default: true
```

### 6.3 插件实现示例

#### 6.3.1 服务插件示例

```dart
/// lib/cloud_storage_plugin.dart
library cloud_storage_plugin;

import 'package:node_graph_notebook/plugins/plugins.dart';

/// 云存储插件
class CloudStoragePlugin extends DataPlugin {
  @override
  PluginDescriptor get descriptor => PluginDescriptor(
    id: 'com.example.cloud_storage',
    name: 'Cloud Storage',
    version: '1.0.0',
    description: 'Sync nodes and graphs to cloud storage',
    author: 'Example Inc.',
    types: [PluginType.data],
    dependencies: [],
    requiredServices: {},
    providedServices: {},
    uiExtensions: [
      UIExtensionPoint(
        point: ExtensionPoint.settings,
        widget: CloudStorageSettingsWidget.builder,
      ),
    ],
    dataProviders: [
      DataProvider(
        type: 'nodeRepository',
        implementation: CloudNodeRepository.builder,
      ),
      DataProvider(
        type: 'graphRepository',
        implementation: CloudGraphRepository.builder,
      ),
    ],
    entrypoint: CloudStoragePlugin.new,
    coreVersion: Version.parse('1.0.0'),
    configSchema: {
      'provider': {'type': 'string', 'enum': ['aws', 'gcp', 'azure']},
      'bucket': {'type': 'string'},
      'region': {'type': 'string'},
    },
  );

  @override
  late PluginContext _context;

  @override
  Future<void> initialize(PluginContext context) async {
    _context = context;
    final config = await context.getConfig();
    // 初始化云存储客户端
  }

  @override
  Future<void> start() async {
    // 注册存储提供者
    final registry = context.getService<RepositoryFactory>();
    registry.registerProvider(CloudStorageProvider());
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  List<DataProvider> get dataProviders => descriptor.dataProviders;

  @override
  Future<dynamic> handleHook(String hookName, Map<String, dynamic> params) async {
    switch (hookName) {
      case 'sync':
        return _sync();
      default:
        throw UnimplementedError('Unknown hook: $hookName');
    }
  }

  Future<void> _sync() async {
    // 实现同步逻辑
  }
}
```

#### 6.3.2 UI 插件示例

```dart
/// lib/custom_theme_plugin.dart
library custom_theme_plugin;

import 'package:flutter/material.dart';
import 'package:node_graph_notebook/plugins/plugins.dart';

/// 自定义主题插件
class CustomThemePlugin extends UIPlugin {
  @override
  PluginDescriptor get descriptor => PluginDescriptor(
    id: 'com.example.custom_theme',
    name: 'Custom Theme',
    version: '1.0.0',
    description: 'Add custom themes to the application',
    author: 'Example Inc.',
    types: [PluginType.ui],
    dependencies: [],
    requiredServices: {'ThemeService'},
    providedServices: {},
    uiExtensions: [
      UIExtensionPoint(
        point: ExtensionPoint.settings,
        widget: CustomThemeSettingsWidget.builder,
      ),
    ],
    dataProviders: [],
    entrypoint: CustomThemePlugin.new,
    coreVersion: Version.parse('1.0.0'),
  );

  @override
  late PluginContext _context;

  @override
  Future<void> initialize(PluginContext context) async {
    _context = context;
    final themeService = context.getService<ThemeService>();

    // 注册自定义主题
    themeService.registerTheme('sunset', AppTheme(
      name: 'Sunset',
      primaryColor: Color(0xFFFF6B6B),
      secondaryColor: Color(0xFF4ECDC4),
      backgroundColor: Color(0xFFF7FFF7),
      textColor: Color(0xFF2D3436),
    ));
  }

  @override
  List<UIExtension> get extensions => [
    MenuItemExtension(
      point: ExtensionPoint.settings,
      label: 'Custom Themes',
      icon: 'palette',
      onPressed: () => _showThemeDialog(),
      priority: 100,
    ),
  ];

  void _showThemeDialog() {
    // 显示主题选择对话框
  }

  @override
  Future<void> start() async {}
  @override
  Future<void> suspend() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<dynamic> handleHook(String hookName, Map<String, dynamic> params) async {}
}
```

#### 6.3.3 AI 提供商插件示例

```dart
/// lib/claude_ai_plugin.dart
library claude_ai_plugin;

import 'package:node_graph_notebook/plugins/plugins.dart';
import 'package:node_graph_notebook/core/services/ai/ai_provider.dart';

/// Claude AI 插件
class ClaudeAIPlugin extends AIProviderPlugin {
  @override
  PluginDescriptor get descriptor => PluginDescriptor(
    id: 'com.anthropic.claude',
    name: 'Claude AI',
    version: '1.0.0',
    description: 'Anthropic Claude AI integration',
    author: 'Anthropic',
    types: [PluginType.aiProvider],
    dependencies: [],
    requiredServices: {'AIService', 'SettingsService'},
    providedServices: {},
    uiExtensions: [
      UIExtensionPoint(
        point: ExtensionPoint.aiMenu,
        widget: ClaudeAIWidget.builder,
      ),
    ],
    dataProviders: [],
    entrypoint: ClaudeAIPlugin.new,
    coreVersion: Version.parse('1.0.0'),
    configSchema: {
      'apiKey': {'type': 'string'},
      'model': {'type': 'string', 'default': 'claude-3-sonnet'},
      'maxTokens': {'type': 'integer', 'default': 4096},
    },
  );

  @override
  late PluginContext _context;

  @override
  Future<void> initialize(PluginContext context) async {
    _context = context;
    final config = await context.getConfig();

    // 创建 Claude 提供商
    final provider = ClaudeAIProvider(
      apiKey: config['apiKey'],
      model: config['model'] ?? 'claude-3-sonnet',
      maxTokens: config['maxTokens'] ?? 4096,
    );

    // 注册到 AI 服务
    final aiService = context.getService<AIService>();
    aiService.registerProvider('claude', provider);
  }

  @override
  AIProvider get provider => ClaudeAIProvider(
    apiKey: '',
    model: 'claude-3-sonnet',
  );

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<dynamic> handleHook(String hookName, Map<String, dynamic> params) async {}
}
```

---

## 7. 实现路线图

### 7.1 阶段 1: 基础设施（2-3 周）

**目标**: 建立插件系统核心基础设施

**任务**:
1. ✅ 创建 `PluginManager` 和 `PluginRegistry`
2. ✅ 实现 `PluginDescriptor` 和 `PluginContext`
3. ✅ 创建 `ServiceRegistry` 替换现有的 Provider 注册
4. ✅ 实现插件元数据解析（YAML → PluginDescriptor）
5. ✅ 添加基础插件接口（`Plugin`, `ServicePlugin`, `UIPlugin`, `DataPlugin`）
6. ✅ 创建插件加载器（从本地文件系统动态加载）

**交付物**:
- `lib/plugins/core/plugin_manager.dart`
- `lib/plugins/core/plugin_registry.dart`
- `lib/plugins/core/plugin_descriptor.dart`
- `lib/plugins/core/plugin_context.dart`
- `lib/core/services/service_registry.dart`
- `lib/plugins/core/interfaces/` （插件接口）

### 7.2 阶段 2: 服务插件化（2-3 周）

**目标**: 将现有服务迁移到插件系统

**任务**:
1. ✅ 创建内置服务插件（将现有服务包装成插件）
2. ✅ 实现 `RepositoryFactory` 和存储提供者
3. ✅ 迁移 `NodeService` 到服务插件
4. ✅ 迁移 `GraphService` 到服务插件
5. ✅ 迁移 `LayoutService` 到服务插件
6. ✅ 迁移 `ImportExportService` 到服务插件
7. ✅ 更新 `app.dart` 使用 `ServiceRegistry`

**交付物**:
- `lib/plugins/builtin_services/` （内置服务插件）
- `lib/core/repositories/repository_factory.dart`
- 更新的 `lib/app.dart`

### 7.3 阶段 3: UI 扩展系统（1-2 周）

**目标**: 实现 UI 扩展点

**任务**:
1. ✅ 定义 `ExtensionPoint` 枚举
2. ✅ 创建 `ExtensionRegistry`
3. ✅ 实现 `UIExtension` 基类和子类
4. ✅ 在主页添加侧边栏扩展点
5. ✅ 在节点/图形组件添加上下文菜单扩展点
6. ✅ 在设置页面添加插件配置扩展点
7. ✅ 创建插件 UI 测试页面

**交付物**:
- `lib/plugins/ui/extension_system.dart`
- `lib/plugins/ui/extensions/` （UI 扩展类）
- 更新的 UI 组件（集成扩展点）
- `lib/ui/pages/plugin_management_page.dart`

### 7.4 阶段 4: 现有插件迁移（1-2 周）

**目标**: 将现有插件迁移到新系统

**任务**:
1. ✅ 迁移 `AIPlugin` 到新的插件系统
2. ✅ 迁移 `ExportPlugin` 到 UI 插件
3. ✅ 迁移 `LayoutPlugin` 到服务插件
4. ✅ 迁移 `SmartLayoutPlugin` 到服务插件
5. ✅ 删除旧的 `GraphPlugin` 接口
6. ✅ 更新插件文档

**交付物**:
- 迁移后的内置插件
- 删除的 `lib/plugins/hooks/graph_plugin.dart`
- 更新的插件文档

### 7.5 阶段 5: 示例插件开发（1 周）

**目标**: 开发示例插件展示系统能力

**任务**:
1. ✅ 开发云存储插件示例
2. ✅ 开发自定义主题插件示例
3. ✅ 开发新的 AI 提供商插件示例（Claude）
4. ✅ 开发自定义布局算法插件示例
5. ✅ 编写插件开发教程

**交付物**:
- `plugins/example/cloud_storage_plugin/`
- `plugins/example/custom_theme_plugin/`
- `plugins/example/claude_ai_plugin/`
- `plugins/example/custom_layout_plugin/`
- `docs/plugin_development_guide.md`

### 7.6 阶段 6: 测试与优化（1-2 周）

**目标**: 确保系统稳定性和性能

**任务**:
1. ✅ 编写单元测试（插件加载、依赖解析、生命周期）
2. ✅ 编写集成测试（插件与服务交互）
3. ✅ 性能测试（插件加载时间、内存占用）
4. ✅ 错误处理测试（插件崩溃、依赖失败）
5. ✅ 优化依赖解析算法
6. ✅ 优化插件加载性能
7. ✅ 添加调试日志和错误提示

**交付物**:
- `test/plugins/` （插件测试）
- 性能测试报告
- 错误处理文档

### 7.7 阶段 7: 文档与发布（1 周）

**目标**: 完善文档并准备发布

**任务**:
1. ✅ 编写插件开发完整文档
2. ✅ 编写 API 参考文档
3. ✅ 编写插件迁移指南
4. ✅ 创建插件模板项目
5. ✅ 录制插件开发教程视频（可选）
6. ✅ 发布 v2.0.0 版本

**交付物**:
- `docs/plugin_architecture.md` （本文档）
- `docs/plugin_development_guide.md`
- `docs/plugin_api_reference.md`
- `docs/plugin_migration_guide.md`
- `plugin_template/` （插件模板项目）

---

## 8. 关键技术决策

### 8.1 插件加载机制

**决策**: **基于文件系统的动态加载**

**原因**:
- ✅ Flutter 对动态代码加载有限制，但可以通过文件系统 + `Isolate` 实现
- ✅ 简单可靠，无需复杂的构建时处理
- ✅ 插件作为独立包，通过符号链接或复制到插件目录
- ⚠️ 需要在应用启动时扫描插件目录

**备选方案**: **构建时代码生成**
- ❌ 需要修改构建流程
- ❌ 插件开发者需要应用源码
- ❌ 无法运行时加载插件

### 8.2 依赖注入框架

**决策**: **自研轻量级 ServiceRegistry**

**原因**:
- ✅ 完全控制，适配插件系统需求
- ✅ 无需引入额外依赖
- ✅ 可以实现服务优先级和替换逻辑
- ✅ 支持延迟加载和生命周期管理

**备选方案**: 使用 `get_it` 或 `provider`
- ⚠️ `get_it`: 功能强大但增加依赖
- ⚠️ `provider`: 已在使用，但不支持服务替换

### 8.3 插件通信

**决策**: **事件总线 + 直接服务访问（混合模式）**

**原因**:
- ✅ 事件总线实现松耦合通信
- ✅ 直接服务访问用于必需的功能调用
- ✅ 清晰的边界：插件间用事件总线，插件与核心用服务访问

**架构**:
```
Plugin A → Event Bus → Plugin B (松耦合)
Plugin A → ServiceLocator → CoreService (直接访问)
Plugin A → PluginContext → Plugin B (受控访问)
```

### 8.4 插件隔离

**决策**: **不实现沙箱隔离（第一阶段）**

**原因**:
- ✅ Flutter 不支持真正的代码隔离
- ✅ 插件信任模型：用户主动安装插件
- ✅ 性能考虑：无隔离开销
- ⚠️ 插件可以访问所有核心服务

**未来考虑**:
- 插件权限系统
- 敏感服务需要显式授权
- 插件审计和签名

### 8.5 配置管理

**决策**: **插件配置使用 SharedPreferencesAsync**

**原因**:
- ✅ 与应用配置一致
- ✅ 异步访问，不阻塞 UI
- ✅ 类型安全（通过配置 Schema）
- ✅ 支持配置验证

**配置存储格式**:
```json
{
  "plugins": {
    "com.example.my_plugin": {
      "enabled": true,
      "config": {
        "apiKey": "sk-...",
        "autoSync": true
      }
    }
  }
}
```

---

## 9. 风险与挑战

### 9.1 技术风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| **动态加载限制** | 高 | 使用文件系统 + Isolate，提供清晰的加载错误提示 |
| **性能开销** | 中 | 实现延迟加载，优化依赖解析算法 |
| **内存占用** | 中 | 实现插件生命周期管理，支持卸载未使用插件 |
| **向后兼容性** | 高 | 分阶段迁移，保持现有 API 稳定 |
| **插件崩溃** | 高 | 故障隔离，插件错误不影响核心系统 |

### 9.2 开发挑战

| 挑战 | 解决方案 |
|------|----------|
| **依赖解析复杂度** | 使用拓扑排序算法，清晰的依赖错误提示 |
| **API 稳定性** | 语义化版本控制，详细的变更日志 |
| **插件测试** | 提供插件测试框架和 Mock 工具 |
| **文档维护** | 自动化 API 文档生成，插件模板项目 |
| **用户支持** | 插件调试工具，详细的错误日志 |

### 9.3 用户体验挑战

| 挑战 | 解决方案 |
|------|----------|
| **插件发现** | 插件管理页面，分类和搜索功能 |
| **安装复杂度** | 一键安装，自动依赖解析 |
| **配置复杂度** | 提供配置 UI，Schema 驱动的表单生成 |
| **更新管理** | 自动检查更新，版本兼容性检查 |

---

## 10. 成功指标

### 10.1 技术指标

- ✅ **插件加载时间**: < 500ms（3 个插件）
- ✅ **内存开销**: < 10MB（基础系统 + 5 个插件）
- ✅ **依赖解析时间**: < 100ms
- ✅ **插件崩溃率**: < 0.1%
- ✅ **API 稳定性**: 90% 的 API 在 2 个版本内保持兼容

### 10.2 开发者指标

- ✅ **插件开发时间**: < 4 小时（简单插件）
- ✅ **插件迁移时间**: < 2 天（从旧系统）
- ✅ **文档完整性**: 覆盖 100% 的公共 API
- ✅ **示例插件**: ≥ 5 个官方示例插件

### 10.3 用户指标

- ✅ **插件安装成功率**: > 95%
- ✅ **插件更新率**: > 80%（兼容更新）
- ✅ **插件崩溃影响**: 0%（核心系统不受影响）

---

## 11. 后续演进方向

### 11.1 第二阶段功能（v2.1.0）

1. **插件市场**
   - 远程插件仓库
   - 插件评分和评论
   - 自动更新

2. **插件权限系统**
   - 敏感服务访问控制
   - 用户授权提示
   - 权限审计

3. **插件沙箱**
   - 限制文件系统访问
   - 限制网络访问
   - 资源使用限制

### 11.2 第三阶段功能（v3.0.0）

1. **Web 插件支持**
   - WebAssembly 插件
   - 浏览器内开发工具

2. **插件编排**
   - 插件工作流
   - 条件触发
   - 数据流管道

3. **AI 辅助插件开发**
   - AI 生成插件代码
   - 智能插件推荐

---

## 12. 附录

### 12.1 术语表

| 术语 | 定义 |
|------|------|
| **插件** | 可动态加载的功能扩展模块 |
| **核心系统** | 不依赖插件的应用基础功能 |
| **扩展点** | 预定义的插件可介入的位置 |
| **服务** | 提供特定业务逻辑的对象 |
| **依赖注入** | 控制反转的一种实现方式 |
| **插件描述符** | 插件的元数据声明 |
| **插件上下文** | 插件与核心系统的交互接口 |
| **生命周期** | 插件从加载到卸载的状态变化 |

### 12.2 参考资料

- [Flutter 插件开发最佳实践](https://docs.flutter.dev/development/packages-and-plugins/developing-packages)
- [VS Code 扩展 API](https://code.visualstudio.com/api)
- [Eclipse 插件架构](https://wiki.eclipse.org/Plug-in_Development_Environment_Guide)
- [WordPress 插件手册](https://developer.wordpress.org/plugins/)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

### 12.3 变更日志

| 版本 | 日期 | 变更说明 |
|------|------|----------|
| 1.0.0 | 2025-01-14 | 初始版本 |

---

## 13. 联系方式

如有问题或建议，请联系：
- **项目仓库**: [GitHub](https://github.com/your-repo/node-graph-notebook)
- **Issue 跟踪**: [GitHub Issues](https://github.com/your-repo/node-graph-notebook/issues)
- **讨论区**: [GitHub Discussions](https://github.com/your-repo/node-graph-notebook/discussions)

---

**文档结束**
