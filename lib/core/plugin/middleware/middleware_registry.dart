import 'middleware_plugin.dart';
import 'middleware_pipeline.dart';

/// 中间件注册表
class MiddlewareRegistry {
  MiddlewareRegistry()
      : _commandMiddleware = {},
        _queryMiddleware = {},
        _pipeline = MiddlewarePipeline();
        
  final Map<String, CommandMiddlewarePlugin> _commandMiddleware;
  final Map<String, QueryMiddlewarePlugin> _queryMiddleware;
  final MiddlewarePipeline _pipeline;

  /// 注册命令中间件
  void registerCommandMiddleware(CommandMiddlewarePlugin middleware) {
    final key = middleware.metadata.id;
    if (_commandMiddleware.containsKey(key)) {
      // 先移除旧的中间件
      _pipeline.removeCommandMiddleware(_commandMiddleware[key]!);
    }
    _commandMiddleware[key] = middleware;
    _pipeline.addCommandMiddleware(middleware);
  }

  /// 注册查询中间件
  void registerQueryMiddleware(QueryMiddlewarePlugin middleware) {
    final key = middleware.metadata.id;
    if (_queryMiddleware.containsKey(key)) {
      // 先移除旧的中间件
      _pipeline.removeQueryMiddleware(_queryMiddleware[key]!);
    }
    _queryMiddleware[key] = middleware;
    _pipeline.addQueryMiddleware(middleware);
  }

  /// 移除命令中间件
  void unregisterCommandMiddleware(String pluginId) {
    final middleware = _commandMiddleware.remove(pluginId);
    if (middleware != null) {
      _pipeline.removeCommandMiddleware(middleware);
    }
  }

  /// 移除查询中间件
  void unregisterQueryMiddleware(String pluginId) {
    final middleware = _queryMiddleware.remove(pluginId);
    if (middleware != null) {
      _pipeline.removeQueryMiddleware(middleware);
    }
  }

  /// 获取命令中间件
  CommandMiddlewarePlugin? getCommandMiddleware(String pluginId) {
    return _commandMiddleware[pluginId];
  }

  /// 获取查询中间件
  QueryMiddlewarePlugin? getQueryMiddleware(String pluginId) {
    return _queryMiddleware[pluginId];
  }

  /// 获取所有命令中间件
  List<CommandMiddlewarePlugin> getAllCommandMiddleware() {
    return _commandMiddleware.values.toList();
  }

  /// 获取所有查询中间件
  List<QueryMiddlewarePlugin> getAllQueryMiddleware() {
    return _queryMiddleware.values.toList();
  }

  /// 获取中间件管道
  MiddlewarePipeline get pipeline => _pipeline;

  /// 清空所有中间件
  void clear() {
    _commandMiddleware.clear();
    _queryMiddleware.clear();
    _pipeline.clear();
  }

  /// 检查是否包含指定的命令中间件
  bool containsCommandMiddleware(String pluginId) {
    return _commandMiddleware.containsKey(pluginId);
  }

  /// 检查是否包含指定的查询中间件
  bool containsQueryMiddleware(String pluginId) {
    return _queryMiddleware.containsKey(pluginId);
  }

  /// 获取命令中间件数量
  int get commandMiddlewareCount => _commandMiddleware.length;

  /// 获取查询中间件数量
  int get queryMiddlewareCount => _queryMiddleware.length;
}
