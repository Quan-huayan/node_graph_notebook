import '../../commands/models/command.dart';
import '../../commands/models/command_context.dart';
import '../../commands/models/command_handler.dart';
import 'middleware_plugin.dart';

/// 中间件管道
class MiddlewarePipeline {
  /// 构造函数
  MiddlewarePipeline({
    List<CommandMiddlewarePlugin>? commandMiddleware,
    List<QueryMiddlewarePlugin>? queryMiddleware,
  }) : _commandMiddleware = commandMiddleware ?? [],
       _queryMiddleware = queryMiddleware ?? [] {
    // 按优先级排序（数值越小优先级越高）
    _commandMiddleware.sort((a, b) => a.priority.compareTo(b.priority));
    _queryMiddleware.sort((a, b) => a.priority.compareTo(b.priority));
  }

  final List<CommandMiddlewarePlugin> _commandMiddleware;
  final List<QueryMiddlewarePlugin> _queryMiddleware;

  /// 执行命令中间件
  Future<CommandResult> executeCommand(
    Command command,
    CommandContext context,
    CommandHandler handler,
  ) async {
    var index = 0;

    Future<CommandResult?> next(Command cmd, CommandContext ctx) async {
      if (index < _commandMiddleware.length) {
        final middleware = _commandMiddleware[index++];
        if (middleware.canHandle(cmd)) {
          final result = await middleware.handle(cmd, ctx, next);
          if (result != null) {
            return result;
          }
        }
        return next(cmd, ctx);
      } else {
        // 所有中间件处理完成，执行最终处理
        return handler.execute(cmd, ctx);
      }
    }

    final result = await next(command, context);
    return result ?? CommandResult.success(null);
  }

  /// 执行查询中间件
  Future<dynamic> executeQuery(
    dynamic query,
    dynamic context,
    QueryHandler handler,
  ) async {
    var index = 0;

    Future<dynamic> next(dynamic q, dynamic ctx) async {
      if (index < _queryMiddleware.length) {
        final middleware = _queryMiddleware[index++];
        if (middleware.canHandle(q)) {
          final result = await middleware.handle(q, ctx, next);
          if (result != null) {
            return result;
          }
        }
        return next(q, ctx);
      } else {
        // 所有中间件处理完成，执行最终处理
        return handler(q, ctx);
      }
    }

    return next(query, context);
  }

  /// 添加命令中间件
  void addCommandMiddleware(CommandMiddlewarePlugin middleware) {
    _commandMiddleware..add(middleware)
    ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// 添加查询中间件
  void addQueryMiddleware(QueryMiddlewarePlugin middleware) {
    _queryMiddleware..add(middleware)
    ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// 移除命令中间件
  void removeCommandMiddleware(CommandMiddlewarePlugin middleware) {
    _commandMiddleware.remove(middleware);
  }

  /// 移除查询中间件
  void removeQueryMiddleware(QueryMiddlewarePlugin middleware) {
    _queryMiddleware.remove(middleware);
  }

  /// 清空所有中间件
  void clear() {
    _commandMiddleware.clear();
    _queryMiddleware.clear();
  }

  /// 获取命令中间件数量
  int get commandMiddlewareCount => _commandMiddleware.length;

  /// 获取查询中间件数量
  int get queryMiddlewareCount => _queryMiddleware.length;
}

/// 查询处理器类型
typedef QueryHandler = Future<dynamic> Function(dynamic query, dynamic context);
