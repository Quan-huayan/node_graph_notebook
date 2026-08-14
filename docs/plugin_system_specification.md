# Plugin System Specification

> Node Graph Notebook 插件系统规范 — v1.0.0
>
> 本文档定义插件的开发规范、生命周期、API 约定及最佳实践。所有插件必须遵守本规范。

---

## 目录

1. [架构概览](#1-架构概览)
2. [Plugin 抽象基类](#2-plugin-抽象基类)
3. [PluginMetadata — 元数据](#3-pluginmetadata--元数据)
4. [生命周期](#4-生命周期)
5. [ServiceRegistration — 服务注册](#5-serviceregistration--服务注册)
6. [Hook 系统](#6-hook-系统)
7. [Bloc 注册](#7-bloc-注册)
8. [Command Handler 注册](#8-command-handler-注册)
9. [PluginContext — 插件上下文](#9-plugincontext--插件上下文)
10. [PluginManager — 插件管理器](#10-pluginmanager--插件管理器)
11. [依赖管理](#11-依赖管理)
12. [编码规范](#12-编码规范)
13. [完整示例](#13-完整示例)

---

## 1. 架构概览

```
┌─────────────────────────────────────────────────────┐
│                    PluginManager                     │
│  load → registerServices → onLoad → registerHooks   │
│  enable → onEnable                                  │
│  disable → onDisable                                │
│  unload → onDisable → onUnload → cleanup            │
└─────────────────────────────────────────────────────┘
                          │
         ┌────────────────┼────────────────┐
         ▼                ▼                ▼
   ServiceRegistry   HookRoleRegistry   BlocProviders
   (DI Container)    (Extension Pts)    (Flutter BLoC)
```

**核心设计原则：**

- **单一职责**：插件封装一个功能领域（图、编辑、搜索等）
- **显式依赖**：依赖声明在 `PluginMetadata.dependencies` 中
- **DI 优先**：通过 `ServiceRegistry` 获取依赖，避免全局单例
- **Hook 扩展**：通过 Hook 点机制扩展 UI，不直接修改框架代码
- **CQRS 分离**：写操作走 `CommandBus`，读操作走 `QueryBus` 或 Repository

---

## 2. Plugin 抽象基类

所有插件必须继承 `Plugin`（位于 `package:plugin/plugin.dart`）。

```dart
abstract class Plugin {
  PluginMetadata get metadata;                       // 必须实现

  List<ServiceRegistration> registerServices() => []; // 可选
  List<BlocProvider> registerBlocs() => [];           // 可选
  List<HookFactory> registerHooks() => [];            // 可选

  Future<void> onLoad(PluginContext context) async {}   // 可选
  Future<void> onEnable() async {}                      // 可选
  Future<void> onDisable() async {}                     // 可选
  Future<void> onUnload() async {}                      // 可选
}
```

| 方法 | 调用时机 | 用途 |
|------|---------|------|
| `registerServices()` | `onLoad` 之前 | 声明服务注册到 `ServiceRegistry` |
| `registerHooks()` | `onLoad` 之后 | 声明 Hook 注册到 `HookRoleRegistry` |
| `registerBlocs()` | 任意（查询时） | 声明 BlocProvider 加入 Provider Tree |
| `onLoad(context)` | 服务注册后 | 初始化：注册 CommandHandler、TaskType 等 |
| `onEnable()` | 加载后 / 手动启用 | 激活插件功能 |
| `onDisable()` | 手动禁用 / 卸载前 | 暂停插件功能 |
| `onUnload()` | 卸载时 | 释放资源 |

---

## 3. PluginMetadata — 元数据

```dart
const PluginMetadata({
  required this.id,              // 唯一标识符（必填）
  required this.name,            // 显示名称（必填）
  required this.version,         // 语义化版本（必填）
  this.description = '',         // 描述
  this.author = '',              // 作者
  this.dependencies = const [],  // 依赖的插件 ID 列表
  this.enabledByDefault = true,  // 是否默认启用
});
```

### 3.1 ID 命名规范

插件 ID 必须唯一。推荐使用简洁的功能名：

| ✅ 推荐 | ❌ 不推荐 | 说明 |
|---------|----------|------|
| `graph` | `graph_plugin` | 避免 `_plugin` 后缀 |
| `search` | `com.example.search` | 项目内插件不需要反向域名 |
| `ai` | `AI` | 全小写 |
| `data_recovery` | `data-recovery` | 使用下划线分隔 |

**规范：** 使用小写字母 + 下划线，简洁描述功能领域。

### 3.2 依赖声明

`dependencies` 列表声明本插件依赖的其他插件 ID。PluginManager 按拓扑顺序加载，启用插件前确保依赖已启用。

```dart
// 正确：声明对 core 和 appframe 的依赖
dependencies: ['core', 'appframe'],

// 错误：使用了其他插件的服务但未声明依赖
dependencies: [],  // 实际使用了 NodeService（来自 graph 插件）
```

---

## 4. 生命周期

```
                    loadPlugin()
                        │
                        ▼
              registerServices()   ← 注册服务到 ServiceRegistry
                        │
                        ▼
                 onLoad(context)   ← 初始化（注册 CommandHandler 等）
                        │
                        ▼
              registerHooks()      ← 注册 Hook 到 HookRoleRegistry
                        │
                        ▼
              enablePlugin()       ← 如果 enabledByDefault
                        │
                        ▼
                  onEnable()       ← 激活功能
                        │
             ┌──────────┴──────────┐
             ▼                     ▼
        onDisable()           onDisable()
             │                     │
             ▼                     ▼
         onEnable()           onUnload()
                                 │
                                 ▼
                          cleanup services/hooks
```

### 4.1 各阶段职责

**`onLoad(context)` — 初始化阶段**
- 注册 CommandHandler 到 CommandBus
- 注册 TaskType 到 TaskRegistry
- 注册 HookPointDefinition（如果是本插件定义的 Hook 点）
- 执行一次性初始化逻辑
- **不要**在这里启动后台服务（放到 `onEnable`）

**`onEnable()` — 激活阶段**
- 启动后台服务（如 LuaCommandServer）
- 订阅事件流
- 注册回调

**`onDisable()` — 停用阶段**
- 停止后台服务
- 取消事件订阅
- 插件实例保留，可以再次 `onEnable()`

**`onUnload()` — 卸载阶段**
- 释放所有资源
- PluginManager 自动清理此插件的 Service 和 Hook

---

## 5. ServiceRegistration — 服务注册

### 5.1 四种注册方式

```dart
// 1. 注册普通实例 → Provider<T>.value
ServiceRegistration.of<T>(instance, owner: metadata.id)

// 2. 注册 ChangeNotifier 实例 → ChangeNotifierProvider<T>.value
ServiceRegistration.notifier<T>(instance, owner: metadata.id)

// 3. 注册工厂（延迟创建）→ Provider<T>.value
ServiceRegistration.singleton<T>((reg) => ServiceImpl(dep: reg.get<Dep>()), owner: metadata.id)

// 4. 注册 ChangeNotifier 工厂 → ChangeNotifierProvider<T>.value
ServiceRegistration.notifierFactory<T>((reg) => Notifier(dep: reg.get<Dep>()), owner: metadata.id)
```

### 5.2 选择指南

| 场景 | 使用 |
|------|------|
| 无状态服务 / 工具类 | `singleton` |
| 有状态且需通知 UI | `notifier` 或 `notifierFactory` |
| 需要访问其他服务来构造 | `singleton` 或 `notifierFactory`（使用 `reg` 参数） |
| 外部已构造好的实例 | `of` 或 `notifier` |
| 跨插件共享的服务 | **始终**设置 `owner: metadata.id` |

### 5.3 反模式

```dart
// ❌ 不要手动注册到 ServiceRegistry
@override
Future<void> onLoad(PluginContext context) async {
  context.get<ServiceRegistry>().register<MyService>(instance: MyService());
}

// ✅ 使用 registerServices()
@override
List<ServiceRegistration> registerServices() => [
  ServiceRegistration.singleton<MyService>((_) => MyService(), owner: metadata.id),
];
```

---

## 6. Hook 系统

### 6.1 Hook 架构

```
HookRoleRegistry (ChangeNotifier)
├── HookPointDefinition  ← 定义可扩展的位置
├── HookWrapper          ← 包装 Hook 实例 + 生命周期状态
│   └── HookRoleBase     ← Hook 实现
│       ├── metadata     ← Hook 元数据
│       ├── hookPointId  ← 挂载的 Hook 点
│       ├── priority     ← 排序优先级
│       ├── render()     ← 渲染
│       └── exportAPIs() ← 导出 API 供其他 Hook 使用
└── HookAPIRegistry      ← 跨 Hook API 通信
```

### 6.2 标准 Hook 点

| Hook 点 ID | 用途 | Context 类型 |
|-----------|------|-------------|
| `root` | 主窗口布局 | `RootHookContext` |
| `sidebar` | 侧边栏布局 | `SidebarLayoutHookContext` |
| `sidebar.tab` | 侧边栏标签页 | `SidebarHookContext` |
| `sidebar.bottom` | 侧边栏底部 | `SidebarHookContext` |
| `main.toolbar` | 主工具栏按钮 | `MainToolbarHookContext` |
| `graph.toolbar` | 图工具栏按钮 | `MainToolbarHookContext` |
| `context_menu.node` | 节点右键菜单 | `NodeContextMenuHookContext` |
| `context_menu.graph` | 图右键菜单 | `GraphContextMenuHookContext` |
| `status.bar` | 状态栏 | `StatusBarHookContext` |
| `help` | 帮助 | `HelpHookContext` |
| `settings` | 设置面板 | `SettingsHookContext` |

### 6.3 类型安全 Hook 基类

`package:appframe/ui/hooks/hook_bases.dart` 提供了类型安全的 Hook 基类：

| 基类 | Hook 点 | 渲染方法 |
|------|--------|---------|
| `MainToolbarHookRole` | `main.toolbar` | `renderToolbar(MainToolbarHookContext)` |
| `GraphToolbarHookRole` | `graph.toolbar` | `renderToolbar(MainToolbarHookContext)` |
| `SidebarTabHookRole` | `sidebar.tab` | `buildContent(SidebarHookContext)` |
| `SidebarBottomHookRole` | `sidebar.bottom` | `renderSidebar(SidebarHookContext)` |
| `SidebarHookRole` | （手动指定） | `renderSidebar(SidebarHookContext)` |
| `StatusBarHookRole` | （手动指定） | `renderStatusBar(StatusBarHookContext)` |
| `NodeContextMenuHookRole` | `context_menu.node` | `renderMenu(NodeContextMenuHookContext)` |
| `RootHookRole` | `root` | `renderRoot(RootHookContext)` |
| `SidebarLayoutHookRole` | `sidebar` | `renderSidebar(SidebarLayoutHookContext)` |

### 6.4 Hook 开发规范

```dart
/// ✅ 正确：使用类型安全的基类
class MyToolbarHook extends MainToolbarHookRole {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'my.toolbar_button',       // 唯一 ID
    name: 'My Toolbar Button',
    version: '1.0.0',
    description: 'Adds my button to the main toolbar',
  );

  @override
  HookPriority get priority => HookPriority.high;

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    // context 是类型安全的，可直接访问 showTitle, showSearch 等
    return IconButton(icon: const Icon(Icons.star), onPressed: () {});
  }
}
```

### 6.5 Hook 优先级

```dart
enum HookPriority {
  critical(0),   // 框架级 Hook（Root、Sidebar 布局）
  highest(10),
  high(100),
  custom50(50), custom60(60), custom70(70), custom80(80),
  custom150(150), custom200(200), custom250(250), custom300(300),
  medium(500),   // 默认
  low(900),
  lowest(1000),
}
```

### 6.6 自定义 Hook 点

如果插件需要暴露可扩展的位置：

```dart
@override
Future<void> onLoad(PluginContext context) async {
  final hr = context.tryGet<HookRoleRegistry>();
  hr?.registerHookPoint(const HookPointDefinition(
    id: 'editor.node',
    name: 'Node Editor',
    description: 'Node content editor extension point',
    category: 'editor',
    contextType: NodeEditorHookContext,
  ));
}
```

---

## 7. Bloc 注册

```dart
@override
List<BlocProvider> registerBlocs() => [
  BlocProvider<MyBloc>(
    create: (ctx) => MyBloc(
      commandBus: ctx.read<CommandBus>(),
      queryBus: ctx.read<QueryBus>(),
    )..add(const MyInitialEvent()),  // 触发初始数据加载
  ),
];
```

**规范：**
- Bloc 通过 `ctx.read<T>()` 获取依赖
- 使用 cascade `..add()` 触发初始事件
- Bloc 只管理 UI 状态，业务逻辑委托给 CommandBus

---

## 8. Command Handler 注册

Command Handler 在 `onLoad` 中注册到 `CommandBus`：

```dart
@override
Future<void> onLoad(PluginContext context) async {
  final commandBus = context.get<CommandBus>();
  final myService = context.get<MyService>();

  commandBus.registerHandlers({
    DoSomethingCommand: DoSomethingHandler(myService),
    DoAnotherCommand: DoAnotherHandler(myService),
  });
}
```

**规范：**
- 使用 `context.get<T>()` 获取服务（类型安全，不存在时抛异常）
- 使用 `context.tryGet<T>()` 获取可选服务（不存在时返回 null）
- 使用 `registerHandlers({})` 批量注册（Map 形式）
- 或使用 `registerHandler(handler, commandType)` 逐个注册

---

## 9. PluginContext — 插件上下文

```dart
class PluginContext {
  String get pluginId;            // 当前插件 ID
  PluginMetadata get metadata;     // 当前插件元数据

  T get<T>();                     // 获取服务（不存在抛异常）
  T? tryGet<T>();                 // 尝试获取服务（不存在返回 null）
}
```

在 `onLoad` 中通过 `context` 参数访问所有已注册的服务。

---

## 10. PluginManager — 插件管理器

### 10.1 创建

```dart
final pluginManager = PluginManager(
  serviceRegistry: serviceRegistry,
  hookRegistry: hookRegistry,  // HookRoleRegistry 实例
);
```

**重要：** 必须传入 `hookRegistry`，否则 `registerHooks()` 不会生效。

### 10.2 API

| 方法 | 说明 |
|------|------|
| `loadPlugin(plugin)` | 注册服务 → onLoad → 注册 Hook |
| `enablePlugin(id)` | 确保依赖启用 → onEnable |
| `disablePlugin(id)` | onDisable |
| `unloadPlugin(id)` | disable → onUnload → 清理服务/Hook |
| `generateBlocProviders()` | 生成所有插件的 BlocProvider 列表 |
| `getPlugin(id)` | 获取已加载的插件包装器 |

---

## 11. 依赖管理

### 11.1 声明依赖

插件必须在 `metadata.dependencies` 中声明所有依赖：

```dart
@override
PluginMetadata get metadata => const PluginMetadata(
  id: 'my_plugin',
  name: 'My Plugin',
  version: '1.0.0',
  dependencies: ['core', 'appframe', 'graph'],  // 依赖声明
);
```

### 11.2 依赖检查清单

- [ ] 使用了 `CommandBus` / `QueryBus` → 依赖 `core`
- [ ] 使用了 `UILayoutService` / `I18n` / `SettingsRegistry` → 依赖 `core`
- [ ] 使用了 `StoragePathService` / `ThemeService` → 依赖 `appframe`
- [ ] 使用了 `NodeService` / `GraphService` → 依赖 `graph`
- [ ] 使用了其他插件的服务 → 依赖对应插件

### 11.3 加载顺序

PluginManager 不自动按依赖排序，调用方需按正确顺序加载：

```dart
await pluginManager.loadPlugin(CorePlugin(hookRoleRegistry: hookRegistry));
await pluginManager.loadPlugin(AppFramePlugin());
await pluginManager.loadPlugin(GraphPlugin());
await pluginManager.loadPlugin(MyPlugin());  // 依赖 graph
```

---

## 12. 编码规范

### 12.1 文件结构

```
packages/my_plugin/
├── lib/
│   ├── my_plugin.dart           # Plugin 主类
│   ├── command/                 # Command 定义
│   ├── handler/                 # Command Handler
│   ├── service/                 # 业务服务
│   ├── bloc/                    # BLoC（状态管理）
│   ├── ui/                      # UI 组件
│   ├── hooks/                   # Hook 实现
│   └── models/                  # 插件专属模型
└── pubspec.yaml
```

### 12.2 导入规范

```dart
// ✅ 正确：从 plugin 包导入 Plugin 基类
import 'package:plugin/plugin.dart';

// ✅ 从 core 包导入基础设施（hide 避免冲突）
import 'package:core/core.dart' hide Plugin, PluginManager;

// ❌ 错误：从 core 包导入 Plugin（类型冲突）
import 'package:core/core.dart';  // core 可能 re-export Plugin
```

### 12.3 日志

使用 `debugPrint()` 或 `AppLogger`：

```dart
const _log = AppLogger('MyPlugin');

_log.info('Plugin loaded');
_log.debug('Registered 3 command handlers');
_log.warning('Optional service not available');
_log.error('Failed to initialize: $error');
```

### 12.4 错误处理

```dart
@override
Future<void> onLoad(PluginContext context) async {
  try {
    final optionalService = context.tryGet<OptionalService>();
    if (optionalService == null) {
      debugPrint('[MyPlugin] OptionalService not available, skipping feature');
      return;  // 优雅降级
    }
    // ... use optionalService
  } catch (e) {
    debugPrint('[MyPlugin] Load failed: $e');
    rethrow;  // 致命错误向上传播
  }
}
```

### 12.5 命名规范

| 元素 | 规范 | 示例 |
|------|------|------|
| 插件 ID | 小写+下划线，不用 `_plugin` 后缀 | `search`, `data_recovery` |
| 插件类 | PascalCase + `Plugin` 后缀 | `SearchPlugin` |
| Hook ID | 小写+点分隔 | `search.sidebar_panel` |
| Hook 类 | PascalCase + `Hook` 后缀 | `SearchSidebarHook` |
| Service ID | 与实现类相同 | `SearchPresetService` |
| Command 类 | PascalCase + `Command` 后缀 | `SaveSearchPresetCommand` |
| Handler 类 | PascalCase + `Handler` 后缀 | `SaveSearchPresetHandler` |

---

## 13. 完整示例

```dart
import 'package:core/core.dart' hide Plugin, PluginManager;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plugin/plugin.dart';

import 'bloc/example_bloc.dart';
import 'command/example_commands.dart';
import 'handler/example_handler.dart';
import 'hooks/example_toolbar_hook.dart';
import 'service/example_service.dart';

/// Example 插件 — 展示标准插件结构。
class ExamplePlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'example',
    name: 'Example',
    version: '1.0.0',
    description: 'An example plugin demonstrating proper structure',
    author: 'Node Graph Notebook',
    enabledByDefault: true,
    dependencies: ['core', 'appframe'],
  );

  // ── 服务注册 ──
  @override
  List<ServiceRegistration> registerServices() => [
    ServiceRegistration.singleton<ExampleService>(
      (reg) => ExampleServiceImpl(reg.get<SomeDependency>()),
      owner: metadata.id,
    ),
  ];

  // ── Bloc 注册 ──
  @override
  List<BlocProvider> registerBlocs() => [
    BlocProvider<ExampleBloc>(
      create: (ctx) => ExampleBloc(
        service: ctx.read<ExampleService>(),
        commandBus: ctx.read<CommandBus>(),
      )..add(const ExampleInitialEvent()),
    ),
  ];

  // ── Hook 注册 ──
  @override
  List<HookFactory> registerHooks() => [
    ExampleToolbarHook.new,
  ];

  // ── 初始化 ──
  @override
  Future<void> onLoad(PluginContext context) async {
    final commandBus = context.get<CommandBus>();
    final service = context.get<ExampleService>();

    commandBus.registerHandlers({
      ExampleCommand: ExampleHandler(service),
    });

    debugPrint('[ExamplePlugin] Loaded');
  }

  // ── 生命周期 ──

  @override
  Future<void> onEnable() async {
    debugPrint('[ExamplePlugin] Enabled');
  }

  @override
  Future<void> onDisable() async {
    debugPrint('[ExamplePlugin] Disabled');
  }

  @override
  Future<void> onUnload() async {
    debugPrint('[ExamplePlugin] Unloaded');
  }
}
```
