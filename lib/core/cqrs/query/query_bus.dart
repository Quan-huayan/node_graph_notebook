import 'dart:async';
import '../../plugin/service_registry.dart';
import 'query.dart';
import 'query_cache.dart';

/// Query Bus - 查询总线
///
/// 负责调度和执行查询请求，是 CQRS 架构中读操作的统一入口
/// 提供查询缓存、中间件管道、错误处理等功能
///
/// 架构说明：
/// Query Bus 实现了 CQRS 模式的 Query 端，提供以下功能：
/// 1. 查询调度：将 Query 分发到对应的 Handler
/// 2. 查询缓存：通过 QueryCache 提升重复查询性能
/// 3. 中间件管道：支持日志、监控、权限检查等横切关注点
/// 4. 错误处理：统一处理查询失败情况
///
/// 使用示例：
/// ```dart
/// // 注册 Query Handler
/// queryBus.registerHandler(LoadNodeQuery, () => LoadNodeQueryHandler(repository));
///
/// // 执行查询
/// final result = await queryBus.dispatch(LoadNodeQuery(nodeId: 'abc'));
/// if (result.isSuccess) {
///   print(result.data);
/// }
/// ```
class QueryBus {
  /// 构造函数
  QueryBus({
    required ServiceRegistry serviceRegistry,
    int maxCacheSize = 1000,
    Duration defaultCacheTtl = const Duration(minutes: 5),
  }) : _cache = QueryCache(
          maxSize: maxCacheSize,
          defaultTtl: defaultCacheTtl,
        );

  /// 已注册的 Query Handlers
  final Map<Type, QueryHandler> _handlers = {};

  /// 查询缓存
  final QueryCache _cache;

  /// 中间件管道
  final List<QueryMiddleware> _middlewares = [];

  /// 注册 Query Handler
  ///
  /// [Q] Query 类型
  /// [T] 返回数据类型
  /// [queryType] Query 的运行时类型
  /// [handlerFactory] Handler 工厂函数
  ///
  /// 使用示例：
  /// ```dart
  /// queryBus.registerHandler<LoadNodeQuery, Node>(
  ///   LoadNodeQuery,
  ///   () => LoadNodeQueryHandler(repository),
  /// );
  /// ```
  void registerHandler<T, Q extends Query<T>>(
    Type queryType,
    QueryHandler<T, Q> Function() handlerFactory,
  ) {
    _handlers[queryType] = handlerFactory() as QueryHandler;
  }

  /// 注册中间件
  ///
  /// 中间件按注册顺序执行，可用于日志、监控、权限检查等
  void registerMiddleware(QueryMiddleware middleware) {
    _middlewares.add(middleware);
  }

  /// 调度查询
  ///
  /// [Q] Query 类型
  /// [T] 返回数据类型
  /// [query] 要执行的查询
  /// 返回查询结果
  ///
  /// 执行流程：
  /// 1. 检查缓存（如果 Query 是可缓存的）
  /// 2. 执行中间件管道
  /// 3. 调用对应的 Handler 处理查询
  /// 4. 缓存结果（如果 Query 是可缓存的）
  /// 5. 返回结果
  ///
  /// 使用示例：
  /// ```dart
  /// final result = await queryBus.dispatch<Node>(
  ///   LoadNodeQuery(nodeId: 'abc'),
  /// );
  /// if (result.isSuccess) {
  ///   print('Node loaded: ${result.data}');
  /// } else {
  ///   print('Failed to load node: ${result.error}');
  /// }
  /// ```
  Future<QueryResult<T>> dispatch<T, Q extends Query<T>>(Q query) async {
    // 检查是否已注册 Handler
    final handlerType = query.runtimeType;
    if (!_handlers.containsKey(handlerType)) {
      return QueryResult.failure(
        'No handler registered for query type: $handlerType',
      );
    }

    // 检查缓存
    if (query is CacheableQuery) {
      final cachedResult = _cache.get(query);
      if (cachedResult != null) {
        return cachedResult as QueryResult<T>;
      }
    }

    // 执行中间件管道
    for (final middleware in _middlewares) {
      final shouldContinue = await middleware.beforeQuery(query);
      if (!shouldContinue) {
        return QueryResult.failure('Query blocked by middleware');
      }
    }

    try {
      // 获取 Handler 并执行查询
      final handler = _handlers[handlerType] as QueryHandler<T, Q>;
      final result = await handler.handle(query);

      // 缓存结果
      if (query is CacheableQuery && result.isSuccess) {
        _cache.put(query, result);
      }

      // 执行中间件后处理
      for (final middleware in _middlewares) {
        await middleware.afterQuery(query, result);
      }

      return result;
    } catch (error, stackTrace) {
      final queryError = error is QueryException
          ? error.message
          : error.toString();

      final result = QueryResult<T>.failure(
        queryError,
        stackTrace,
      );

      // 通知中间件查询失败
      for (final middleware in _middlewares) {
        await middleware.onQueryError(query, error, stackTrace);
      }

      return result;
    }
  }

  /// 清除查询缓存
  ///
  /// [queryType] 如果指定，只清除该类型查询的缓存；否则清除所有缓存
  void clearCache([Type? queryType]) {
    if (queryType != null) {
      _cache.invalidateByType(queryType);
    } else {
      _cache.clear();
    }
  }

  /// 获取缓存统计信息
  QueryCacheStats get cacheStats => _cache.stats;

  /// 释放资源
  void dispose() {
    _cache.clear();
    _handlers.clear();
    _middlewares.clear();
  }
}

/// Query 中间件接口
///
/// 用于在查询执行前后添加自定义逻辑
abstract class QueryMiddleware {
  /// 查询前执行
  ///
  /// 返回 false 可以阻止查询执行
  Future<bool> beforeQuery(Query query) async => true;

  /// 查询后执行
  Future<void> afterQuery(Query query, QueryResult result) async {}

  /// 查询错误时执行
  Future<void> onQueryError(
    Query query,
    Object error,
    StackTrace stackTrace,
  ) async {}
}
