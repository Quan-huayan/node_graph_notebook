/// AI 工具定义接口
///
/// 定义 AI 可以调用的工具及其参数 schema
/// 支持类似 OpenAI function calling 的功能
library;

import '../../../../core/commands/command_bus.dart';
import '../../../../core/commands/models/command.dart';
import '../../../../core/cqrs/query/query.dart';
import '../../../../core/cqrs/query/query_bus.dart';
import '../../../../core/plugin/plugin_context.dart';
import '../../../../core/repositories/graph_repository.dart';
import '../../../../core/repositories/node_repository.dart';

/// AI 工具抽象基类
///
/// 定义 AI 可以调用的工具及其参数 schema
/// 支持类似 OpenAI function calling 的功能
///
/// 所有 AI 工具都应该继承此类并实现相应的方法
abstract class AITool {
  /// 工具唯一标识符
  ///
  /// 示例: 'create_node', 'search_nodes', 'connect_nodes'
  String get id;

  /// 工具名称（显示给 AI）
  ///
  /// 应该是动词短语，清晰描述工具功能
  /// 示例: 'create_node', 'search_nodes_by_title'
  String get name;

  /// 工具描述（用于 AI 理解工具用途）
  ///
  /// 应该详细说明：
  /// - 工具的功能
  /// - 何时使用
  /// - 参数的含义
  String get description;

  /// 参数 JSON Schema
  ///
  /// 使用 JSON Schema Draft 2020-12 格式
  /// 定义工具接受的参数结构
  Map<String, dynamic> get parametersSchema;

  /// 执行工具
  ///
  /// [arguments] - AI 提供的参数（已通过 schema 验证）
  /// [context] - 工具执行上下文（包含 CommandBus, PluginContext 等）
  ///
  /// 返回工具执行结果（会发送回 AI）
  ///
  /// 架构说明：
  /// - 工具实现应该通过 CommandBus 执行写操作
  /// - 工具实现应该通过 QueryBus 或 Repository 执行读操作
  /// - 返回值应该是 AI 可以理解的字符串或结构化数据
  Future<AIToolResult> execute(
    Map<String, dynamic> arguments,
    AIToolContext context,
  );

  /// 工具分类（用于 UI 分组显示）
  ///
  /// 预定义分类：
  /// - 'node' - 节点操作（创建、更新、删除）
  /// - 'graph' - 图操作（连接、布局）
  /// - 'search' - 搜索操作
  /// - 'analysis' - 分析操作
  /// - 'custom' - 自定义工具
  String get category => 'custom';

  /// 工具是否需要确认（用于敏感操作）
  ///
  /// 如果为 true，工具执行前会向用户确认
  /// 示例：删除节点、批量操作等敏感操作应该设为 true
  bool get requiresConfirmation => false;

  /// 工具优先级（影响 AI 调用顺序）
  ///
  /// 范围：0.0 - 1.0
  /// 默认值：0.5
  /// 更高优先级的工具会优先展示给 AI
  double get priority => 0.5;
}

/// AI 工具执行结果
///
/// 封装工具执行的结果，支持多种返回格式
class AIToolResult {
  /// 创建成功结果
  ///
  /// [data] - 返回给 AI 的数据（可以是字符串或结构化数据）
  /// [summary] - 人类可读的摘要（显示在 UI 中）
  const AIToolResult.success({
    required this.data,
    this.summary,
  })  : _success = true,
        error = null,
        isRetryable = false;

  /// 创建失败结果
  ///
  /// [error] - 错误消息（会发送给 AI）
  /// [isRetryable] - 是否可重试（如果为 true，AI 可能会重试）
  const AIToolResult.failure({
    required this.error,
    this.isRetryable = false,
  })  : _success = false,
        data = null,
        summary = null;

  /// 是否成功
  bool get isSuccess => _success;

  final bool _success;

  /// 返回数据（成功时）
  final dynamic data;

  /// 人类可读摘要（可选）
  final String? summary;

  /// 错误消息（失败时）
  final String? error;

  /// 是否可重试（失败时）
  final bool isRetryable;

  /// 转换为 AI 友好的格式
  ///
  /// 成功：返回 data 字段
  /// 失败：返回错误消息
  dynamic toAIFriendlyFormat() {
    if (_success) {
      return data;
    } else {
      return 'Error: $error${isRetryable ? ' (retryable)' : ''}';
    }
  }
}

/// AI 工具执行上下文
///
/// 提供工具执行时需要的系统依赖
class AIToolContext {
  /// 创建工具执行上下文
  const AIToolContext({
    required this.commandBus,
    required this.pluginContext,
    this.queryBus,
    this.nodeRepository,
    this.graphRepository,
  });

  /// Command Bus（执行写操作）
  final CommandBus commandBus;

  /// 插件上下文（访问系统服务）
  final PluginContext pluginContext;

  /// Query Bus（执行复杂查询）
  final QueryBus? queryBus;

  /// 节点仓库（直接访问）
  final NodeRepository? nodeRepository;

  /// 图仓库（直接访问）
  final GraphRepository? graphRepository;

  /// 便捷方法：执行命令
  Future<CommandResult> executeCommand(Command command) async => commandBus.dispatch(command);

  /// 便捷方法：执行查询
  Future<T> executeQuery<T>(Query<T> query) async {
    final bus = queryBus;
    if (bus == null) {
      throw const AIToolExecutionException('QueryBus not available');
    }
    final result = await bus.dispatch(query);
    if (!result.isSuccess) {
      throw AIToolExecutionException(result.error ?? 'Query failed');
    }
    return result.data as T;
  }
}

/// AI 工具执行异常
class AIToolExecutionException implements Exception {
  /// 创建工具执行异常
  const AIToolExecutionException(this.message);

  /// 错误消息
  final String message;

  @override
  String toString() => 'AIToolExecutionException: $message';
}
