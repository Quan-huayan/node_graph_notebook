import '../../../../cqrs/commands/models/command.dart';
import '../../../../cqrs/commands/models/command_context.dart';
import '../../../../cqrs/query/query.dart';
import '../../../../utils/logger.dart';
import '../plugin.dart';

/// 中间件插件接口
abstract class MiddlewarePlugin extends Plugin {
  /// 中间件优先级（数值越小优先级越高）
  int get priority => 100;

  /// 插件初始化
  Future<void> onInit(MiddlewarePluginContext context);

  /// 插件销毁
  Future<void> onDispose();
}

/// 命令中间件插件接口
abstract class CommandMiddlewarePlugin extends MiddlewarePlugin {
  /// 判断是否处理该 Command
  bool canHandle(Command command);

  /// 处理 Command（返回 null 继续执行下一个中间件）
  Future<CommandResult?> handle(
    Command command,
    CommandContext context,
    NextMiddleware next,
  );
}

/// 查询中间件插件接口
abstract class QueryMiddlewarePlugin extends MiddlewarePlugin {
  /// 判断是否处理该 Query
  bool canHandle(Query query);

  /// 处理 Query（返回 null 继续执行下一个中间件）
  Future<QueryResult?> handle(
    Query query,
    NextQueryMiddleware next,
  );
}

/// 下一个中间件函数类型
typedef NextMiddleware =
    Future<CommandResult?> Function(Command command, CommandContext context);

/// 下一个查询中间件函数类型
typedef NextQueryMiddleware =
    Future<QueryResult?> Function(Query query);

/// 中间件插件上下文
class MiddlewarePluginContext {
  /// 创建中间件插件上下文
  MiddlewarePluginContext({
    required this.commandBus,
    required this.logger,
    required this.config,
  });

  /// 命令总线
  final dynamic commandBus;
  /// 插件日志
  final AppLogger logger;
  /// 插件配置
  final Map<String, dynamic> config;
}
