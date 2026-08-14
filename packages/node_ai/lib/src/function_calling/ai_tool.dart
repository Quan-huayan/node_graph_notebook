/// AI 工具契约（M7.3 Function Calling 复活，archive/ai 资产带走）。
///
/// 工具 = AI 可调用的函数（OpenAI function calling 语义）：参数
/// JSON Schema（Draft 2020-12）+ execute。工具执行**必须经 CommandBus
/// dispatch**（判据①，写操作唯一执行者 = Handler，00 不变量 4.4-1）；
/// 读操作经 Graph。
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

/// AI 工具抽象基类。
abstract class AITool {
  /// const 构造（工具为无状态描述——可 const 装配）。
  const AITool();

  /// 工具唯一标识符（'create_node' 等）。
  String get id;

  /// 工具名称（显示给 AI，动词短语）。
  String get name;

  /// 工具描述（AI 理解用途：功能/何时用/参数含义）。
  String get description;

  /// 参数 JSON Schema（Draft 2020-12）。
  Map<String, dynamic> get parametersSchema;

  /// 工具分类（'node' / 'graph' / 'search' / 'analysis' / 'custom'）。
  String get category => 'custom';

  /// 工具优先级（0.0-1.0，影响 AI 调用顺序；默认 0.5）。
  double get priority => 0.5;

  /// 执行工具（参数已通过 schema 验证）。
  Future<AIToolResult> execute(
    Map<String, dynamic> arguments,
    AIToolContext context,
  );
}

/// AI 工具执行结果。
class AIToolResult {
  /// 成功（[data] 返回给 AI；[summary] 人类可读摘要）。
  const AIToolResult.success({required this.data, this.summary})
    : _success = true,
      error = null,
      isRetryable = false;

  /// 失败（[error] 消息发给 AI；[isRetryable] 可重试）。
  const AIToolResult.failure({required this.error, this.isRetryable = false})
    : _success = false,
      data = null,
      summary = null;

  /// 是否成功。
  bool get isSuccess => _success;

  final bool _success;

  /// 成功数据。
  final dynamic data;

  /// 人类可读摘要。
  final String? summary;

  /// 失败消息。
  final String? error;

  /// 是否可重试。
  final bool isRetryable;

  /// AI 友好格式（成功 = data；失败 = 错误消息）。
  dynamic toAIFriendlyFormat() {
    if (_success) {
      return data;
    }
    return 'Error: $error${isRetryable ? ' (retryable)' : ''}';
  }
}

/// AI 工具执行上下文（收敛依赖：CommandBus + Graph——旧 archive 的
/// PluginContext/QueryBus/Repository 依赖删除，新架构对应物）。
class AIToolContext {
  /// 注入写通道与结构存储。
  const AIToolContext({required this.commandBus, required this.graph});

  /// 命令总线（写操作）。
  final CommandBus commandBus;

  /// 结构存储（读操作）。
  final Graph graph;

  /// 便捷方法：执行命令（泛型结果）。
  Future<R> executeCommand<C extends Command, R extends WriteResult>(
    C command,
  ) => commandBus.dispatch<C, R>(command);
}

/// AI 工具执行异常。
class AIToolExecutionException implements Exception {
  /// 构造异常。
  const AIToolExecutionException(this.message);

  /// 错误消息。
  final String message;

  @override
  String toString() => 'AIToolExecutionException: $message';
}
