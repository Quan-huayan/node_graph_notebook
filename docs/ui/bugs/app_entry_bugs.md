# UI 入口模块 Bug 报告

**审查日期**: 2026-04-21  
**审查范围**: `lib/main.dart` 和 `lib/app.dart`

---

## Bug 1: FutureBuilder 的 future 在每次 build 时重新创建

**严重程度**: 严重 (功能性缺陷)

**位置**: [app.dart:514-516](file:///d:/Projects/node_graph_notebook/lib/app.dart#L514-L516)

**问题描述**:  
`FutureBuilder` 的 `future` 参数直接传入 `_loadPlugins(pluginManager)` 方法调用。由于 `build` 方法可能被 Flutter 框架多次调用，每次调用都会创建一个新的 `Future`，导致 `FutureBuilder` 重新执行异步操作。这是 Flutter 中一个经典且严重的反模式。

**问题代码**:
```dart
return FutureBuilder<void>(
  future: _loadPlugins(pluginManager),  // 每次 build 都创建新 Future
  builder: (context, snapshot) {
    // ...
  },
);
```

**影响**:  
- 每次组件重建都会重新加载所有插件
- `FutureBuilder` 的 `ConnectionState` 会反复重置为 `ConnectionState.waiting`
- 用户可能看到加载界面反复闪烁
- 与 Bug 2 和 Bug 6 联动，造成更严重的连锁问题

**修复建议**:  
将 Future 缓存为状态变量，确保只创建一次：
```dart
late Future<void> _pluginsLoadedFuture;

// 在 _isInitialized = true 之后：
_pluginsLoadedFuture = _loadPlugins(pluginManager);

// 在 build 中：
return FutureBuilder<void>(
  future: _pluginsLoadedFuture,  // 使用缓存的 Future
  builder: (context, snapshot) {
    // ...
  },
);
```

---

## Bug 2: PluginManager 在 build 方法中重复创建

**严重程度**: 严重 (功能性缺陷 + 资源浪费)

**位置**: [app.dart:499-511](file:///d:/Projects/node_graph_notebook/lib/app.dart#L499-L511)

**问题描述**:  
`PluginManager` 实例在 `build` 方法内部创建。`build` 方法可能被 Flutter 框架多次调用（例如由于父组件重建、`setState` 触发等），每次都会创建一个新的 `PluginManager` 实例。新实例与旧实例状态完全独立，导致插件系统状态不一致。

**问题代码**:
```dart
@override
Widget build(BuildContext context) {
  // ...
  final pluginManager = PluginManager(  // 每次 build 都创建新实例！
    commandBus: _commandBus,
    nodeRepository: _nodeRepository,
    graphRepository: _graphRepository,
    serviceRegistry: _serviceRegistry,
    executionEngine: _executionEngine,
    taskRegistry: _taskRegistry,
    settingsRegistry: _settingsRegistry,
    themeRegistry: _themeRegistry,
    sharedPreferencesAsync: _sharedPreferencesAsync,
    storagePathService: _storagePathService,
    hookRegistry: hookRegistry,
  );
  // ...
}
```

**影响**:  
- 每次 rebuild 创建新的 PluginManager，旧实例中的插件状态丢失
- 新的 PluginManager 没有已加载的插件，导致插件功能间歇性失效
- 与 Bug 1 联动：新 PluginManager 触发重新加载插件，而旧 PluginManager 的插件仍在运行
- 资源浪费：大量对象被创建后立即丢弃

**修复建议**:  
将 `PluginManager` 提升为状态变量，在 `_initializeCore` 中创建一次：
```dart
late PluginManager _pluginManager;

// 在 _initializeCore 末尾：
_pluginManager = PluginManager(
  commandBus: _commandBus,
  nodeRepository: _nodeRepository,
  // ...
);

// 在 build 中直接使用 _pluginManager
```

---

## Bug 3: _initializeStandardHookPoints 重复调用会抛出异常

**严重程度**: 高 (运行时崩溃)

**位置**: [app.dart:377-444](file:///d:/Projects/node_graph_notebook/lib/app.dart#L377-L444) 与 [hook_point_registry.dart:147-152](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_point_registry.dart#L147-L152)

**问题描述**:  
`_initializeStandardHookPoints` 方法通过 `hookRegistry..registerHookPoint(...)` 注册 Hook 点。`HookPointRegistry.registerPoint` 在检测到重复 ID 时会抛出 `ArgumentError`。由于 Bug 1 导致 `_loadPlugins` 可能被多次调用，而 `_loadPlugins` 内部调用了 `_initializeStandardHookPoints`，第二次调用时必然抛出异常。

**问题代码**:
```dart
// app.dart - _loadPlugins 每次都调用 _initializeStandardHookPoints
Future<void> _loadPlugins(PluginManager pluginManager) async {
  _initializeStandardHookPoints();  // 重复调用会崩溃！
  // ...
}

// hook_point_registry.dart - 重复注册会抛异常
void registerPoint(HookPointDefinition point) {
  if (_points.containsKey(point.id)) {
    throw ArgumentError('Hook point already registered: ${point.id}');
  }
  _points[point.id] = point;
}
```

**影响**:  
- 当 Bug 1 触发重复加载时，应用会因 `ArgumentError` 崩溃
- 错误被 `_loadPlugins` 的 catch 块捕获后，`FutureBuilder` 显示错误状态
- 用户可能看到插件加载失败界面，但实际原因是 Hook 点重复注册

**修复建议**:  
方案1 - 添加幂等性检查：
```dart
void _initializeStandardHookPoints() {
  final existingPoints = hookRegistry.getAllHookPoints();
  if (existingPoints.any((p) => p.id == 'main.toolbar')) {
    return;  // 已初始化，跳过
  }
  // ... 注册 Hook 点
}
```

方案2 - 在 `HookPointRegistry.registerPoint` 中改为静默跳过而非抛出异常：
```dart
void registerPoint(HookPointDefinition point) {
  if (_points.containsKey(point.id)) {
    return;  // 已存在，跳过
  }
  _points[point.id] = point;
}
```

---

## Bug 4: SearchIndexMaterializedView 从未被初始化

**严重程度**: 高 (搜索功能失效)

**位置**: [app.dart:277](file:///d:/Projects/node_graph_notebook/lib/app.dart#L277)

**问题描述**:  
在 `_createQueryBus` 方法中创建了 `SearchIndexMaterializedView` 实例，但从未调用 `buildIndex()` 或 `addOrUpdateNode()` 来填充索引数据。该类是一个被动数据结构，不会自动从仓库加载数据。这意味着所有依赖该视图的查询处理器（`FastSearchQueryHandler`、`GetPopularTokensQueryHandler`）将始终返回空结果。

**问题代码**:
```dart
QueryBus _createQueryBus(AdjacencyList adjacencyList) {
  // ...
  final searchIndexView = SearchIndexMaterializedView();  // 空视图，从未填充！
  
  // ... 使用空视图创建查询处理器
  ..registerHandler<List<NodeReadModel>, FastSearchQuery>(
    FastSearchQuery,
    () => FastSearchQueryHandler(searchIndexView, nodeRepository),  // 永远返回空
  )
  ..registerHandler<List<String>, GetPopularTokensQuery>(
    GetPopularTokensQuery,
    () => GetPopularTokensQueryHandler(searchIndexView),  // 永远返回空
  );
}
```

**影响**:  
- `FastSearchQuery` 始终返回空列表，快速搜索功能完全失效
- `GetPopularTokensQuery` 始终返回空列表，热门标签功能完全失效
- 用户无法通过搜索索引查找节点
- 与 `AdjacencyList` 的初始化形成对比：邻接表在创建后正确调用了 `buildFromNodes(allNodes)`，但搜索索引没有

**修复建议**:  
在创建 `SearchIndexMaterializedView` 后，使用已有节点数据构建索引：
```dart
final searchIndexView = SearchIndexMaterializedView();
final allNodes = await _nodeRepository.queryAll();
searchIndexView.buildIndex(allNodes);
```

同时，需要订阅 `CommandBus` 的事件流以保持索引同步：
```dart
_commandBus.events.whereType<NodeCreatedEvent>().listen((e) {
  final node = await _nodeRepository.load(e.nodeId);
  if (node != null) searchIndexView.addOrUpdateNode(node);
});
_commandBus.events.whereType<NodeUpdatedEvent>().listen((e) {
  final node = await _nodeRepository.load(e.nodeId);
  if (node != null) searchIndexView.addOrUpdateNode(node);
});
_commandBus.events.whereType<NodeDeletedEvent>().listen((e) {
  searchIndexView.removeNode(e.nodeId);
});
```

---

## Bug 5: SharedPreferencesAsync 创建了两个不同的实例

**严重程度**: 中 (数据不一致)

**位置**: [app.dart:100](file:///d:/Projects/node_graph_notebook/lib/app.dart#L100) 与 [app.dart:563-565](file:///d:/Projects/node_graph_notebook/lib/app.dart#L563-L565)

**问题描述**:  
`SharedPreferencesAsync` 在两个不同的地方被创建：
1. `_initializeCore` 中创建了 `_sharedPreferencesAsync = SharedPreferencesAsync()`，并注册到 `ServiceRegistry`
2. `coreProviders` 中又通过 `Provider<SharedPreferencesAsync>(create: (_) => SharedPreferencesAsync())` 创建了一个新实例

两个实例指向不同的对象。通过 `ServiceRegistry` 获取的实例和通过 `Provider` 获取的实例是不同的，可能导致数据读写不一致。

**问题代码**:
```dart
// 第一次创建（_initializeCore 中，第 100 行）
_sharedPreferencesAsync = SharedPreferencesAsync();

// 第二次创建（coreProviders 中，第 563-565 行）
Provider<SharedPreferencesAsync>(
  create: (_) => SharedPreferencesAsync(),  // 新实例！应该用 .value
),
```

**影响**:  
- 通过 `ServiceRegistry` 和通过 `Provider` 获取的 `SharedPreferencesAsync` 是不同实例
- 虽然底层可能共享同一存储，但缓存状态可能不一致
- 插件通过 `ServiceRegistry` 获取的实例与 UI 通过 `Provider` 获取的实例不同
- 违反了单一数据源原则

**修复建议**:  
使用 `Provider.value` 传入已创建的实例：
```dart
Provider<SharedPreferencesAsync>.value(
  value: _sharedPreferencesAsync,
),
```

---

## Bug 6: 并发初始化无保护

**严重程度**: 中 (竞态条件)

**位置**: [app.dart:662](file:///d:/Projects/node_graph_notebook/lib/app.dart#L662)

**问题描述**:  
错误恢复界面的"Retry"按钮直接调用 `_initializeCore()`，没有任何并发保护。如果用户快速多次点击 Retry，或者在初始化尚未完成时再次点击，会导致多个初始化流程并发执行，产生竞态条件。

**问题代码**:
```dart
ElevatedButton(
  onPressed: _initializeCore,  // 无防重复点击保护
  child: const Text('Retry'),
),
```

**影响**:  
- 多个初始化流程并发执行，可能导致文件系统冲突
- `setState` 被多次调用，状态可能被覆盖
- `FileSystemNodeRepository.init()` 和 `FileSystemGraphRepository.init()` 可能并发创建目录，导致竞态条件
- 资源浪费

**修复建议**:  
添加初始化锁：
```dart
bool _isInitializing = false;

Future<void> _initializeCore() async {
  if (_isInitializing) return;
  _isInitializing = true;
  try {
    // ... 原有初始化逻辑
  } catch (e, st) {
    // ... 错误处理
  } finally {
    _isInitializing = false;
  }
}
```

同时在 UI 层禁用按钮：
```dart
ElevatedButton(
  onPressed: _isInitializing ? null : _initializeCore,
  child: const Text('Retry'),
),
```

---

## Bug 7: 缺少 dispose 方法导致资源泄漏

**严重程度**: 中 (资源泄漏)

**位置**: [app.dart:68-669](file:///d:/Projects/node_graph_notebook/lib/core/plugin/plugin_manager.dart) (整个 `_NodeGraphNotebookAppState` 类)

**问题描述**:  
`_NodeGraphNotebookAppState` 类没有重写 `dispose` 方法。该类创建了大量需要清理的资源，包括 `CommandBus`、`QueryBus`、`ExecutionEngine`、`UILayoutService`、`PluginManager` 等，这些资源在组件销毁时不会被正确释放。

**问题代码**:
```dart
class _NodeGraphNotebookAppState extends State<NodeGraphNotebookApp> {
  late NodeRepository _nodeRepository;
  late CommandBus _commandBus;
  late QueryBus _queryBus;
  late ExecutionEngine _executionEngine;
  late UILayoutService _layoutService;
  // ... 更多资源

  // 缺少 dispose 方法！
  // @override
  // void dispose() { ... }
}
```

**影响**:  
- `ExecutionEngine` 中的任务调度器可能继续运行
- `UILayoutService` 中的事件订阅不会被取消
- `CommandBus` 和 `QueryBus` 中的事件流不会被关闭
- `PluginManager` 中的插件资源不会被释放
- 内存泄漏，特别是在热重载时更明显

**修复建议**:  
添加 `dispose` 方法：
```dart
@override
void dispose() {
  _executionEngine.dispose();
  _layoutService.dispose();
  _commandBus.dispose();
  _queryBus.dispose();
  // 释放其他资源
  super.dispose();
}
```

---

## Bug 8: _buildErrorUI 中 Theme.of(context) 在 MaterialApp 外部使用

**严重程度**: 低 (显示异常)

**位置**: [app.dart:653](file:///d:/Projects/node_graph_notebook/lib/app.dart#L653)

**问题描述**:  
`_buildErrorUI` 方法在 `build` 方法中 `_initError != null` 时被调用，此时还没有 `MaterialApp` 作为祖先。方法内部使用了 `Theme.of(context)`，但 `context` 是 State 的 context，不在任何 `MaterialApp` 下，因此会获取到默认的 ThemeData 而非应用自定义主题。

**问题代码**:
```dart
Widget _buildErrorUI() => MaterialApp(
  home: Scaffold(
    body: Center(
      child: Column(
        children: [
          Text(
            'Initialization Failed',
            style: Theme.of(context).textTheme.headlineMedium,  // context 不在 MaterialApp 下
          ),
          // ...
        ],
      ),
    ),
  ),
);
```

**影响**:  
- 错误界面的文字样式使用默认主题而非应用主题
- 视觉上可能与应用其他界面不一致
- 功能上不会崩溃，但用户体验不佳

**修复建议**:  
在 `_buildErrorUI` 创建的 `MaterialApp` 内部使用 Builder 获取正确的 context：
```dart
Widget _buildErrorUI() => MaterialApp(
  theme: AppTheme.getMaterialTheme(AppTheme.defaultTheme, Brightness.light),
  darkTheme: AppTheme.getMaterialTheme(AppTheme.defaultTheme, Brightness.dark),
  home: Scaffold(
    body: Builder(
      builder: (innerContext) => Center(
        child: Column(
          children: [
            Text(
              'Initialization Failed',
              style: Theme.of(innerContext).textTheme.headlineMedium,
            ),
            // ...
          ],
        ),
      ),
    ),
  ),
);
```

---

## Bug 关联分析

以上 Bug 存在明显的连锁关系：

```
Bug 1 (FutureBuilder future 重建)
  ├── 触发 Bug 2 (PluginManager 重复创建)
  ├── 触发 Bug 6 (_initializeStandardHookPoints 重复调用 → ArgumentError 崩溃)
  └── 间接导致 Bug 4 (每次重建创建新的空 SearchIndexMaterializedView)

Bug 5 (SharedPreferencesAsync 双实例) ← 独立问题
Bug 6 (并发初始化) ← 独立问题
Bug 7 (缺少 dispose) ← 独立问题
Bug 8 (Theme.of context) ← 独立问题
```

**核心修复优先级**: Bug 1 + Bug 2 是根因，修复后 Bug 6 的触发条件消除。Bug 4 是独立的高优先级功能缺陷，应优先修复。
