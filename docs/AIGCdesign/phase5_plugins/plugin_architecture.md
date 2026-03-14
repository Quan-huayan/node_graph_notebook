# 插件架构设计文档

## 1. 概述

### 1.1 职责
插件架构是系统的核心扩展机制，负责：
- 插件的发现和加载
- 插件生命周期管理
- 插件沙箱隔离
- 插件依赖解析
- 插件版本兼容性管理
- 插件热加载/热卸载

### 1.2 目标
- **安全性**: 插件隔离，防止恶意代码破坏系统
- **可扩展性**: 支持动态加载第三方插件
- **稳定性**: 插件崩溃不影响主系统
- **性能**: 插件加载延迟 < 100ms，插件调用开销 < 1ms
- **易用性**: 简单的插件开发 API

### 1.3 关键挑战
- **沙箱隔离**: 在 Dart/Flutter 环境下实现代码隔离
- **依赖管理**: 处理插件间依赖和版本冲突
- **API 兼容**: 保证插件 API 向后兼容
- **资源管理**: 插件资源的正确释放
- **通信机制**: 插件与主系统的高效通信

## 2. 架构设计

### 2.1 组件结构

```
PluginSystem
    │
    ├── PluginRegistry (插件注册表)
    │   ├── discoveredPlugins (已发现插件)
    │   ├── loadedPlugins (已加载插件)
    │   └── dependencyGraph (依赖图)
    │
    ├── PluginLoader (插件加载器)
    │   ├── loadPlugin()
    │   ├── unloadPlugin()
    │   └── reloadPlugin()
    │
    ├── PluginSandbox (插件沙箱)
    │   ├── Isolate边界
    │   ├── 消息传递通道
    │   └── 资源限制
    │
    ├── PluginLifecycle (生命周期管理)
    │   ├── onLoad()
    │   ├── onEnable()
    │   ├── onDisable()
    │   └── onUnload()
    │
    └── PluginCommunication (通信层)
        ├── HostChannel (主系统→插件)
        └── PluginChannel (插件→主系统)
```

### 2.2 接口定义

#### Plugin 元数据

```dart
/// 插件元数据
class PluginMetadata {
  /// 插件唯一标识符
  final String id;

  /// 插件名称
  final String name;

  /// 插件版本
  final String version;

  /// 插件描述
  final String description;

  /// 插件作者
  final String author;

  /// 主应用版本要求
  final String minAppVersion;

  /// 依赖的其他插件
  final List<PluginDependency> dependencies;

  /// 插件入口点路径
  final String entryPoint;

  /// 插件类型
  final PluginType type;

  /// 插件权限声明
  final List<PluginPermission> permissions;

  PluginMetadata({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.author,
    required this.minAppVersion,
    required this.entryPoint,
    required this.type,
    this.dependencies = const [],
    this.permissions = const [],
  });

  /// 验证版本兼容性
  bool isCompatibleWith(String appVersion) {
    // TODO: 实现版本比较逻辑
    return true;
  }
}

/// 插件依赖
class PluginDependency {
  final String pluginId;
  final String minVersion;
  final String? maxVersion;

  PluginDependency({
    required this.pluginId,
    required this.minVersion,
    this.maxVersion,
  });

  /// 检查版本是否满足要求
  bool satisfies(String version) {
    // TODO: 实现版本范围检查
    return true;
  }
}

/// 插件类型
enum PluginType {
  /// UI 扩展插件
  ui,

  /// 数据处理插件
  data,

  /// 导入导出插件
  converter,

  /// 渲染插件
  renderer,

  /// 命令插件
  command,

  /// 查询插件
  query,
}

/// 插件权限
enum PluginPermission {
  /// 读取节点数据
  readNodes,

  /// 写入节点数据
  writeNodes,

  /// 读取图数据
  readGraphs,

  /// 写入图数据
  writeGraphs,

  /// 访问文件系统
  accessFileSystem,

  /// 网络访问
  networkAccess,

  /// 显示对话框
  showDialog,

  /// 修改 UI
  modifyUI,
}
```

#### Plugin 接口

```dart
/// 插件基类
abstract class Plugin {
  /// 插件元数据
  PluginMetadata get metadata;

  /// 插件初始化
  ///
  /// [context] - 插件上下文，提供与主系统通信的 API
  Future<void> onLoad(PluginContext context);

  /// 插件启用
  Future<void> onEnable();

  /// 插件禁用
  Future<void> onDisable();

  /// 插件卸载
  Future<void> onUnload();

  /// 插件配置变更
  Future<void> onConfigChanged(Map<String, dynamic> config);
}

/// 插件上下文
class PluginContext {
  /// 插件 ID
  final String pluginId;

  /// 插件配置
  final Map<String, dynamic> config;

  /// 主系统 API 提供者
  final HostAPIProvider hostAPI;

  /// 日志记录器
  final PluginLogger logger;

  /// 事件总线
  final PluginEventBus eventBus;

  PluginContext({
    required this.pluginId,
    required this.config,
    required this.hostAPI,
    required this.logger,
    required this.eventBus,
  });

  /// 获取插件数据目录
  String getDataDir() {
    return '$appDataDir/plugins/$pluginId';
  }

  /// 获取插件缓存目录
  String getCacheDir() {
    return '$cacheDir/plugins/$pluginId';
  }
}

/// 主系统 API 提供者
class HostAPIProvider {
  /// Command Bus
  final ICommandBus commandBus;

  /// Query Bus
  final IQueryBus queryBus;

  /// 存储 API
  final StorageAPI storage;

  /// UI API
  final UIAPI ui;

  HostAPIProvider({
    required this.commandBus,
    required this.queryBus,
    required this.storage,
    required this.ui,
  });
}

/// 存储 API（受限）
class StorageAPI {
  /// 读取节点
  Future<Node?> getNode(String id) async {
    // 权限检查
    if (!_hasPermission(PluginPermission.readNodes)) {
      throw PluginPermissionError('缺少读取节点权限');
    }
    // 实现...
  }

  /// 写入节点
  Future<void> saveNode(Node node) async {
    // 权限检查
    if (!_hasPermission(PluginPermission.writeNodes)) {
      throw PluginPermissionError('缺少写入节点权限');
    }
    // 通过 Command Bus 执行
  }

  bool _hasPermission(PluginPermission permission) {
    // 检查插件是否具有该权限
    return true;
  }
}

/// UI API（受限）
class UIAPI {
  /// 显示对话框
  Future<T?> showDialog<T>(DialogBuilder builder) async {
    // 权限检查
    // 实现...
  }

  /// 注册 UI Hook
  void registerHook(UIHook hook) {
    // 实现...
  }

  /// 注销 UI Hook
  void unregisterHook(UIHook hook) {
    // 实现...
  }
}

/// 插件日志记录器
class PluginLogger {
  final String pluginId;
  final Logger _logger;

  PluginLogger(this.pluginId) : _logger = Logger('Plugin[$pluginId]');

  void debug(String message) => _logger.d(message);
  void info(String message) => _logger.i(message);
  void warning(String message) => _logger.w(message);
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(message, error, stackTrace);
  }
}

/// 插件事件总线
class PluginEventBus {
  final StreamController<PluginEvent> _controller =
      StreamController.broadcast();

  /// 订阅事件
  StreamSubscription on<T extends PluginEvent>(
    void Function(T) callback,
  ) {
    return _controller.stream
        .where((event) => event is T)
        .map((event) => event as T)
        .listen(callback);
  }

  /// 发布事件
  void emit(PluginEvent event) {
    _controller.add(event);
  }
}

/// 插件事件基类
abstract class PluginEvent {
  final DateTime timestamp = DateTime.now();
}
```

#### PluginManager 接口

```dart
/// 插件管理器接口
abstract class IPluginManager {
  /// 发现插件
  Future<List<PluginMetadata>> discoverPlugins();

  /// 加载插件
  Future<void> loadPlugin(String pluginId);

  /// 卸载插件
  Future<void> unloadPlugin(String pluginId);

  /// 重载插件
  Future<void> reloadPlugin(String pluginId);

  /// 启用插件
  Future<void> enablePlugin(String pluginId);

  /// 禁用插件
  Future<void> disablePlugin(String pluginId);

  /// 获取已加载插件
  List<PluginMetadata> getLoadedPlugins();

  /// 获取插件状态
  PluginState getPluginState(String pluginId);

  /// 调用插件方法
  Future<dynamic> callPlugin(
    String pluginId,
    String method, [
    List<dynamic> args = const [],
  ]);
}

/// 插件状态
enum PluginState {
  /// 未加载
  unloaded,

  /// 已加载
  loaded,

  /// 已启用
  enabled,

  /// 已禁用
  disabled,

  /// 错误状态
  error,
}
```

### 2.3 沙箱设计

#### Isolate 隔离

```dart
/// 插件沙箱
class PluginSandbox {
  final PluginMetadata metadata;
  final ReceivePort _receivePort = ReceivePort();
  final SendPort? _sendPort;
  Isolate? _isolate;

  PluginSandbox(this.metadata, {SendPort? sendPort})
      : _sendPort = sendPort;

  /// 启动沙箱
  Future<void> start() async {
    // 创建 Isolate 运行插件代码
    _isolate = await Isolate.spawn(
      _pluginEntry,
      _receivePort.sendPort,
      debugName: 'Plugin[${metadata.id}]',
    );

    // 监听来自插件的消息
    _receivePort.listen(_handlePluginMessage);
  }

  /// 停止沙箱
  Future<void> stop() async {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort.close();
  }

  /// 向插件发送消息
  Future<dynamic> send(String method, List<dynamic> args) async {
    final completer = Completer<dynamic>();

    // 发送请求到插件
    _sendPort?.send({
      'type': 'request',
      'method': method,
      'args': args,
      'requestId': completer,
    });

    return completer.future;
  }

  /// 处理来自插件的消息
  void _handlePluginMessage(dynamic message) {
    if (message is Map<String, dynamic>) {
      final type = message['type'];

      switch (type) {
        case 'response':
          final completer = message['requestId'] as Completer;
          final data = message['data'];
          completer.complete(data);
          break;

        case 'event':
          // 处理插件发布的事件
          break;

        case 'error':
          final completer = message['requestId'] as Completer;
          final error = message['error'];
          completer.completeError(error);
          break;
      }
    }
  }

  /// 插件入口函数（运行在独立 Isolate 中）
  static void _pluginEntry(SendPort sendPort) {
    // 初始化插件环境
    final receivePort = ReceivePort();

    // 向主系统注册
    sendPort.send({
      'type': 'register',
      'sendPort': receivePort.sendPort,
    });

    // 监听来自主系统的消息
    receivePort.listen((message) async {
      if (message is Map<String, dynamic>) {
        final requestId = message['requestId'];
        final method = message['method'];
        final args = message['args'] as List<dynamic>;

        try {
          // 调用插件方法
          final result = await _invokePluginMethod(method, args);

          // 返回结果
          sendPort.send({
            'type': 'response',
            'requestId': requestId,
            'data': result,
          });
        } catch (e) {
          // 返回错误
          sendPort.send({
            'type': 'error',
            'requestId': requestId,
            'error': e.toString(),
          });
        }
      }
    });
  }

  /// 调用插件方法
  static Future<dynamic> _invokePluginMethod(
    String method,
    List<dynamic> args,
  ) async {
    // 根据方法名调用对应的插件逻辑
    // 这里需要根据具体插件实现
    return null;
  }
}
```

## 3. 核心算法

### 3.1 插件依赖解析

**问题描述**:
给定一组插件及其依赖关系，确定正确的加载顺序，避免循环依赖。

**算法描述**:
使用拓扑排序算法解析插件依赖图。

**伪代码**:
```
function resolveDependencies(plugins):
    // 构建依赖图
    graph = DependencyGraph()
    for plugin in plugins:
        graph.addPlugin(plugin.id)
        for dep in plugin.dependencies:
            graph.addDependency(plugin.id, dep.pluginId)

    // 检测循环依赖
    if graph.hasCycle():
        throw CircularDependencyError()

    // 拓扑排序
    order = graph.topologicalSort()

    return order
```

**复杂度分析**:
- 时间复杂度: O(V + E)，V 为插件数，E 为依赖关系数
- 空间复杂度: O(V + E)

**实现**:

```dart
class DependencyResolver {
  /// 解析插件加载顺序
  List<String> resolve(List<PluginMetadata> plugins) {
    // 构建依赖图
    final graph = _buildDependencyGraph(plugins);

    // 检测循环依赖
    if (_hasCycle(graph)) {
      throw const PluginException('检测到循环依赖');
    }

    // 拓扑排序
    return _topologicalSort(graph);
  }

  /// 构建依赖图
  Map<String, Set<String>> _buildDependencyGraph(
    List<PluginMetadata> plugins,
  ) {
    final graph = <String, Set<String>>{};

    // 初始化所有节点
    for (final plugin in plugins) {
      graph[plugin.id] = {};
    }

    // 添加依赖边
    for (final plugin in plugins) {
      for (final dep in plugin.dependencies) {
        graph[plugin.id]!.add(dep.pluginId);
      }
    }

    return graph;
  }

  /// 检测循环依赖（DFS）
  bool _hasCycle(Map<String, Set<String>> graph) {
    final visited = <String>{};
    final recursionStack = <String>{};

    bool hasCycleNode(String node) {
      visited.add(node);
      recursionStack.add(node);

      for (final neighbor in graph[node]!) {
        if (!visited.contains(neighbor)) {
          if (hasCycleNode(neighbor)) {
            return true;
          }
        } else if (recursionStack.contains(neighbor)) {
          return true;
        }
      }

      recursionStack.remove(node);
      return false;
    }

    for (final node in graph.keys) {
      if (!visited.contains(node)) {
        if (hasCycleNode(node)) {
          return true;
        }
      }
    }

    return false;
  }

  /// 拓扑排序（Kahn 算法）
  List<String> _topologicalSort(Map<String, Set<String>> graph) {
    final inDegree = <String, int>{};
    final queue = <String>[];
    final result = <String>[];

    // 计算入度
    for (final node in graph.keys) {
      inDegree[node] = 0;
    }
    for (final node in graph.keys) {
      for (final neighbor in graph[node]!) {
        inDegree[neighbor] = (inDegree[neighbor] ?? 0) + 1;
      }
    }

    // 将入度为 0 的节点加入队列
    for (final entry in inDegree.entries) {
      if (entry.value == 0) {
        queue.add(entry.key);
      }
    }

    // 处理队列
    while (queue.isNotEmpty) {
      final node = queue.removeAt(0);
      result.add(node);

      for (final neighbor in graph[node]!) {
        inDegree[neighbor] = inDegree[neighbor]! - 1;
        if (inDegree[neighbor] == 0) {
          queue.add(neighbor);
        }
      }
    }

    return result;
  }
}
```

### 3.2 插件发现算法

**问题描述**:
如何自动发现可用的插件。

**算法描述**:
扫描指定目录，解析插件清单文件（plugin.yaml）。

**伪代码**:
```
function discoverPlugins(directories):
    plugins = []
    for dir in directories:
        manifestPath = dir / "plugin.yaml"
        if exists(manifestPath):
            metadata = parseManifest(manifestPath)
            plugins.add(metadata)
    return plugins
```

**复杂度分析**:
- 时间复杂度: O(n)，n 为扫描的文件数
- 空间复杂度: O(m)，m 为插件数

**实现**:

```dart
class PluginDiscoverer {
  /// 插件搜索路径
  static const List<String> _searchPaths = [
    'plugins',
    '$appDataDir/plugins',
    '/opt/nodegraph/plugins',
  ];

  /// 发现插件
  Future<List<PluginMetadata>> discover() async {
    final plugins = <PluginMetadata>[];

    for (final path in _searchPaths) {
      final dir = Directory(path);
      if (!await dir.exists()) continue;

      await for (final entity in dir.list()) {
        if (entity is Directory) {
          final metadata = await _tryLoadPlugin(entity);
          if (metadata != null) {
            plugins.add(metadata);
          }
        }
      }
    }

    return plugins;
  }

  /// 尝试加载插件元数据
  Future<PluginMetadata?> _tryLoadPlugin(Directory dir) async {
    final manifestFile = File('${dir.path}/plugin.yaml');
    if (!await manifestFile.exists()) {
      return null;
    }

    try {
      final yaml = await manifestFile.readAsString();
      final json = loadYaml(yaml);

      return PluginMetadata(
        id: json['id'] as String,
        name: json['name'] as String,
        version: json['version'] as String,
        description: json['description'] as String,
        author: json['author'] as String,
        minAppVersion: json['minAppVersion'] as String,
        entryPoint: json['entryPoint'] as String,
        type: _parsePluginType(json['type'] as String),
        dependencies: _parseDependencies(json['dependencies']),
        permissions: _parsePermissions(json['permissions']),
      );
    } catch (e) {
      // 跳过无效的插件
      return null;
    }
  }

  PluginType _parsePluginType(String type) {
    return PluginType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => PluginType.data,
    );
  }

  List<PluginDependency> _parseDependencies(dynamic deps) {
    if (deps == null) return [];

    return (deps as List).map((dep) {
      return PluginDependency(
        pluginId: dep['pluginId'] as String,
        minVersion: dep['minVersion'] as String,
        maxVersion: dep['maxVersion'] as String?,
      );
    }).toList();
  }

  List<PluginPermission> _parsePermissions(dynamic perms) {
    if (perms == null) return [];

    return (perms as List).map((perm) {
      return PluginPermission.values.firstWhere(
        (e) => e.name == perm,
      );
    }).toList();
  }
}
```

## 4. 生命周期管理

### 4.1 状态转换

```
     ┌──────────┐
     │ unloaded │
     └────┬─────┘
          │ loadPlugin()
          ▼
     ┌──────────┐
     │  loaded  │
     └────┬─────┘
          │ enablePlugin()
          ▼
     ┌──────────┐
◄───  │ enabled  │ ───►
 │    └────┬─────┘     │
 │         │            │
disable   │           enable
 │         ▼            │
 │    ┌──────────┐      │
 └─── │ disabled │ ◄────┘
      └────┬─────┘
           │ unloadPlugin()
           ▼
      ┌──────────┐
      │ unloaded │
      └──────────┘
```

### 4.2 生命周期钩子

```dart
class PluginLifecycleManager {
  Future<void> load(Plugin plugin, PluginContext context) async {
    try {
      await plugin.onLoad(context);
      _pluginStates[plugin.metadata.id] = PluginState.loaded;
    } catch (e) {
      _pluginStates[plugin.metadata.id] = PluginState.error;
      rethrow;
    }
  }

  Future<void> enable(Plugin plugin) async {
    if (_pluginStates[plugin.metadata.id] != PluginState.loaded) {
      throw StateError('插件未加载');
    }

    try {
      await plugin.onEnable();
      _pluginStates[plugin.metadata.id] = PluginState.enabled;
    } catch (e) {
      _pluginStates[plugin.metadata.id] = PluginState.error;
      rethrow;
    }
  }

  Future<void> disable(Plugin plugin) async {
    if (_pluginStates[plugin.metadata.id] != PluginState.enabled) {
      throw StateError('插件未启用');
    }

    try {
      await plugin.onDisable();
      _pluginStates[plugin.metadata.id] = PluginState.disabled;
    } catch (e) {
      _pluginStates[plugin.metadata.id] = PluginState.error;
      rethrow;
    }
  }

  Future<void> unload(Plugin plugin) async {
    if (_pluginStates[plugin.metadata.id] == PluginState.enabled) {
      await disable(plugin);
    }

    try {
      await plugin.onUnload();
      _pluginStates.remove(plugin.metadata.id);
    } catch (e) {
      _pluginStates[plugin.metadata.id] = PluginState.error;
      rethrow;
    }
  }
}
```

## 5. 性能考虑

### 5.1 概念性性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 插件发现时间 | < 500ms | 扫描默认插件目录 |
| 插件加载时间 | < 100ms | 单个插件加载 |
| 插件方法调用开销 | < 1ms | 跨 Isolate 消息传递 |
| 内存开销 | < 10MB per plugin | 不包括插件自身数据 |

### 5.2 优化策略

1. **延迟加载**:
   - 按需加载插件
   - 启动时只加载必需插件

2. **缓存机制**:
   - 缓存插件元数据
   - 缓存依赖解析结果

3. **消息批处理**:
   - 批量发送消息到插件
   - 减少跨 Isolate 通信次数

## 6. 关键文件清单

```
lib/core/plugin/
├── plugin.dart                   # Plugin 基类和接口
├── plugin_metadata.dart          # PluginMetadata 相关类
├── plugin_context.dart           # PluginContext 和 API 提供者
├── plugin_manager.dart           # IPluginManager 接口和实现
├── plugin_loader.dart            # 插件加载器
├── plugin_lifecycle.dart         # 生命周期管理
├── plugin_sandbox.dart           # 沙箱隔离
├── plugin_discoverer.dart        # 插件发现
├── dependency_resolver.dart      # 依赖解析
└── api/
    ├── storage_api.dart          # 存储 API
    ├── ui_api.dart               # UI API
    └── command_api.dart          # Command API
```

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
