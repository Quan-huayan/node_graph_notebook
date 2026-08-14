/// Function Calling 循环（M7.3，archive/ai 服务循环带走）：
/// complete（带 tools）→ 模型返回 tool_calls → 校验 → 工具 execute
/// → 结果回填（tool 角色消息）→ 下一轮，直到模型返回纯文本。
///
/// 迭代上限 [maxIterations] 兜底（AI 失控死循环防护）。
library;

import 'dart:convert';

import '../ai_provider.dart';
import 'ai_tool.dart';
import 'ai_tool_parameter_validator.dart';

/// 工具调用循环。
class FunctionCallingLoop {
  /// 注入迭代上限与参数验证器。
  const FunctionCallingLoop({
    this.maxIterations = 10,
    this.validator = const AIToolParameterValidator(),
  });

  /// 最大迭代轮数。
  final int maxIterations;

  /// 参数验证器。
  final AIToolParameterValidator validator;

  /// 执行工具循环，返回最终文本回复。
  ///
  /// [provider] LLM 后端；[history] 初始消息（用户上下文）；
  /// [tools] 可用工具；[executeTool] 工具执行器（写路径归调用方）。
  Future<String> run({
    required AIProvider provider,
    required List<AIMessage> history,
    required List<AITool> tools,
    required Future<AIToolResult> Function(
      AITool tool,
      Map<String, dynamic> args,
    )
    executeTool,
  }) async {
    final messages = List<AIMessage>.from(history);
    for (var iteration = 0; iteration < maxIterations; iteration++) {
      final response = await provider.complete(
        messages: messages,
        tools: tools,
      );
      final toolCalls = response.toolCalls;
      if (toolCalls == null || toolCalls.isEmpty) {
        return response.content ?? '';
      }
      // 回填 assistant 消息（模型调用声明）。
      messages.add(
        AIMessage(
          role: 'assistant',
          content: response.content,
          toolCalls: toolCalls,
        ),
      );
      for (final call in toolCalls) {
        final tool = tools.where((t) => t.id == call.name).firstOrNull;
        if (tool == null) {
          messages.add(
            AIMessage(
              role: 'tool',
              content: 'Error: unknown tool "${call.name}"',
              toolCallId: call.id,
            ),
          );
          continue;
        }
        try {
          validator.validateParameters(
            tool.id,
            call.arguments,
            tool.parametersSchema,
          );
          final result = await executeTool(tool, call.arguments);
          messages.add(
            AIMessage(
              role: 'tool',
              content: jsonEncode(result.toAIFriendlyFormat()),
              toolCallId: call.id,
            ),
          );
        } on AIToolParameterValidationException catch (error) {
          // 校验失败 → 回填错误（模型可自我修正后重试）。
          messages.add(
            AIMessage(
              role: 'tool',
              content: 'Error: $error',
              toolCallId: call.id,
            ),
          );
        }
      }
    }
    throw AIProviderException('Function calling 超过最大迭代次数 ($maxIterations)');
  }
}
