# 用例 04: 插件系统工作流程

## 概述

本文档描述插件系统的完整生命周期管理，包括加载、卸载、启用、禁用、Hook注册、服务注册、BLoC注册等操作的调用链和数据流。

## 用户角色

| 角色 | 描述 |
|------|------|
| 普通用户 | 使用插件提供的功能 |
| 插件开发者 | 开发、调试、发布插件 |
| 系统管理员 | 管理插件启用/禁用状态 |

## 用例列表

| 用例ID | 用例名称 | 优先级 | 触发者 |
|--------|----------|--------|--------|
| UC-PLUGIN-01 | 系统启动加载插件 | P0 | 系统 |
| UC-PLUGIN-02 | 加载单个插件 | P0 | 系统/用户 |
| UC-PLUGIN-03 | 卸载插件 | P1 | 用户 |
| UC-PLUGIN-04 | 启用插件 | P1 | 用户 |
| UC-PLUGIN-05 | 禁用插件 | P1 | 用户 |
| UC-PLUGIN-06 | 注册服务 | P0 | 插件系统 |
| UC-PLUGIN-07 | 注册UI Hook | P0 | 插件系统 |
| UC-PLUGIN-08 | 插件间通信 | P1 | 插件 |

---

## UC-PLUGIN-01: 系统启动加载插件

### 场景描述

应用程序启动时自动加载所有内置插件。

### 调用链

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. main() 启动应用程序                                            │
│    文件: lib/main.dart                                           │
│    步骤:                                                          │
│    - 确保 Flutter 绑定初始化                                       │
│    - 初始化 SettingsService                                      │
│    - 初始化 ThemeService                                         │
│    - 运行 NodeGraphNotebookApp                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. NodeGraphNotebookAppState._initializeCore()                    │
│    文件: lib/app.dart                                            │
│    初始化核心组件:                                                 │
│    - SharedPreferences                                           │
│    - StoragePathService                                          │
│    - NodeRepository & GraphRepository                            │
│    - CommandBus (带中间件)                                        │
│    - TaskRegistry, SettingsRegistry, ThemeRegistry               │
│    - ExecutionEngine                                             │
│    - ServiceRegistry (带核心依赖)                                  │
│    - AdjacencyList                                               │
│    - QueryBus                                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. 创建 PluginManager                                             │
│    依赖注入:                                                       │
│    - CommandBus                                                  │
│    - NodeRepository                                              │
│    - GraphRepository                                             │
│    - ServiceRegistry                                             │
│    - ExecutionEngine                                             │
│    - TaskRegistry                                                │
│    - SettingsRegistry                                            │
│    - ThemeRegistry                                               │
│    - StoragePathService                                          │
│    - HookRegistry                                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. _loadPlugins() → FutureBuilder 等待加载                        │
│    文件: lib/app.dart                                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. _initializeStandardHookPoints()                                │
│    注册标准Hook点:                                                 │
│    - main.toolbar (主工具栏)                                      │
│    - graph.toolbar (图工具栏)                                     │
│    - context_menu.node (节点右键菜单)                              │
│    - context_menu.graph (图右键菜单)                               │
│    - sidebar.bottom (侧边栏底部)                                   │
│    - status.bar (状态栏)                                          │
│    - help (帮助)                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. BuiltinPluginLoader.loadAllBuiltinPlugins()                    │
│    文件: lib/core/plugin/builtin_plugin_loader.dart              │
│    内置插件列表:                                                   │
│    - GraphPlugin (图管理)                                         │
│    - AIPlugin (AI集成)                                           │
│    - LuaPlugin (Lua脚本)                                         │
│    - ConverterPlugin (导入导出)                                   │
│    - SearchPlugin (搜索)                                         │
│    - EditorPlugin (编辑器)                                       │
│    - FolderPlugin (文件夹)                                       │
│    - LayoutPlugin (布局)                                         │
│    - I18nPlugin (国际化)                                         │
│    - SettingsPlugin (设置)                                       │
│    - DataRecoveryPlugin (数据恢复)                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. PluginManager.loadPlugin(pluginId) for each plugin             │
│    每个插件的加载流程:                                              │
│    7.1 _validateAndDiscoverPlugin() - 验证插件                    │
│    7.2 _createPluginWrapper() - 创建包装器                        │
│    7.3 _registerPluginWrapper() - 注册                            │
│    7.4 _initializePlugin() - 初始化                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. _initializePlugin() 详细流程                                   │
│    8.1 _registerPluginServices()                                 │
│        └── plugin.registerServices() → ServiceRegistry           │
│                                                                  │
│    8.2 _callPluginOnLoad()                                       │
│        └── plugin.onLoad(context)                                │
│            ├── 注册命令处理器 (commandBus.registerHandlers)      │
│            ├── 注册任务类型 (taskRegistry.registerTaskType)      │
│            └── 初始化插件特定服务                                  │
│                                                                  │
│    8.3 _registerPluginAPIs()                                     │
│        └── plugin.exportAPIs() → APIRegistry                     │
│                                                                  │
│    8.4 _registerPluginHookPoints()                               │
│        └── plugin.registerHookPoints() → HookRegistry            │
│                                                                  │
│    8.5 _registerPluginUIHooks()                                  │
│        └── plugin.registerHooks() → HookRegistry                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 9. DynamicProviderWidget 构建 Provider 树                         │
│    文件: lib/core/plugin/dynamic_provider_widget.dart            │
│    Provider 顺序:                                                  │
│    - coreProviders: 核心依赖 (不重建)                              │
│    - serviceProviders: 插件服务 (可重建)                           │
│    - blocProviders: 插件 BLoC (可重建)                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 10. HomePage 显示，应用启动完成                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## UC-PLUGIN-02: 加载单个插件

### 场景描述

动态加载单个插件（热加载或从市场安装后加载）。

### 调用链

```
用户触发加载插件 / 系统自动加载
    │
    ▼
PluginManager.loadPlugin(pluginId)
    │
    ├── 1. _validateAndDiscoverPlugin(pluginId)
    │   ├── 检查是否已加载 → 已加载则抛出 PluginAlreadyExistsException
    │   ├── PluginDiscoverer.discoverPlugin(pluginId)
    │   └── 版本兼容性检查 → 不兼容则抛出 PluginVersionException
    │
    ├── 2. _createPluginWrapper(plugin, pluginId)
    │   ├── 创建 PluginContext (包含所有依赖)
    │   ├── 创建 PluginLifecycleManager
    │   └── 创建 PluginWrapper
    │
    ├── 3. _registerPluginWrapper(wrapper)
    │   ├── _validateAPIDependencies() - 验证API依赖
    │   └── _registry.register(wrapper)
    │
    └── 4. _initializePlugin(plugin, wrapper, context, pluginId)
        ├── 注册服务
        ├── 调用 onLoad
        ├── 注册API
        ├── 注册Hook点
        └── 注册UI Hooks
    │
    ▼
PluginLoadedEvent → CommandBus.publishEvent()
    │
    ▼
UI 更新 (新Hook点生效，新服务可用)
```

### 插件加载状态机

```
                   ┌─────────────┐
                   │  unloaded   │
                   └──────┬──────┘
                          │ loadPlugin()
                          ▼
                   ┌─────────────┐
              ┌───▶│   loaded    │◀────────────────────┐
              │    └──────┬──────┘                     │
              │           │ enablePlugin()             │ disablePlugin()
              │           ▼                            │
              │    ┌─────────────┐                     │
              │    │  enabled    │─────────────────────┘
              │    └──────┬──────┘
              │           │ unloadPlugin()
              │           ▼
              │    ┌─────────────┐
              └────│  unloaded   │
                   └─────────────┘

注意: 加载失败会回滚到 unloaded 状态并清理资源
```

---

## UC-PLUGIN-03: 卸载插件

### 场景描述

从系统中完全移除插件及其所有资源。

### 调用链

```
用户触发卸载插件
    │
    ▼
PluginManager.unloadPlugin(pluginId)
    │
    ├── 查找插件 → 未找到则抛出 PluginNotFoundException
    │
    ├── 如果插件已启用 → 先 disablePlugin()
    │
    ├── 清理资源:
    │   ├── _unregisterPluginHookPoints() - 注销Hook点
    │   ├── _disposePluginHooks() - 销毁Hooks
    │   ├── _apiRegistry.unregisterPluginAPIs() - 注销API
    │   └── _serviceRegistry.unregisterPluginServices() - 注销服务
    │
    ├── 调用 plugin.onUnload()
    │   └── lifecycle.transitionTo(PluginState.unloaded)
    │
    └── _registry.unregister(pluginId) - 从注册表移除
    │
    ▼
插件完全移除，UI更新
```

---

## UC-PLUGIN-04: 启用插件

### 场景描述

启用已加载但禁用的插件。

### 调用链

```
用户触发启用插件
    │
    ▼
PluginManager.enablePlugin(pluginId)
    │
    ├── 查找插件 → 未找到则抛出 PluginNotFoundException
    ├── 检查是否已启用 → 已启用则跳过
    │
    ├── _ensureDependencies(wrapper)
    │   └── 递归启用所有依赖插件
    │       ├── 检查依赖插件是否存在
    │       └── 如果依赖未启用 → 递归 enablePlugin()
    │
    ├── 调用 plugin.onEnable()
    │   └── lifecycle.transitionTo(PluginState.enabled)
    │
    └── _enablePluginHooks(wrapper)
        └── 启用所有UI Hooks
    │
    ▼
PluginEnabledEvent → UI 更新
```

### 依赖检查流程

```
Plugin A (依赖: B, C)
    │
    ├── 检查依赖 B
    │   ├── B 已存在且启用 → ✓
    │   └── B 未启用 → 递归 enablePlugin(B)
    │       └── B 的依赖检查...
    │
    ├── 检查依赖 C
    │   ├── C 已存在且启用 → ✓
    │   └── C 不存在 → ✗ MissingDependencyException
    │
    └── 所有依赖满足 → 启用 A
```

---

## UC-PLUGIN-05: 禁用插件

### 场景描述

禁用插件但不从系统中移除（保留加载状态）。

### 调用链

```
用户触发禁用插件
    │
    ▼
PluginManager.disablePlugin(pluginId)
    │
    ├── 查找插件 → 未找到则抛出 PluginNotFoundException
    ├── 检查是否已禁用 → 已禁用则跳过
    │
    ├── _disablePluginHooks(wrapper)
    │   └── 禁用所有UI Hooks
    │
    └── 调用 plugin.onDisable()
        └── lifecycle.transitionTo(PluginState.disabled)
    │
    ▼
插件禁用，Hook不渲染，但服务/API仍可用
```

---

## UC-PLUGIN-06: 注册服务

### 场景描述

插件向系统注册服务，供其他插件和组件使用。

### 调用链

```
Plugin.registerServices()
    │
    ▼
返回 List<ServiceBinding>
    │
    └── 示例:
        ├── NodeServiceBinding()
        ├── GraphServiceBinding()
        ├── AIServiceBinding()
        └── LuaScriptServiceBinding()
    │
    ▼
ServiceRegistry.registerServices(pluginId, bindings)
    │
    ├── 遍历 bindings
    ├── 对于每个 binding:
    │   ├── binding.createService(pluginContext) - 创建服务实例
    │   └── _services[pluginId][serviceType] = service - 存储
    │
    └── 触发 notifyListeners() → 通知依赖更新
    │
    ▼
其他插件可通过 context.read<ServiceType>() 获取服务
```

### 服务依赖注入

```
ServiceRegistry
    │
    ├── 核心依赖 (Core Dependencies)
    │   ├── NodeRepository
    │   ├── GraphRepository
    │   ├── CommandBus
    │   ├── QueryBus
    │   ├── ExecutionEngine
    │   └── ...
    │
    └── 插件服务 (Plugin Services)
        ├── NodeService (GraphPlugin)
        ├── GraphService (GraphPlugin)
        ├── AIService (AIPlugin)
        ├── LuaScriptService (LuaPlugin)
        └── ...

使用方式:
  final nodeService = context.read<NodeService>();
  final aiService = context.read<AIService>();
```

---

## UC-PLUGIN-07: 注册UI Hook

### 场景描述

插件注册UI Hook到系统的扩展点。

### 调用链

```
Plugin.registerHooks()
    │
    ▼
返回 List<HookFactory>
    │
    └── 示例 (GraphPlugin):
        ├── GraphNodesToolbarHook.new
        ├── RefreshGraphToolbarHook.new
        └── ToggleConnectionsToolbarHook.new
    │
    ▼
PluginManager._registerPluginHooks(wrapper)
    │
    ├── 遍历 factories
    ├── 对于每个 factory:
    │   ├── hook = factory() - 创建Hook实例
    │   ├── hookContext = BasicHookContext(...) - 创建上下文
    │   ├── hookRegistry.registerHook(hook, parentPlugin: wrapper)
    │   ├── hook.onInit(hookContext) - 初始化
    │   └── 如果插件已启用 → _enablePluginHooks()
    │
    └── 添加到 _pluginHooks[pluginId] 跟踪列表
    │
    ▼
Hook 渲染流程:

HookRegistry.getHookWrappers(hookPointId)
    │
    ├── 按优先级排序 (priority)
    ├── 过滤禁用的Hook (默认)
    └── 返回 HookWrapper 列表
    │
    ▼
DynamicHookRenderer 渲染每个 Hook
    │
    └── 调用 hook.build(context) → 返回 Widget
```

### Hook 生命周期

```
                   ┌─────────────┐
                   │  disposed   │
                   └──────▲──────┘
                          │ onDispose()
                          │
                   ┌─────────────┐
              ┌───▶│  disabled   │◀────────────────────┐
              │    └──────┬──────┘                     │
              │           │ onEnable()                 │ onDisable()
              │           ▼                            │
              │    ┌─────────────┐                     │
              │    │  enabled    │─────────────────────┘
              │    └──────▲──────┘
              │           │ onInit()
              │           │
              │    ┌─────────────┐
              └────│ initialized │
                   └─────────────┘
```

---

## UC-PLUGIN-08: 插件间通信

### 场景描述

插件之间通过API或事件进行通信。

### 方式一: API Registry

```
Plugin A (导出API)                  Plugin B (使用API)
    │                                  │
    ├── exportAPIs()                   │
    │   └── {                          │
    │       'graphApi': graphService   │
    │   }                              │
    │                                  │
    ▼                                  │
APIRegistry.registerAPI(               │
  pluginId: 'graph',                   │
  apiName: 'graphApi',                 │
  api: graphService                    │
)                                      │
                                       │
                                       ├── 获取API
                                       │   APIRegistry.getAPI('graph', 'graphApi')
                                       │
                                       ▼
                                       graphService.getNodes()
```

### 方式二: 事件流

```
Plugin A (发布事件)                  Plugin B (订阅事件)
    │                                  │
    ├── CommandBus.publishEvent()      │
    │   └── NodeCreatedEvent           │
    │                                  │
    ▼                                  │
CommandBus.eventStream ─────────────────▶ BLoC 订阅
    │                                      │
    │                                      ├── on<Event>(handler)
    │                                      └── emit(newState)
    │
    ▼
其他订阅者也收到事件
```

### 方式三: Service Registry

```
Plugin A (注册服务)                  Plugin B (使用服务)
    │                                  │
    ├── registerServices()             │
    │   └── [AIServiceBinding()]       │
    │                                  │
    ▼                                  │
ServiceRegistry.register()             │
    │                                  │
    │                                  ├── context.read<AIService>()
    │                                  │
    ▼                                  ▼
服务已注册可用                         直接使用服务
```

---

## 插件元数据

```dart
PluginMetadata {
  id: String;              // 插件唯一标识
  name: String;            // 显示名称
  version: String;         // 版本号 (semver)
  description: String;     // 描述
  author: String;          // 作者
  enabledByDefault: bool;  // 是否默认启用
  dependencies: List<String>;      // 依赖的插件ID列表
  apiDependencies: List<APIDependency>; // 依赖的API列表
}
```

---

## 时序图: 插件加载流程

```
main()           App            PluginManager    PluginDiscoverer    Plugin    ServiceRegistry   HookRegistry
 │               │                   │                  │              │            │               │
 │──runApp()─────▶│                   │                  │              │            │               │
 │               │──_initializeCore() │                  │              │            │               │
 │               │                   │                  │              │            │               │
 │               │──创建PluginManager─▶│                  │              │            │               │
 │               │                   │                  │              │            │               │
 │               │──_loadPlugins()───▶│                  │              │            │               │
 │               │                   │──_initializeStandardHookPoints()│            │               │
 │               │                   │                  │              │            │               │
 │               │                   │──loadPlugin()────▶│              │            │               │
 │               │                   │                  │──discover()──▶│            │               │
 │               │                   │                  │◀──Plugin─────│            │               │
 │               │                   │                  │              │            │               │
 │               │                   │──创建Wrapper─────────────────────▶│            │               │
 │               │                   │                  │              │            │               │
 │               │                   │──registerServices()──────────────────────────▶│               │
 │               │                   │                  │              │            │               │
 │               │                   │──onLoad()───────────────────────▶│            │               │
 │               │                   │                  │              │            │               │
 │               │                   │──registerAPIs()──────────────────────────────▶│               │
 │               │                   │                  │              │            │               │
 │               │                   │──registerHooks()─────────────────────────────────────────────▶│
 │               │                   │                  │              │            │               │
 │               │◀──完成────────────│                  │              │            │               │
 │               │                   │                  │              │            │               │
 │               │──build UI()──────▶│                  │              │            │               │
 │               │                   │──generateBlocProviders()        │            │               │
 │               │                   │                  │              │            │               │
 │◀──显示UI──────│                   │                  │              │            │               │
```

---

## 扩展点

| 扩展点 | 说明 | 实现方式 |
|--------|------|----------|
| 新插件 | 添加新插件 | 继承 Plugin 类 |
| 新服务 | 插件提供服务 | 实现 ServiceBinding |
| 新Hook | 插入UI扩展点 | 实现 UIHookBase |
| 新Hook点 | 创建新扩展点 | registerHookPoints() |
| 新命令 | 插件命令处理器 | registerHandlers() |
| 新BLoC | 插件状态管理 | registerBlocs() |
