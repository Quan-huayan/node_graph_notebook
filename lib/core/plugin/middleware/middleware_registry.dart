import 'middleware_pipeline.dart';
import 'middleware_plugin.dart';

/// 中间件注册表
///
/// 负责管理和注册命令中间件和查询中间件，提供中间件的添加、移除和查询功能。
class MiddlewareRegistry {
  /// 创建一个新的中间件注册表实例。
  MiddlewareRegistry()
    : _commandMiddleware = {},
      _queryMiddleware = {},
      _pipeline = MiddlewarePipeline();

  /// 命令中间件映射，键为插件ID，值为中间件实例。
  final Map<String, CommandMiddlewarePlugin> _commandMiddleware;
  
  /// 查询中间件映射，键为插件ID，值为中间件实例。
  final Map<String, QueryMiddlewarePlugin> _queryMiddleware;
  
  /// 中间件管道，用于处理中间件的执行顺序。
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
  CommandMiddlewarePlugin? getCommandMiddleware(String pluginId) => _commandMiddleware[pluginId];

  /// 获取查询中间件
  QueryMiddlewarePlugin? getQueryMiddleware(String pluginId) => _queryMiddleware[pluginId];

  /// 获取所有命令中间件
  List<CommandMiddlewarePlugin> getAllCommandMiddleware() => _commandMiddleware.values.toList();

  /// 获取所有查询中间件
  List<QueryMiddlewarePlugin> getAllQueryMiddleware() => _queryMiddleware.values.toList();

  /// 获取中间件管道
  MiddlewarePipeline get pipeline => _pipeline;

  /// 清空所有中间件
  void clear() {
    _commandMiddleware.clear();
    _queryMiddleware.clear();
    _pipeline.clear();
  }

  /// 检查是否包含指定的命令中间件
  bool containsCommandMiddleware(String pluginId) => _commandMiddleware.containsKey(pluginId);

  /// 检查是否包含指定的查询中间件
  bool containsQueryMiddleware(String pluginId) => _queryMiddleware.containsKey(pluginId);

  /// 获取命令中间件数量
  int get commandMiddlewareCount => _commandMiddleware.length;

  /// 获取查询中间件数量
  int get queryMiddlewareCount => _queryMiddleware.length;
}
