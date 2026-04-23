import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/utils/logger.dart';
import '../../service/ai_service.dart';
import '../tool/ai_tool.dart';
import '../tool/ai_tool_registry.dart';
import '../validation/ai_tool_parameter_validator.dart';

/// AI Function Calling 服务
///
/// 核心服务，处理 AI 与工具的交互循环
///
/// 架构说明：
/// - 管理完整的 function calling 循环
/// - 支持 OpenAI、Anthropic、智谱 AI 的 function calling
/// - 集成现有的 CommandBus/QueryBus 架构
/// - 提供工具调用过程的可视化支持
/// - **安全强化**：参数验证防止恶意注入
class AIFunctionCallingService {
  /// 创建 function calling 服务
  ///
  /// [toolRegistry] - 工具注册表（默认使用全局单例）
  /// [maxIterations] - 最大迭代次数（防止无限循环）
  /// [enableVisualization] - 是否启用工具调用可视化
  /// [enableParameterValidation] - 是否启用参数验证（安全强化，默认启用）
  /// [parameterValidator] - 自定义参数验证器（可选）
  AIFunctionCallingService({
    AIToolRegistry? toolRegistry,
    this.maxIterations = 10,
    this.enableVisualization = true,
    this.enableParameterValidation = true,
    AIToolParameterValidator? parameterValidator,
  })  : _toolRegistry = toolRegistry ?? AIToolRegistry.instance,
        _parameterValidator = parameterValidator ??
            const AIToolParameterValidator(
              strictMode: false,
              enableSecurityChecks: true,
            );

  /// 工具注册表
  final AIToolRegistry _toolRegistry;

  /// 最大迭代次数
  final int maxIterations;

  /// 是否启用可视化
  final bool enableVisualization;

  /// 是否启用参数验证
  ///
  /// 安全强化功能，防止 AI 提供的恶意参数导致安全问题
  final bool enableParameterValidation;

  /// 参数验证器
  final AIToolParameterValidator _parameterValidator;

  /// 工具调用流
  ///
  /// 用于 UI 订阅工具调用事件
  final _toolCallStreamController =
      StreamController<ToolCallEvent>.broadcast();

  /// 工具调用事件流
  ///
  /// UI 可以订阅此流以显示工具调用过程
  Stream<ToolCallEvent> get toolCallStream =>
      _toolCallStreamController.stream;

  /// 发送消息并处理 function calling
  ///
  /// [userMessage] - 用户消息
  /// [provider] - AI 提供商
  /// [conversationHistory] - 对话历史（可选）
  /// [context] - 工具执行上下文
  ///
  /// 返回 AI 的最终响应（可能包含工具调用结果）
  ///
  /// 架构说明：
  /// - 自动处理多轮对话（AI 调用工具后，执行并返回结果，AI 继续生成）
  /// - 支持并行工具调用（AI 在同一轮中调用多个工具）
  /// - 工具调用事件会发送到 toolCallStream 供 UI 显示
  /// - 防止无限循环（maxIterations 限制）
  Future<String> chatWithFunctionCalling({
    required String userMessage,
    required AIProvider provider,
    List<ChatMessage>? conversationHistory,
    required AIToolContext context,
  }) async {
    // 初始化消息历史 - 创建新列表避免修改传入的列表
    final messages = [...?conversationHistory];
    messages.add(ChatMessage(role: 'user', content: userMessage));

    // 获取适用于该提供商的工具
    final tools = _getToolsForProvider(provider);

    // 迭代循环（处理多轮工具调用）
    for (var i = 0; i < maxIterations; i++) {
      // 1. 调用 AI
      final response = await _callAIWithTools(
        provider: provider,
        messages: messages,
        tools: tools,
      );

      // 2. 检查 AI 是否想调用工具
      if (response.toolCalls == null || response.toolCalls!.isEmpty) {
        // AI 没有调用工具，返回最终响应
        messages.add(ChatMessage(
          role: 'assistant',
          content: response.content,
        ));
        return response.content ?? 'No response from AI';
      }

      // 3. 执行工具调用
      final toolResults = await _executeToolCalls(
        toolCalls: response.toolCalls!,
        context: context,
      );

      // 4. 将工具调用和结果添加到消息历史
      messages.add(ChatMessage(
        role: 'assistant',
        content: response.content,
        toolCalls: response.toolCalls,
      ));

      for (final result in toolResults) {
        messages.add(ChatMessage(
          role: 'tool',
          toolCallId: result.toolCallId,
          content: result.result,
        ));
      }

      // 5. 继续循环，AI 会基于工具结果生成新的响应
    }

    // 达到最大迭代次数
    throw AIFunctionCallingException(
      'Maximum iterations ($maxIterations) reached. '
      'The AI may be stuck in a loop.',
    );
  }

  /// 调用 AI（带工具支持）
  ///
  /// [provider] - AI 提供商
  /// [messages] - 消息历史
  /// [tools] - 工具列表（已转换为提供商格式）
  ///
  /// 返回 AI 响应（可能包含工具调用请求）
  Future<AIResponse> _callAIWithTools({
    required AIProvider provider,
    required List<ChatMessage> messages,
    required List<Map<String, dynamic>> tools,
  }) async {
    // 根据提供商类型调用相应的 API
    if (provider is OpenAIProvider) {
      return _callOpenAIWithTools(
        provider,
        messages,
        tools,
      );
    } else if (provider is AnthropicProvider) {
      return _callAnthropicWithTools(
        provider,
        messages,
        tools,
      );
    } else if (provider is ZhipuAIProvider) {
      return _callZhipuAIWithTools(
        provider,
        messages,
        tools,
      );
    } else {
      // 不支持 function calling 的提供商，直接调用
      final content = await provider.generate(
        _formatMessagesForProvider(messages, provider),
      );
      return AIResponse(content: content);
    }
  }

  /// 调用 OpenAI（带 tools 参数）
  Future<AIResponse> _callOpenAIWithTools(
    OpenAIProvider provider,
    List<ChatMessage> messages,
    List<Map<String, dynamic>> tools,
  ) async {
    try {
      final requestBody = {
        'model': provider.model,
        'messages': messages.map(_convertMessageToOpenAIFormat).toList(),
        'tools': tools,
        'tool_choice': 'auto', // 让 AI 决定是否使用工具
        'max_tokens': provider.maxTokens,
        'temperature': 0.7,
      };

      // 调用 OpenAI API
      final response = await http.post(
        Uri.parse('${provider.baseUrl}/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${provider.apiKey}',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        final errorData = error['error'] as Map<String, dynamic>;
        throw AIFunctionCallingException(
          'OpenAI API error: ${errorData['message']}',
        );
      }

      final data = jsonDecode(response.body);
      return _parseOpenAIResponse(data);
    } catch (e) {
      const AppLogger('AIFunctionCallingService')
          .error('OpenAI API call failed', error: e);
      rethrow;
    }
  }

  /// 调用 Anthropic（带 tools 参数）
  Future<AIResponse> _callAnthropicWithTools(
    AnthropicProvider provider,
    List<ChatMessage> messages,
    List<Map<String, dynamic>> tools,
  ) async {
    try {
      // Anthropic 使用不同的消息格式
      final anthropicMessages = _convertMessagesToAnthropicFormat(messages);

      final requestBody = {
        'model': provider.model,
        'max_tokens': provider.maxTokens,
        'messages': anthropicMessages,
        'tools': tools,
      };

      final response = await http.post(
        Uri.parse('${provider.baseUrl}/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': provider.apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        final errorData = error['error'] as Map<String, dynamic>;
        throw AIFunctionCallingException(
          'Anthropic API error: ${errorData['message']}',
        );
      }

      final data = jsonDecode(response.body);
      return _parseAnthropicResponse(data);
    } catch (e) {
      const AppLogger('AIFunctionCallingService')
          .error('Anthropic API call failed', error: e);
      rethrow;
    }
  }

  /// 调用智谱 AI（带 tools 参数）
  Future<AIResponse> _callZhipuAIWithTools(
    ZhipuAIProvider provider,
    List<ChatMessage> messages,
    List<Map<String, dynamic>> tools,
  ) async {
    try {
      // 智谱 AI 与 OpenAI 格式兼容
      final requestBody = {
        'model': provider.model,
        'messages': messages.map(_convertMessageToOpenAIFormat).toList(),
        'tools': tools,
        'tool_choice': 'auto',
        'max_tokens': provider.maxTokens,
        'temperature': 0.7,
      };

      final token = provider.apiKey; // 简化：直接使用 API key

      final response = await http.post(
        Uri.parse('${provider.baseUrl}/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        final errorData = error['error'] as Map<String, dynamic>;
        throw AIFunctionCallingException(
          '智谱AI API error: ${errorData['message']}',
        );
      }

      final data = jsonDecode(response.body);
      return _parseOpenAIResponse(
          data); // 智谱 AI 使用与 OpenAI 兼容的响应格式
    } catch (e) {
      const AppLogger('AIFunctionCallingService')
          .error('智谱AI API call failed', error: e);
      rethrow;
    }
  }

  /// 执行工具调用
  ///
  /// [toolCalls] - AI 请求的工具调用列表
  /// [context] - 工具执行上下文
  ///
  /// 返回工具执行结果列表
  Future<List<ToolCallResult>> _executeToolCalls({
    required List<ToolCall> toolCalls,
    required AIToolContext context,
  }) async {
    final results = <ToolCallResult>[];

    // 并行执行所有工具调用
    final futures = toolCalls.map((toolCall) async {
      // 发布工具调用开始事件
      _toolCallStreamController.add(
        ToolCallStarted(
          toolId: toolCall.toolId,
          arguments: toolCall.arguments,
          timestamp: DateTime.now(),
        ),
      );

      try {
        // 查找工具
        final tool = _toolRegistry.getTool(toolCall.toolId);
        if (tool == null) {
          throw AIToolExecutionException('Tool not found: ${toolCall.toolId}');
        }

        // ✅ 安全强化：参数验证
        // 防止 AI 提供的恶意参数导致安全问题
        if (enableParameterValidation) {
          _parameterValidator.validateParameters(
            toolCall.toolId,
            toolCall.arguments,
            tool.parametersSchema,
          );
        }

        // 执行工具
        final result = await tool.execute(toolCall.arguments, context);

        // 发布工具调用成功事件
        _toolCallStreamController.add(
          ToolCallSucceeded(
            toolId: toolCall.toolId,
            result: result,
            timestamp: DateTime.now(),
          ),
        );

        return ToolCallResult(
          toolCallId: toolCall.id,
          toolId: toolCall.toolId,
          result: result.toAIFriendlyFormat(),
          success: true,
        );
      } catch (e) {
        // 发布工具调用失败事件
        _toolCallStreamController.add(
          ToolCallFailed(
            toolId: toolCall.toolId,
            error: e.toString(),
            timestamp: DateTime.now(),
          ),
        );

        return ToolCallResult(
          toolCallId: toolCall.id,
          toolId: toolCall.toolId,
          result: 'Error: $e',
          success: false,
        );
      }
    });

    results.addAll(await Future.wait(futures));
    return results;
  }

  /// 获取适用于提供商的工具
  ///
  /// [provider] - AI 提供商
  ///
  /// 返回已转换为提供商格式的工具列表
  List<Map<String, dynamic>> _getToolsForProvider(AIProvider provider) {
    if (provider is OpenAIProvider) {
      return _toolRegistry.toOpenAIFormat();
    } else if (provider is AnthropicProvider) {
      return _toolRegistry.toAnthropicFormat();
    } else if (provider is ZhipuAIProvider) {
      return _toolRegistry.toZhipuAIFormat();
    } else {
      return [];
    }
  }

  /// 将消息转换为 OpenAI 格式
  Map<String, dynamic> _convertMessageToOpenAIFormat(ChatMessage msg) {
    final result = <String, dynamic>{
      'role': msg.role,
    };

    if (msg.content != null) {
      result['content'] = msg.content;
    }

    if (msg.toolCalls != null) {
      result['tool_calls'] = msg.toolCalls!.map((call) => {
          'id': call.id,
          'type': 'function',
          'function': {
            'name': call.toolId,
            'arguments': jsonEncode(call.arguments),
          },
        }).toList();
    }

    if (msg.toolCallId != null) {
      result['tool_call_id'] = msg.toolCallId;
    }

    return result;
  }

  /// 将消息列表转换为 Anthropic 格式
  List<Map<String, dynamic>> _convertMessagesToAnthropicFormat(
      List<ChatMessage> messages) {
    // Anthropic 格式略有不同
    final result = <Map<String, dynamic>>[];

    for (final msg in messages) {
      if (msg.role == 'tool') {
        // Anthropic 使用 tool_result 类型
        result.add({
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': msg.toolCallId,
              'content': msg.content,
            }
          ]
        });
      } else if (msg.toolCalls != null && msg.toolCalls!.isNotEmpty) {
        // Anthropic 使用 tool_use 类型
        final content = <Map<String, dynamic>>[
          {
            'type': 'text',
            'text': msg.content ?? '',
          }
        ];

        for (final call in msg.toolCalls!) {
          content.add(<String, dynamic>{
            'type': 'tool_use',
            'id': call.id,
            'name': call.toolId,
            'input': call.arguments,
          });
        }

        result.add({
          'role': 'assistant',
          'content': content,
        });
      } else {
        // 普通消息
        result.add({
          'role': msg.role,
          'content': msg.content ?? '',
        });
      }
    }

    return result;
  }

  /// 解析 OpenAI 响应
  AIResponse _parseOpenAIResponse(Map<String, dynamic> data) {
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      return const AIResponse(content: 'No response');
    }

    final firstChoice = choices.first as Map<String, dynamic>;
    final message = firstChoice['message'] as Map<String, dynamic>;

    // 检查是否有工具调用
    final toolCallsRaw = message['tool_calls'] as List<dynamic>?;
    List<ToolCall>? toolCalls;

    if (toolCallsRaw != null && toolCallsRaw.isNotEmpty) {
      toolCalls = toolCallsRaw.map((callRaw) {
        final call = callRaw as Map<String, dynamic>;
        final function = call['function'] as Map<String, dynamic>;
        return ToolCall(
          id: call['id'] as String,
          toolId: function['name'] as String,
          arguments: jsonDecode(function['arguments'] as String)
              as Map<String, dynamic>,
        );
      }).toList();
    }

    return AIResponse(
      content: message['content'] as String?,
      toolCalls: toolCalls,
    );
  }

  /// 解析 Anthropic 响应
  AIResponse _parseAnthropicResponse(Map<String, dynamic> data) {
    final content = data['content'] as List<dynamic>;
    String? textContent;
    List<ToolCall>? toolCalls;

    for (final item in content) {
      final block = item as Map<String, dynamic>;
      final type = block['type'] as String;

      if (type == 'text') {
        textContent = block['text'] as String;
      } else if (type == 'tool_use') {
        toolCalls ??= [];
        toolCalls.add(ToolCall(
          id: block['id'] as String,
          toolId: block['name'] as String,
          arguments: block['input'] as Map<String, dynamic>,
        ));
      }
    }

    return AIResponse(
      content: textContent,
      toolCalls: toolCalls,
    );
  }

  /// 格式化消息用于不支持 function calling 的提供商
  String _formatMessagesForProvider(
      List<ChatMessage> messages, AIProvider provider) {
    final buffer = StringBuffer();

    for (final msg in messages) {
      if (msg.role == 'user') {
        buffer.writeln('User: ${msg.content}');
      } else if (msg.role == 'assistant') {
        buffer.writeln('Assistant: ${msg.content}');
      }
      // 忽略 tool 消息，因为不支持
    }

    return buffer.toString().trim();
  }

  /// 释放资源
  void dispose() {
    _toolCallStreamController.close();
  }
}

// === 辅助类型定义 ===

/// 聊天消息
///
/// 表示对话中的一条消息，可以是用户消息、助手消息或工具调用结果
class ChatMessage {
  /// 创建聊天消息
  ///
  /// [role] 消息角色（'user', 'assistant', 'tool'）
  /// [content] 消息内容
  /// [toolCalls] 工具调用列表（仅 assistant 消息）
  /// [toolCallId] 工具调用 ID（仅 tool 消息）
  const ChatMessage({
    required this.role,
    this.content,
    this.toolCalls,
    this.toolCallId,
  });

  /// 消息角色（'user', 'assistant', 'tool'）
  final String role;

  /// 消息内容
  final String? content;

  /// 工具调用列表（仅 assistant 消息）
  final List<ToolCall>? toolCalls;

  /// 工具调用 ID（仅 tool 消息）
  final String? toolCallId;
}

/// 工具调用
///
/// 表示 AI 请求调用一个工具
class ToolCall {
  /// 创建工具调用
  ///
  /// [id] 工具调用 ID
  /// [toolId] 工具 ID
  /// [arguments] 工具参数
  const ToolCall({
    required this.id,
    required this.toolId,
    required this.arguments,
  });

  /// 工具调用 ID
  final String id;

  /// 工具 ID
  final String toolId;

  /// 工具参数
  final Map<String, dynamic> arguments;
}

/// AI 响应
///
/// 表示 AI 返回的响应，可能包含工具调用请求
class AIResponse {
  /// 创建 AI 响应
  ///
  /// [content] 响应内容
  /// [toolCalls] 工具调用列表
  const AIResponse({
    this.content,
    this.toolCalls,
  });

  /// 响应内容
  final String? content;

  /// 工具调用列表
  final List<ToolCall>? toolCalls;
}

/// 工具调用结果
///
/// 表示工具执行后的结果
class ToolCallResult {
  /// 创建工具调用结果
  ///
  /// [toolCallId] 工具调用 ID
  /// [toolId] 工具 ID
  /// [result] 执行结果
  /// [success] 是否成功
  const ToolCallResult({
    required this.toolCallId,
    required this.toolId,
    required this.result,
    required this.success,
  });

  /// 工具调用 ID
  final String toolCallId;

  /// 工具 ID
  final String toolId;

  /// 执行结果
  final dynamic result;

  /// 是否成功
  final bool success;
}

/// 工具调用事件
///
/// 表示工具调用过程中的事件（开始、成功、失败）
abstract class ToolCallEvent {
  /// 创建工具调用事件
  ///
  /// [timestamp] 事件时间戳
  const ToolCallEvent({required this.timestamp});

  /// 事件时间戳
  final DateTime timestamp;
}

/// 工具调用开始事件
class ToolCallStarted extends ToolCallEvent {
  /// 创建工具调用开始事件
  ///
  /// [toolId] 工具 ID
  /// [arguments] 工具参数
  /// [timestamp] 事件时间戳
  const ToolCallStarted({
    required this.toolId,
    required this.arguments,
    required super.timestamp,
  });

  /// 工具 ID
  final String toolId;

  /// 工具参数
  final Map<String, dynamic> arguments;
}

/// 工具调用成功事件
class ToolCallSucceeded extends ToolCallEvent {
  /// 创建工具调用成功事件
  ///
  /// [toolId] 工具 ID
  /// [result] 执行结果
  /// [timestamp] 事件时间戳
  const ToolCallSucceeded({
    required this.toolId,
    required this.result,
    required super.timestamp,
  });

  /// 工具 ID
  final String toolId;

  /// 执行结果
  final AIToolResult result;
}

/// 工具调用失败事件
class ToolCallFailed extends ToolCallEvent {
  /// 创建工具调用失败事件
  ///
  /// [toolId] 工具 ID
  /// [error] 错误信息
  /// [timestamp] 事件时间戳
  const ToolCallFailed({
    required this.toolId,
    required this.error,
    required super.timestamp,
  });

  /// 工具 ID
  final String toolId;

  /// 错误信息
  final String error;
}

/// AI Function Calling 异常
///
/// 当 AI Function Calling 执行过程中发生错误时抛出此异常
class AIFunctionCallingException implements Exception {
  /// 创建 AI Function Calling 异常
  ///
  /// [message] 错误消息
  const AIFunctionCallingException(this.message);

  /// 错误消息
  final String message;

  @override
  String toString() => 'AIFunctionCallingException: $message';
}
