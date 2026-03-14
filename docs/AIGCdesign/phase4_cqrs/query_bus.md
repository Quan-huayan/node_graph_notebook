# 查询总线 (Query Bus) 设计文档

## 概述

### 职责

查询总线是 CQRS 架构中负责处理查询端（读端）请求的核心组件。它负责：

- **查询路由**：将查询请求路由到正确的查询处理器
- **处理器注册**：管理查询处理器的注册和生命周期
- **结果缓存**：缓存查询结果以提高读取性能
- **并发控制**：处理并发查询请求，确保线程安全
- **错误处理**：统一处理查询过程中的错误和异常

### 目标

1. **性能优化**：通过缓存和异步处理最大化查询性能
2. **解耦**：实现查询请求与查询处理器的完全解耦
3. **可扩展性**：支持动态注册新的查询类型和处理器
4. **可测试性**：易于单元测试和集成测试
5. **类型安全**：在编译时确保查询类型与处理器类型的匹配

### 关键挑战

1. **缓存一致性**：在数据更新时如何使缓存失效
2. **缓存策略**：如何选择合适的缓存策略（LRU、TTL、基于事件的失效）
3. **性能瓶颈**：如何避免查询总线成为性能瓶颈
4. **内存管理**：如何控制缓存大小，避免内存溢出
5. **并发安全**：如何确保并发查询的正确性和性能

## 架构设计

### 组件结构

```
QueryBus
├── QueryHandlerRegistry          # 查询处理器注册表
├── QueryDispatcher               # 查询分发器
├── QueryCache                    # 查询缓存
├── QueryExecutor                 # 查询执行器
└── QueryResultProcessor          # 查询结果处理器

Query<I, O>                       # 查询接口
├── QueryId                       # 查询唯一标识
├── Timestamp                     # 查询时间戳
└── CachePolicy                   # 缓存策略

QueryHandler<I, O>                # 查询处理器接口
├── handle(query)                 # 处理查询
└── canHandle(query)              # 判断是否能处理查询

QueryResult<O>                    # 查询结果
├── data                          # 查询数据
├── metadata                      # 元数据（缓存状态、执行时间等）
└── errors                        # 错误信息
```

### 接口定义

```dart
/// 查询接口 - 所有查询的基接口
abstract class Query<I, O> {
  /// 查询唯一标识
  String get queryId;

  /// 查询时间戳
  DateTime get timestamp;

  /// 缓存策略
  CachePolicy get cachePolicy;

  /// 查询参数（用于缓存键生成）
  Map<String, dynamic> get parameters;
}

/// 缓存策略
enum CachePolicy {
  /// 不缓存
  none,

  /// 基于时间的缓存（TTL）
  timeToLive,

  /// 基于事件的缓存（在特定事件时失效）
  eventBased,

  /// 永久缓存（直到显式失效）
  permanent,
}

/// 查询处理器接口
abstract class QueryHandler<I, O> {
  /// 处理查询
  Future<QueryResult<O>> handle(I query);

  /// 判断是否能处理该查询
  bool canHandle(I query);

  /// 获取处理器支持的查询类型
  Type get queryType;
}

/// 查询结果
class QueryResult<O> {
  final O? data;
  final QueryResultMetadata metadata;
  final List<QueryError> errors;

  const QueryResult({
    this.data,
    required this.metadata,
    this.errors = const [],
  });

  bool get isSuccess => errors.isEmpty;
  bool get isCached => metadata.isCached;
}

/// 查询结果元数据
class QueryResultMetadata {
  final bool isCached;
  final Duration executionTime;
  final DateTime timestamp;
  final int? cacheHitCount;

  const QueryResultMetadata({
    required this.isCached,
    required this.executionTime,
    required this.timestamp,
    this.cacheHitCount,
  });
}

/// 查询总线接口
abstract class QueryBus {
  /// 执行查询
  Future<QueryResult<O>> execute<I extends Query<I, O>, O>(I query);

  /// 注册查询处理器
  void registerHandler<I, O>(QueryHandler<I, O> handler);

  /// 注销查询处理器
  void unregisterHandler<I, O>(QueryHandler<I, O> handler);

  /// 清除缓存
  Future<void> clearCache({Type? queryType, String? queryId});

  /// 获取缓存统计信息
  QueryCacheStats getCacheStats();
}

/// 查询缓存统计信息
class QueryCacheStats {
  final int totalQueries;
  final int cacheHits;
  final int cacheMisses;
  final double hitRate;
  final int cacheSize;
  final Duration averageExecutionTime;

  const QueryCacheStats({
    required this.totalQueries,
    required this.cacheHits,
    required this.cacheMisses,
    required this.hitRate,
    required this.cacheSize,
    required this.averageExecutionTime,
  });
}
```

### 查询总线实现

```dart
/// 查询总线实现
class QueryBusImpl implements QueryBus {
  final QueryHandlerRegistry _registry;
  final QueryDispatcher _dispatcher;
  final QueryCache _cache;
  final QueryExecutor _executor;

  QueryBusImpl({
    required QueryHandlerRegistry registry,
    required QueryDispatcher dispatcher,
    required QueryCache cache,
    required QueryExecutor executor,
  })  : _registry = registry,
        _dispatcher = dispatcher,
        _cache = cache,
        _executor = executor;

  @override
  Future<QueryResult<O>> execute<I extends Query<I, O>, O>(I query) async {
    final startTime = DateTime.now();

    try {
      // 1. 检查缓存
      if (query.cachePolicy != CachePolicy.none) {
        final cachedResult = await _cache.get<I, O>(query);
        if (cachedResult != null) {
          return cachedResult.copyWith(
            metadata: cachedResult.metadata.copyWith(
              cacheHitCount: cachedResult.metadata.cacheHitCount! + 1,
            ),
          );
        }
      }

      // 2. 路由查询到处理器
      final handler = _registry.findHandler<I, O>(query);
      if (handler == null) {
        throw QueryHandlerNotFoundException(query.queryId);
      }

      // 3. 执行查询
      final result = await _executor.execute(query, handler);

      // 4. 缓存结果
      if (query.cachePolicy != CachePolicy.none && result.isSuccess) {
        await _cache.put(query, result);
      }

      // 5. 更新统计信息
      final executionTime = DateTime.now().difference(startTime);
      return result.copyWith(
        metadata: result.metadata.copyWith(
          executionTime: executionTime,
        ),
      );
    } catch (e, stackTrace) {
      // 错误处理
      return QueryResult<O>(
        metadata: QueryResultMetadata(
          isCached: false,
          executionTime: DateTime.now().difference(startTime),
          timestamp: DateTime.now(),
        ),
        errors: [
          QueryError(
            message: e.toString(),
            stackTrace: stackTrace.toString(),
          ),
        ],
      );
    }
  }

  @override
  void registerHandler<I, O>(QueryHandler<I, O> handler) {
    _registry.register(handler);
  }

  @override
  void unregisterHandler<I, O>(QueryHandler<I, O> handler) {
    _registry.unregister(handler);
  }

  @override
  Future<void> clearCache({Type? queryType, String? queryId}) async {
    if (queryType != null) {
      await _cache.clearByType(queryType);
    } else if (queryId != null) {
      await _cache.clearById(queryId);
    } else {
      await _cache.clearAll();
    }
  }

  @override
  QueryCacheStats getCacheStats() => _cache.getStats();
}
```

### 查询处理器注册表

```dart
/// 查询处理器注册表
class QueryHandlerRegistry {
  final Map<Type, List<QueryHandler>> _handlers = {};

  /// 注册查询处理器
  void register<I, O>(QueryHandler<I, O> handler) {
    final queryType = handler.queryType;
    _handlers.putIfAbsent(queryType, () => []);
    _handlers[queryType]!.add(handler);
  }

  /// 注销查询处理器
  void unregister<I, O>(QueryHandler<I, O> handler) {
    final queryType = handler.queryType;
    _handlers[queryType]?.remove(handler);
  }

  /// 查找查询处理器
  QueryHandler<I, O>? findHandler<I, O>(Query<I, O> query) {
    final handlers = _handlers[query.runtimeType];
    if (handlers == null || handlers.isEmpty) {
      return null;
    }

    // 返回第一个能处理该查询的处理器
    for (final handler in handlers) {
      if (handler.canHandle(query)) {
        return handler as QueryHandler<I, O>;
      }
    }

    return null;
  }

  /// 获取所有注册的处理器类型
  List<Type> getRegisteredTypes() => _handlers.keys.toList();
}
```

### 查询缓存实现

```dart
/// 查询缓存
class QueryCache {
  final Map<String, _CachedResult> _cache = {};
  final Map<Type, Set<String>> _typeIndex = {};
  final int maxSize;
  final Duration defaultTtl;

  QueryCache({
    this.maxSize = 1000,
    this.defaultTtl = const Duration(minutes: 5),
  });

  /// 获取缓存结果
  Future<QueryResult<O>?> get<I extends Query<I, O>, O>(I query) async {
    final key = _generateCacheKey(query);
    final cached = _cache[key];

    if (cached == null) {
      return null;
    }

    // 检查是否过期
    if (cached.isExpired) {
      await _remove(key);
      return null;
    }

    return cached.result as QueryResult<O>;
  }

  /// 缓存结果
  Future<void> put<I extends Query<I, O>, O>(
    I query,
    QueryResult<O> result,
  ) async {
    final key = _generateCacheKey(query);
    final queryType = query.runtimeType;

    // 检查缓存大小限制
    if (_cache.length >= maxSize) {
      await _evictLRU();
    }

    // 计算过期时间
    DateTime? expirationTime;
    switch (query.cachePolicy) {
      case CachePolicy.timeToLive:
        expirationTime = DateTime.now().add(defaultTtl);
        break;
      case CachePolicy.permanent:
        expirationTime = null;
        break;
      case CachePolicy.none:
      case CachePolicy.eventBased:
        expirationTime = DateTime.now().add(const Duration(minutes: 1));
        break;
    }

    _cache[key] = _CachedResult(
      result: result,
      expirationTime: expirationTime,
      lastAccessTime: DateTime.now(),
    );

    _typeIndex.putIfAbsent(queryType, () => {});
    _typeIndex[queryType]!.add(key);
  }

  /// 清除缓存
  Future<void> clearAll() async {
    _cache.clear();
    _typeIndex.clear();
  }

  /// 按类型清除缓存
  Future<void> clearByType(Type queryType) async {
    final keys = _typeIndex[queryType];
    if (keys != null) {
      for (final key in keys) {
        _cache.remove(key);
      }
      _typeIndex.remove(queryType);
    }
  }

  /// 按 ID 清除缓存
  Future<void> clearById(String queryId) async {
    final keysToRemove = <String>[];
    _cache.forEach((key, value) {
      if (key.startsWith(queryId)) {
        keysToRemove.add(key);
      }
    });

    for (final key in keysToRemove) {
      await _remove(key);
    }
  }

  /// 生成缓存键
  String _generateCacheKey(Query<dynamic, dynamic> query) {
    final params = query.parameters;
    final paramsStr = params.entries
        .map((e) => '${e.key}:${e.value}')
        .join(',')
        .hashCode
        .toString();
    return '${query.runtimeType}_$paramsStr';
  }

  /// 移除缓存项
  Future<void> _remove(String key) async {
    final cached = _cache[key];
    if (cached != null) {
      _typeIndex[cached.result.data.runtimeType]?.remove(key);
    }
    _cache.remove(key);
  }

  /// LRU 淘汰策略
  Future<void> _evictLRU() async {
    String? oldestKey;
    DateTime? oldestAccess;

    _cache.forEach((key, value) {
      if (oldestAccess == null || value.lastAccessTime.isBefore(oldestAccess!)) {
        oldestAccess = value.lastAccessTime;
        oldestKey = key;
      }
    });

    if (oldestKey != null) {
      await _remove(oldestKey!);
    }
  }

  /// 获取缓存统计信息
  QueryCacheStats getStats() {
    // 实现统计信息收集
    return QueryCacheStats(
      totalQueries: 0,
      cacheHits: 0,
      cacheMisses: 0,
      hitRate: 0.0,
      cacheSize: _cache.length,
      averageExecutionTime: Duration.zero,
    );
  }
}

class _CachedResult {
  final QueryResult result;
  final DateTime? expirationTime;
  DateTime lastAccessTime;

  _CachedResult({
    required this.result,
    this.expirationTime,
    required this.lastAccessTime,
  });

  bool get isExpired =>
      expirationTime != null && DateTime.now().isAfter(expirationTime!);
}
```

## 核心算法

### 1. 查询路由算法

**问题描述**：将查询请求路由到正确的查询处理器，支持多个处理器候选和优先级选择。

**算法描述**：
1. 根据查询类型查找所有注册的处理器
2. 使用处理器的 `canHandle` 方法筛选能处理该查询的处理器
3. 如果有多个处理器，选择优先级最高的
4. 如果没有找到处理器，抛出异常

**伪代码**：
```
function routeQuery(query):
    handlers = registry.findHandlers(query.runtimeType)
    candidates = []

    for handler in handlers:
        if handler.canHandle(query):
            candidates.append(handler)

    if candidates.isEmpty:
        throw NoHandlerFoundException

    // 按优先级排序
    candidates.sortByPriority()

    return candidates.first
```

**复杂度分析**：
- 时间复杂度：O(n)，其中 n 是注册的处理器数量
- 空间复杂度：O(k)，其中 k 是候选处理器数量

### 2. 缓存键生成算法

**问题描述**：为查询生成唯一且一致的缓存键，确保相同查询命中缓存，不同查询不冲突。

**算法描述**：
1. 获取查询类型名称
2. 获取查询参数并排序（确保参数顺序不影响键值）
3. 使用哈希算法生成参数摘要
4. 组合类型名称和参数摘要生成最终键

**伪代码**：
```
function generateCacheKey(query):
    typeName = query.runtimeType.toString()
    params = query.parameters

    // 排序参数确保一致性
    sortedParams = sortParams(params)

    // 生成哈希
    paramHash = hash(sortedParams)

    return "${typeName}_${paramHash}"

function sortParams(params):
    keys = params.keys.sort()
    sorted = []
    for key in keys:
        sorted.append("${key}:${params[key]}")
    return sorted.join(',')
```

**复杂度分析**：
- 时间复杂度：O(n log n)，主要是参数排序
- 空间复杂度：O(n)，用于存储排序后的参数

### 3. 缓存失效策略

**问题描述**：在数据更新时使相关缓存失效，确保不会返回过时数据。

**算法描述**：
1. 监听领域事件（如 NodeChangedEvent、GraphChangedEvent）
2. 根据事件类型确定受影响的查询类型
3. 生成受影响的缓存键模式
4. 删除匹配的缓存项

**伪代码**：
```
function onDomainEvent(event):
    affectedQueryTypes = determineAffectedQueries(event)

    for queryType in affectedQueryTypes:
        keys = findCacheKeys(queryType, event)
        for key in keys:
            cache.remove(key)

function determineAffectedQueries(event):
    // 根据事件类型返回受影响的查询类型
    if event is NodeChangedEvent:
        return [GetNodeQuery, GetNodeChildrenQuery, SearchNodesQuery]
    else if event is GraphChangedEvent:
        return [GetGraphQuery, GetGraphNodesQuery]
    // ... 其他事件类型
```

**复杂度分析**：
- 时间复杂度：O(m + k)，其中 m 是受影响的查询类型数量，k 是缓存键数量
- 空间复杂度：O(1)

### 4. LRU 缓存淘汰算法

**问题描述**：当缓存达到容量上限时，淘汰最久未使用的缓存项。

**算法描述**：
1. 维护每个缓存项的最后访问时间
2. 当缓存满时，遍历所有缓存项
3. 找到最后访问时间最早的项
4. 删除该项

**伪代码**：
```
function evictLRU():
    oldestKey = null
    oldestTime = null

    for (key, cachedResult) in cache:
        if oldestTime == null or cachedResult.lastAccessTime < oldestTime:
            oldestTime = cachedResult.lastAccessTime
            oldestKey = key

    if oldestKey != null:
        cache.remove(oldestKey)
```

**复杂度分析**：
- 时间复杂度：O(n)，其中 n 是缓存项数量
- 空间复杂度：O(1)

## 性能考虑

### 概念性能指标

1. **查询响应时间**：
   - 缓存命中：< 1ms
   - 缓存未命中：10-100ms（取决于查询复杂度）
   - 目标：95% 的查询响应时间 < 50ms

2. **缓存命中率**：
   - 热点数据：> 90%
   - 平均命中率：> 70%
   - 目标：整体缓存命中率 > 75%

3. **吞吐量**：
   - 单线程：> 1000 queries/second
   - 多线程：> 5000 queries/second
   - 目标：支持 > 2000 queries/second

4. **内存使用**：
   - 每个缓存项平均大小：1-10 KB
   - 默认缓存大小：1000 项
   - 预估内存使用：10-50 MB

### 性能优化策略

1. **异步缓存加载**：
   - 使用 Isolate 进行后台缓存预加载
   - 预测用户可能执行的查询并提前缓存

2. **缓存分层**：
   - L1 缓存：内存缓存（小容量，快速访问）
   - L2 缓存：本地文件缓存（大容量，较慢访问）

3. **批量查询优化**：
   - 支持批量查询接口
   - 批量查询结果缓存

4. **缓存压缩**：
   - 对大型查询结果进行压缩
   - 减少内存占用

5. **智能缓存预热**：
   - 应用启动时预加载常用查询
   - 基于历史查询模式预测和缓存

## 关键文件列表

### 核心实现文件

1. **D:\Projects\node_graph_notebook\lib\core\cqrs\query\query.dart**
   - 定义 Query 接口和基础实现
   - 包含所有查询类型的基类

2. **D:\Projects\node_graph_notebook\lib\core\cqrs\query\query_handler.dart**
   - 定义 QueryHandler 接口
   - 包含查询处理器的基类和工具类

3. **D:\Projects\node_graph_notebook\lib\core\cqrs\query\query_bus.dart**
   - QueryBus 接口定义
   - QueryBusImpl 实现类

4. **D:\Projects\node_graph_notebook\lib\core\cqrs\query\query_handler_registry.dart**
   - 查询处理器注册表实现
   - 处理器查找和路由逻辑

5. **D:\Projects\node_graph_notebook\lib\core\cqrs\query\query_cache.dart**
   - 查询缓存实现
   - 包含 LRU 淘汰策略和缓存统计

6. **D:\Projects\node_graph_notebook\lib\core\cqrs\query\query_result.dart**
   - QueryResult 和相关数据类
   - 查询结果元数据定义

### 查询实现文件

7. **D:\Projects\node_graph_notebook\lib\core\cqrs\query\node_queries.dart**
   - 节点相关查询实现
   - GetNodeQuery, SearchNodesQuery 等

8. **D:\Projects\node_graph_notebook\lib\core\cqrs\query\graph_queries.dart**
   - 图相关查询实现
   - GetGraphQuery, GetGraphNodeQuery 等

9. **D:\Projects\node_graph_notebook\lib\core\cqrs\query\connection_queries.dart**
   - 连接相关查询实现
   - GetConnectionQuery, GetConnectionsQuery 等

### 查询处理器文件

10. **D:\Projects\node_graph_notebook\lib\core\cqrs\query\handlers\node_query_handlers.dart**
    - 节点查询处理器实现
    - 与 NodeRepository 集成

11. **D:\Projects\node_graph_notebook\lib\core\cqrs\query\handlers\graph_query_handlers.dart**
    - 图查询处理器实现
    - 与 GraphRepository 集成

12. **D:\Projects\node_graph_notebook\lib\core\cqrs\query\handlers\connection_query_handlers.dart**
    - 连接查询处理器实现
    - 连接查询逻辑

### 配置和工具文件

13. **D:\Projects\node_graph_notebook\lib\core\cqrs\query\query_config.dart**
    - 查询总线配置
    - 缓存配置和策略设置

14. **D:\Projects\node_graph_notebook\lib\core\cqrs\query\query_cache_stats.dart**
    - 缓存统计信息收集
    - 性能监控工具

### 测试文件

15. **D:\Projects\node_graph_notebook\test\core\cqrs\query\query_bus_test.dart**
    - 查询总线单元测试
    - 路由和缓存测试

16. **D:\Projects\node_graph_notebook\test\core\cqrs\query\query_cache_test.dart**
    - 查询缓存单元测试
    - 缓存策略测试

17. **D:\Projects\node_graph_notebook\test\core\cqrs\query\query_handler_test.dart**
    - 查询处理器单元测试
    - 处理器集成测试

### 集成文件

18. **D:\Projects\node_graph_notebook\lib\app.dart**
    - 在应用初始化时注册查询总线
    - 提供查询总线依赖注入

19. **D:\Projects\node_graph_notebook\lib\core\events\event_integration.dart**
    - 领域事件与缓存失效的集成
    - 事件监听器配置
