# 中间件插件设计文档

## 1. 概述

### 1.1 职责
中间件插件系统允许第三方扩展 Command/Query Bus 的功能，实现：
- 自定义验证逻辑
- 请求/响应转换
- 性能监控
- 日志记录
- 缓存策略
- 权限控制
- 审计追踪

### 1.2 目标
- **灵活性**: 支持在任意位置插入中间件
- **可组合性**: 多个中间件可以组合使用
- **隔离性**: 中间件之间相互隔离
- **可观测性**: 提供中间件执行的可观测性
- **性能**: 中间件执行开销 < 0.5ms

### 1.3 关键挑战
- **顺序控制**: 中间件的执行顺序
- **短路逻辑**: 支持提前返回
- **错误处理**: 错误的正确传播
- **依赖管理**: 中间件之间的依赖关系
- **热插拔**: 运行时添加/移除中间件

## 2. 架构设计

### 2.1 组件结构

```
MiddlewarePluginSystem
    │
    ├── CommandMiddlewarePlugin (Command 中间件插件)
    │   ├── priority (优先级)
    │   ├── handle() (处理方法)
    │   └── canHandle() (条件判断)
    │
    ├── QueryMiddlewarePlugin (Query 中间件插件)
    │   ├── priority (优先级)
    │   ├── handle() (处理方法)
    │   └── canHandle() (条件判断)
    │
    ├── MiddlewarePipeline (中间件管道)
    │   ├── middlewares (中间件列表)
    │   ├── execute() (执行管道)
    │   └── add/remove (添加/移除)
    │
    └── MiddlewareRegistry (中间件注册表)
        ├── commandMiddlewares
        ├── queryMiddlewares
        └── loadPlugin()
```

### 2.2 接口定义

#### Command 中间件插件

```dart
/// Command 中间件插件接口
abstract class CommandMiddlewarePlugin {
  /// 插件元数据
  PluginMetadata get metadata;

  /// 中间件优先级（数值越小优先级越高）
  int get priority => 100;

  /// 判断是否处理该 Command
  ///
  /// 返回 true 表示该中间件将处理此 Command
  bool canHandle(Command command);

  /// 处理 Command
  ///
  /// [command] - 要执行的 Command
  /// [context] - 执行上下文
  /// [next] - 下一个中间件的调用函数
  ///
  /// 返回 CommandResult 表示中间件拦截了执行
  /// 返回 null 表示继续执行下一个中间件
  Future<CommandResult?> handle(
    Command command,
    CommandContext context,
    NextMiddleware next,
  );

  /// 插件初始化
  Future<void> onInit(MiddlewarePluginContext context);

  /// 插件销毁
  Future<void> onDispose();
}

/// 下一个中间件调用函数
typedef NextMiddleware = Future<CommandResult> Function(
  Command command,
  CommandContext context,
);

/// 中间件插件上下文
class MiddlewarePluginContext {
  /// 插件配置
  final Map<String, dynamic> config;

  /// 日志记录器
  final Logger logger;

  /// 事件总线
  final EventBus eventBus;

  MiddlewarePluginContext({
    required this.config,
    required this.logger,
    required this.eventBus,
  });

  /// 获取插件配置项
  T? getConfig<T>(String key) {
    return config[key] as T?;
  }

  /// 设置配置项
  void setConfig(String key, dynamic value) {
    config[key] = value;
  }
}
```

#### Query 中间件插件

```dart
/// Query 中间件插件接口
abstract class QueryMiddlewarePlugin {
  /// 插件元数据
  PluginMetadata get metadata;

  /// 中间件优先级
  int get priority => 100;

  /// 判断是否处理该 Query
  bool canHandle(Query query);

  /// 处理 Query
  ///
  /// 返回 QueryResult 表示中间件拦截了执行
  /// 返回 null 表示继续执行下一个中间件
  Future<QueryResult?> handle(
    Query query,
    QueryContext context,
    NextQueryMiddleware next,
  );

  /// 插件初始化
  Future<void> onInit(MiddlewarePluginContext context);

  /// 插件销毁
  Future<void> onDispose();
}

/// 下一个 Query 中间件调用函数
typedef NextQueryMiddleware = Future<QueryResult> Function(
  Query query,
  QueryContext context,
);
```

#### 中间件管道

```dart
/// Command 中间件管道
class CommandMiddlewarePipeline {
  final List<CommandMiddlewarePlugin> _middlewares = [];
  final Logger _logger = Logger('CommandPipeline');

  /// 添加中间件
  void addMiddleware(CommandMiddlewarePlugin middleware) {
    _middlewares.add(middleware);
    // 按优先级排序
    _middlewares.sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// 移除中间件
  void removeMiddleware(CommandMiddlewarePlugin middleware) {
    _middlewares.remove(middleware);
  }

  /// 执行管道
  Future<CommandResult> execute(
    Command command,
    CommandContext context,
  ) async {
    return _executeChain(command, context, 0);
  }

  /// 递归执行中间件链
  Future<CommandResult> _executeChain(
    Command command,
    CommandContext context,
    int index,
  ) async {
    if (index >= _middlewares.length) {
      // 所有中间件执行完毕
      return CommandResult.ok(null);
    }

    final middleware = _middlewares[index];

    // 检查是否处理该 Command
    if (!middleware.canHandle(command)) {
      // 跳过该中间件
      return _executeChain(command, context, index + 1);
    }

    try {
      _logger.d('执行中间件: ${middleware.metadata.id}');

      final result = await middleware.handle(
        command,
        context,
        (cmd, ctx) => _executeChain(cmd, ctx, index + 1),
      );

      if (result != null) {
        // 中间件拦截了执行
        _logger.d('中间件 ${middleware.metadata.id} 拦截了执行');
        return result;
      }

      // 继续执行下一个中间件
      return _executeChain(command, context, index + 1);
    } catch (e, stackTrace) {
      _logger.e(
        '中间件 ${middleware.metadata.id} 执行失败',
        e,
        stackTrace,
      );
      return CommandResult.err('中间件执行失败: ${e.toString()}');
    }
  }
}
```

#### 中间件插件注册表

```dart
/// 中间件插件注册表
class MiddlewarePluginRegistry {
  final Map<String, CommandMiddlewarePlugin> _commandMiddlewares = {};
  final Map<String, QueryMiddlewarePlugin> _queryMiddlewares = {};
  final MiddlewarePluginContext _context;

  MiddlewarePluginRegistry(this._context);

  /// 注册 Command 中间件插件
  Future<void> registerCommandMiddleware(
    CommandMiddlewarePlugin middleware,
  ) async {
    final id = middleware.metadata.id;

    if (_commandMiddlewares.containsKey(id)) {
      throw PluginException('中间件插件已存在: $id');
    }

    // 初始化插件
    await middleware.onInit(_context);

    // 注册
    _commandMiddlewares[id] = middleware;

    _logger.i('注册 Command 中间件插件: $id');
  }

  /// 注销 Command 中间件插件
  Future<void> unregisterCommandMiddleware(String id) async {
    final middleware = _commandMiddlewares.remove(id);

    if (middleware != null) {
      await middleware.onDispose();
      _logger.i('注销 Command 中间件插件: $id');
    }
  }

  /// 注册 Query 中间件插件
  Future<void> registerQueryMiddleware(
    QueryMiddlewarePlugin middleware,
  ) async {
    final id = middleware.metadata.id;

    if (_queryMiddlewares.containsKey(id)) {
      throw PluginException('中间件插件已存在: $id');
    }

    // 初始化插件
    await middleware.onInit(_context);

    // 注册
    _queryMiddlewares[id] = middleware;

    _logger.i('注册 Query 中间件插件: $id');
  }

  /// 注销 Query 中间件插件
  Future<void> unregisterQueryMiddleware(String id) async {
    final middleware = _queryMiddlewares.remove(id);

    if (middleware != null) {
      await middleware.onDispose();
      _logger.i('注销 Query 中间件插件: $id');
    }
  }

  /// 获取所有 Command 中间件
  List<CommandMiddlewarePlugin> getCommandMiddlewares() {
    return _commandMiddlewares.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// 获取所有 Query 中间件
  List<QueryMiddlewarePlugin> getQueryMiddlewares() {
    return _queryMiddlewares.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// 从目录加载中间件插件
  Future<void> loadPluginsFromDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return;

    await for (final entity in dir.list()) {
      if (entity is Directory) {
        await _tryLoadPlugin(entity);
      }
    }
  }

  /// 尝试加载插件
  Future<void> _tryLoadPlugin(Directory dir) async {
    final manifestFile = File('${dir.path}/middleware_plugin.yaml');
    if (!await manifestFile.exists()) return;

    try {
      final yaml = await manifestFile.readAsString();
      final json = loadYaml(yaml);

      final type = json['type'] as String?;
      final entryPoint = json['entryPoint'] as String?;

      if (type == null || entryPoint == null) {
        _logger.w('插件清单缺少必要字段: ${dir.path}');
        return;
      }

      // 动态加载插件
      if (type == 'command') {
        final plugin = await _loadCommandMiddlewarePlugin(entryPoint);
        if (plugin != null) {
          await registerCommandMiddleware(plugin);
        }
      } else if (type == 'query') {
        final plugin = await _loadQueryMiddlewarePlugin(entryPoint);
        if (plugin != null) {
          await registerQueryMiddleware(plugin);
        }
      }
    } catch (e) {
      _logger.e('加载插件失败: ${dir.path}', e);
    }
  }

  Future<CommandMiddlewarePlugin?> _loadCommandMiddlewarePlugin(
    String entryPoint,
  ) async {
    // TODO: 实现动态加载逻辑
    return null;
  }

  Future<QueryMiddlewarePlugin?> _loadQueryMiddlewarePlugin(
    String entryPoint,
  ) async {
    // TODO: 实现动态加载逻辑
    return null;
  }
}
```

## 3. 核心中间件插件实现

### 3.1 缓存中间件

```dart
/// 缓存中间件插件
class CacheMiddlewarePlugin extends CommandMiddlewarePlugin {
  final CacheStorage _cache;
  final Duration _ttl;

  CacheMiddlewarePlugin({
    required CacheStorage cache,
    Duration ttl = const Duration(minutes: 5),
  })  : _cache = cache,
        _ttl = ttl;

  @override
  PluginMetadata get metadata => PluginMetadata(
        id: 'cache_middleware',
        name: '缓存中间件',
        version: '1.0.0',
        description: '为 Command 提供缓存功能',
        author: 'System',
        minAppVersion: '1.0.0',
        entryPoint: '',
        type: PluginType.command,
      );

  @override
  int get priority => 5; // 高优先级，优先检查缓存

  @override
  bool canHandle(Command command) {
    // 只缓存可缓存的 Command
    return command is CacheableCommand;
  }

  @override
  Future<CommandResult?> handle(
    Command command,
    CommandContext context,
    NextMiddleware next,
  ) async {
    final cacheableCommand = command as CacheableCommand;

    // 生成缓存键
    final cacheKey = _generateCacheKey(command);

    // 尝试从缓存获取
    final cached = await _cache.get(cacheKey);
    if (cached != null) {
      return CommandResult.ok(cached);
    }

    // 执行后续中间件
    final result = await next(command, context);

    // 缓存结果
    if (result.isSuccess) {
      await _cache.set(cacheKey, result.data, ttl: _ttl);
    }

    return result;
  }

  String _generateCacheKey(Command command) {
    // 根据Command生成唯一缓存键
    return 'cmd:${command.runtimeType}:${command.hashCode}';
  }

  @override
  Future<void> onInit(MiddlewarePluginContext context) async {
    // 初始化缓存
  }

  @override
  Future<void> onDispose() async {
    // 清理缓存
    await _cache.clear();
  }
}

/// 可缓存的 Command 接口
abstract class CacheableCommand extends Command {
  /// 生成缓存键
  String getCacheKey();
}

/// 缓存存储接口
abstract class CacheStorage {
  Future<dynamic> get(String key);
  Future<void> set(String key, dynamic value, {Duration? ttl});
  Future<void> delete(String key);
  Future<void> clear();
}
```

### 3.2 性能监控中间件

```dart
/// 性能监控中间件插件
class PerformanceMonitorMiddlewarePlugin extends CommandMiddlewarePlugin {
  final MetricsCollector _metrics;
  final Logger _logger;

  PerformanceMonitorMiddlewarePlugin({
    required MetricsCollector metrics,
    Logger? logger,
  })  : _metrics = metrics,
        _logger = logger ?? Logger('PerformanceMonitor');

  @override
  PluginMetadata get metadata => PluginMetadata(
        id: 'performance_monitor',
        name: '性能监控中间件',
        version: '1.0.0',
        description: '监控 Command 执行性能',
        author: 'System',
        minAppVersion: '1.0.0',
        entryPoint: '',
        type: PluginType.command,
      );

  @override
  int get priority => 1000; // 低优先级，最后执行

  @override
  bool canHandle(Command command) => true;

  @override
  Future<CommandResult?> handle(
    Command command,
    CommandContext context,
    NextMiddleware next,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      // 执行后续中间件
      final result = await next(command, context);

      stopwatch.stop();

      // 记录指标
      _metrics.recordCommandExecution(
        commandType: command.runtimeType.toString(),
        duration: stopwatch.elapsed,
        success: result.isSuccess,
      );

      // 慢查询警告
      if (stopwatch.elapsedMilliseconds > 100) {
        _logger.w(
          '慢 Command: ${command.runtimeType} '
          '耗时 ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      return result;
    } catch (e) {
      stopwatch.stop();

      // 记录错误
      _metrics.recordCommandExecution(
        commandType: command.runtimeType.toString(),
        duration: stopwatch.elapsed,
        success: false,
      );

      rethrow;
    }
  }

  @override
  Future<void> onInit(MiddlewarePluginContext context) async {
    _logger.i('性能监控中间件已启动');
  }

  @override
  Future<void> onDispose() async {
    _logger.i('性能监控中间件已停止');
  }
}

/// 指标收集器
class MetricsCollector {
  final Map<String, CommandMetrics> _metrics = {};

  void recordCommandExecution({
    required String commandType,
    required Duration duration,
    required bool success,
  }) {
    final metrics = _metrics.putIfAbsent(
      commandType,
      () => CommandMetrics(commandType),
    );

    metrics.record(duration, success);
  }

  CommandMetrics? getMetrics(String commandType) {
    return _metrics[commandType];
  }

  Map<String, CommandMetrics> getAllMetrics() {
    return Map.from(_metrics);
  }
}

/// Command 指标
class CommandMetrics {
  final String commandType;
  int totalExecutions = 0;
  int successfulExecutions = 0;
  int failedExecutions = 0;
  final List<Duration> _durations = [];

  CommandMetrics(this.commandType);

  void record(Duration duration, bool success) {
    totalExecutions++;
    _durations.add(duration);

    if (success) {
      successfulExecutions++;
    } else {
      failedExecutions++;
    }
  }

  Duration get averageDuration {
    if (_durations.isEmpty) return Duration.zero;
    final totalMs =
        _durations.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
    return Duration(milliseconds: totalMs ~/ _durations.length);
  }

  Duration get p95Duration {
    if (_durations.isEmpty) return Duration.zero;
    final sorted = List.from(_durations)..sort((a, b) => a.compareTo(b));
    final index = (sorted.length * 0.95).floor() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  Duration get p99Duration {
    if (_durations.isEmpty) return Duration.zero;
    final sorted = List.from(_durations)..sort((a, b) => a.compareTo(b));
    final index = (sorted.length * 0.99).floor() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}
```

### 3.3 审计日志中间件

```dart
/// 审计日志中间件插件
class AuditLogMiddlewarePlugin extends CommandMiddlewarePlugin {
  final AuditLogWriter _writer;
  final Logger _logger;

  AuditLogMiddlewarePlugin({
    required AuditLogWriter writer,
    Logger? logger,
  })  : _writer = writer,
        _logger = logger ?? Logger('AuditLog');

  @override
  PluginMetadata get metadata => PluginMetadata(
        id: 'audit_log',
        name: '审计日志中间件',
        version: '1.0.0',
        description: '记录 Command 审计日志',
        author: 'System',
        minAppVersion: '1.0.0',
        entryPoint: '',
        type: PluginType.command,
      );

  @override
  int get priority => 900; // 接近最后执行

  @override
  bool canHandle(Command command) {
    // 只审计需要审计的 Command
    return command is AuditableCommand;
  }

  @override
  Future<CommandResult?> handle(
    Command command,
    CommandContext context,
    NextMiddleware next,
  ) async {
    final auditableCommand = command as AuditableCommand;

    // 创建审计记录
    final auditRecord = AuditRecord(
      commandType: command.runtimeType.toString(),
      userId: context.get<String>('userId') ?? 'anonymous',
      timestamp: DateTime.now(),
      inputData: auditableCommand.getAuditData(),
    );

    try {
      // 执行后续中间件
      final result = await next(command, context);

      // 记录结果
      auditRecord.outputData = result.data?.toString();
      auditRecord.success = result.isSuccess;
      auditRecord.error = result.error;

      // 写入审计日志
      await _writer.write(auditRecord);

      return result;
    } catch (e) {
      // 记录异常
      auditRecord.success = false;
      auditRecord.error = e.toString();
      await _writer.write(auditRecord);

      rethrow;
    }
  }

  @override
  Future<void> onInit(MiddlewarePluginContext context) async {
    _logger.i('审计日志中间件已启动');
  }

  @override
  Future<void> onDispose() async {
    await _writer.close();
  }
}

/// 可审计的 Command 接口
abstract class AuditableCommand extends Command {
  /// 获取审计数据
  Map<String, dynamic> getAuditData();
}

/// 审计记录
class AuditRecord {
  final String commandType;
  final String userId;
  final DateTime timestamp;
  final Map<String, dynamic> inputData;
  String? outputData;
  bool? success;
  String? error;

  AuditRecord({
    required this.commandType,
    required this.userId,
    required this.timestamp,
    required this.inputData,
  });

  Map<String, dynamic> toJson() {
    return {
      'commandType': commandType,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'inputData': inputData,
      'outputData': outputData,
      'success': success,
      'error': error,
    };
  }
}

/// 审计日志写入器
abstract class AuditLogWriter {
  Future<void> write(AuditRecord record);
  Future<void> close();
}
```

## 4. 中间件插件清单文件

### 4.1 清单格式

```yaml
# middleware_plugin.yaml
id: my_middleware_plugin
name: 我的中介件插件
version: 1.0.0
description: 插件描述
author: 作者名
minAppVersion: 1.0.0

# 插件类型：command 或 query
type: command

# 入口点
entryPoint: lib/middleware_plugin.dart

# 配置
config:
  cache_ttl: 300
  max_cache_size: 1000
```

## 5. 性能考虑

### 5.1 概念性性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 中间件执行开销 | < 0.5ms | 单个中间件的平均执行时间 |
| 管道总开销 | < 2ms | 所有中间件的总执行时间 |
| 插件加载时间 | < 50ms | 单个中间件插件的加载时间 |

### 5.2 优化策略

1. **短路机制**:
   - 条件不满足时快速返回
   - 减少不必要的中间件执行

2. **异步执行**:
   - 非关键中间件异步执行
   - 不阻塞主流程

3. **缓存结果**:
   - 缓存中间件判断结果
   - 避免重复计算

## 6. 关键文件清单

```
lib/core/plugin/middleware/
├── middleware_plugin.dart         # 中间件插件基类
├── middleware_pipeline.dart       # 中间件管道
├── middleware_registry.dart       # 中间件注册表
└── builtin/                       # 内置中间件
    ├── cache_middleware.dart      # 缓存中间件
    ├── performance_middleware.dart # 性能监控中间件
    ├── audit_middleware.dart      # 审计日志中间件
    ├── validation_middleware.dart # 验证中间件
    └── logging_middleware.dart    # 日志中间件
```

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
