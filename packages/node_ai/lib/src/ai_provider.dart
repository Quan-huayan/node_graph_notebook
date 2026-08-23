/// LLM 后端（01 拍板 #31，按 archive/ai 方式带走）：
/// `AIProvider` 接口 + `MockAIProvider`（默认，延迟回复，演示/测试可跑）
/// + `OpenAIProvider`（http，key 配置留 settings 迭代）。
///
/// 服务经 plugon DI 注册（AiPlugin.registerServices →
/// `addSingleton<AIProvider>`），Handler 延迟解析——插件可换 provider
/// 而无需改命令/Handler（03 §四 长任务契约的执行者）。
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_provider_config.dart';
import 'function_calling/ai_tool.dart';

/// 工具调用声明（模型返回）。
class ToolCallIntent {
  /// 构造调用声明。
  const ToolCallIntent({
    required this.id,
    required this.name,
    this.arguments = const <String, dynamic>{},
  });

  /// 调用 id（结果回填 tool_call_id）。
  final String id;

  /// 工具名（AITool.id）。
  final String name;

  /// 参数（JSON 对象）。
  final Map<String, dynamic> arguments;
}

/// 协议层消息（function calling 循环用；与落盘层 ChatMessage 分离——
/// 落盘走 markdown 文本，协议层走结构化 messages）。
class AIMessage {
  /// 构造消息（user/assistant/tool 角色）。
  const AIMessage({
    required this.role,
    this.content,
    this.toolCalls,
    this.toolCallId,
  });

  /// 角色（'user' / 'assistant' / 'tool'）。
  final String role;

  /// 文本内容。
  final String? content;

  /// assistant 的工具调用声明。
  final List<ToolCallIntent>? toolCalls;

  /// 工具结果回填 id。
  final String? toolCallId;
}

/// 模型回复（内容或工具调用）。
class AssistantResponse {
  /// 构造回复。
  const AssistantResponse({this.content, this.toolCalls});

  /// 文本内容（工具调用轮可能为 null）。
  final String? content;

  /// 工具调用（空 = 纯文本回复）。
  final List<ToolCallIntent>? toolCalls;
}

/// AI 回复服务接口。
abstract class AIProvider {
  /// 生成回复（[prompt] 上下文 + 问题）。
  ///
  /// 长任务调用方（AskAIHandler）保证不阻塞 UI——实现须 async。
  Future<String> generate(String prompt);

  /// 服务名称（设置 UI 展示）。
  String get serviceName;

  /// 多轮对话（带可选工具，M7.3 Function Calling）。
  ///
  /// 缺省实现 = 无工具路径（拼 prompt 调 [generate]）——旧 provider
  /// 无需改动即兼容。
  Future<AssistantResponse> complete({
    required List<AIMessage> messages,
    List<AITool>? tools,
  }) async {
    final prompt = messages
        .map((m) => '${m.role}: ${m.content ?? ''}')
        .join('\n');
    return AssistantResponse(content: await generate(prompt));
  }
}

/// 配置驱动提供器（M7.2 阶段 C：AI key 设置恢复）——
/// 按 AIProviderConfig 委托：key 空 → Mock；非空 → OpenAI。
///
/// 插件注册的 AIProvider 由此包装——设置表单改 key 即时生效，
/// 无需重建 provider 实例（01 拍板 #31：provider 可换而不改 Handler）。
class ConfigAIProvider implements AIProvider {
  /// 注入配置（plugon DI 解析）。
  ConfigAIProvider(this.config);

  /// LLM 后端配置。
  final AIProviderConfig config;

  @override
  String get serviceName => config.apiKey.isEmpty ? 'Mock AI' : 'OpenAI（已配置）';

  @override
  Future<String> generate(String prompt) async {
    final key = config.apiKey;
    if (key.isEmpty) {
      return const MockAIProvider().generate(prompt);
    }
    return OpenAIProvider(
      apiKey: key,
      model: config.model,
      baseUrl: config.baseUrl,
    ).generate(prompt);
  }

  @override
  Future<AssistantResponse> complete({
    required List<AIMessage> messages,
    List<AITool>? tools,
  }) {
    // 委托（implements 不继承接口默认实现——M7.3）。
    final key = config.apiKey;
    if (key.isEmpty) {
      return const MockAIProvider().complete(messages: messages, tools: tools);
    }
    return OpenAIProvider(
      apiKey: key,
      model: config.model,
      baseUrl: config.baseUrl,
    ).complete(messages: messages, tools: tools);
  }
}

/// Mock 提供器（默认：无网络依赖，杀手演示/测试可跑）。
class MockAIProvider implements AIProvider {
  /// 可配置延迟（测试注入 0 秒）与脚本化工具调用（测试驱动
  /// function calling 循环）。
  const MockAIProvider({
    this.delay = const Duration(milliseconds: 500),
    this.scriptedToolCalls,
  });

  /// 模拟思考延迟。
  final Duration delay;

  /// 脚本化工具调用（非空 → complete 恒返回工具调用；测试用）。
  final List<ToolCallIntent>? scriptedToolCalls;

  /// 脚本消费进度（按实例身份）。
  ///
  /// `const` 构造下 `scriptedToolCalls` 是**不可变列表**，直接 removeAt
  /// 会运行期崩溃（M7.4 const 清理后暴露）；消费进度改记在实例身份上
  /// （Expando——const 实例同一性稳定），列表本身零修改。
  static final Expando<int> _consumed = Expando<int>();

  @override
  String get serviceName => 'Mock AI';

  @override
  Future<String> generate(String prompt) async {
    await Future<void>.delayed(delay);
    // 简易回声回复：取笔记/消息的标题行（演示可读、确定性可测）。
    final firstLine = prompt
        .split('\n')
        .map((l) => l.trim())
        .firstWhere(
          (l) =>
              l.isNotEmpty &&
              !l.startsWith('笔记内容') &&
              !l.startsWith('对话记录') &&
              !l.startsWith('请针对'),
          orElse: () => '你的笔记',
        );
    return '（Mock 回复）我读到了「$firstLine」。这是一个演示回复——'
        '接入真实 AIProvider（如 OpenAI）后这里会是模型回答。';
  }

  @override
  Future<AssistantResponse> complete({
    required List<AIMessage> messages,
    List<AITool>? tools,
  }) async {
    // 脚本化工具调用：逐个消费（一轮一个）——消费完回落到文本路径，
    // 工具循环可终止（确定性测试驱动）。
    final scripted = scriptedToolCalls;
    if (scripted != null && scripted.isNotEmpty) {
      // 按实例身份取下一个脚本调用（不修改列表——const 列表不可变）。
      final index = _consumed[this] ?? 0;
      if (index >= scripted.length) {
        _consumed[this] = scripted.length; // 消费完 → 回落文本路径。
      } else {
        _consumed[this] = index + 1;
        return AssistantResponse(
          content: null,
          toolCalls: <ToolCallIntent>[scripted[index]],
        );
      }
    }
    // 无工具 / 脚本消费完 → 旧 generate 路径。
    return AssistantResponse(content: await generate(_promptOf(messages)));
  }

  static String _promptOf(List<AIMessage> messages) =>
      messages.map((m) => '${m.role}: ${m.content ?? ''}').join('\n');
}

/// OpenAI 兼容提供器（http；archive/ai 带走精简，key 配置留 settings）。
class OpenAIProvider implements AIProvider {
  /// 构造 OpenAI 提供器。
  OpenAIProvider({
    required this.apiKey,
    this.model = 'gpt-4o-mini',
    this.maxTokens = 2000,
    this.baseUrl = 'https://api.openai.com/v1',
  });

  /// API 密钥。
  final String apiKey;

  /// 模型名。
  final String model;

  /// 最大 token 数。
  final int maxTokens;

  /// API 基础 URL（兼容网关）。
  final String baseUrl;

  @override
  String get serviceName => 'OpenAI ($model)';

  @override
  Future<String> generate(String prompt) async {
    final response = await complete(
      messages: <AIMessage>[AIMessage(role: 'user', content: prompt)],
    );
    return response.content ?? '';
  }

  @override
  Future<AssistantResponse> complete({
    required List<AIMessage> messages,
    List<AITool>? tools,
  }) async {
    final hasTools = tools != null && tools.isNotEmpty;
    // 网络失败包装（P0-4）：断网/DNS/超时 → AIProviderException——
    // 调用方（AskAI UI）统一 catch 展示，不再静默冒泡。
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(<String, dynamic>{
              'model': model,
              'messages': <Map<String, dynamic>>[
                for (final message in messages)
                  <String, dynamic>{
                    'role': message.role,
                    if (message.content != null) 'content': message.content,
                    if (message.toolCallId != null)
                      'tool_call_id': message.toolCallId,
                    if (message.toolCalls != null &&
                        message.toolCalls!.isNotEmpty)
                      'tool_calls': <Map<String, dynamic>>[
                        for (final call in message.toolCalls!)
                          <String, dynamic>{
                            'id': call.id,
                            'type': 'function',
                            'function': <String, dynamic>{
                              'name': call.name,
                              'arguments': jsonEncode(call.arguments),
                            },
                          },
                      ],
                  },
              ],
              // M7.3 Function Calling：工具声明 + auto 选择。
              if (hasTools)
                'tools': <Map<String, dynamic>>[
                  for (final tool in tools)
                    <String, dynamic>{
                      'type': 'function',
                      'function': <String, dynamic>{
                        'name': tool.id,
                        'description': tool.description,
                        'parameters': tool.parametersSchema,
                      },
                    },
                ],
              if (hasTools) 'tool_choice': 'auto',
              'max_tokens': maxTokens,
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(seconds: 60));
    } on AIProviderException {
      rethrow;
    } catch (error) {
      throw AIProviderException('网络请求失败：$error');
    }
    if (response.statusCode != 200) {
      throw AIProviderException('OpenAI API 错误 ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw AIProviderException('OpenAI API 返回空 choices');
    }
    final message =
        (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>;
    final content = message['content'] as String?;
    // 工具调用解析（缺字段 → 空列表兜底）。
    final toolCallsRaw = message['tool_calls'] as List<dynamic>?;
    final toolCalls = <ToolCallIntent>[];
    if (toolCallsRaw != null) {
      for (final raw in toolCallsRaw) {
        final call = raw as Map<String, dynamic>;
        final function =
            (call['function'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        toolCalls.add(
          ToolCallIntent(
            id: call['id'] as String? ?? '',
            name: function['name'] as String? ?? '',
            arguments: _parseArguments(function['arguments']),
          ),
        );
      }
    }
    return AssistantResponse(
      content: content,
      toolCalls: toolCalls.isEmpty ? null : toolCalls,
    );
  }

  /// 参数解析（模型返回 JSON 字符串 → Map；损坏 → 空 Map 兜底）。
  static Map<String, dynamic> _parseArguments(dynamic raw) {
    if (raw is! String || raw.isEmpty) {
      return const <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
    } on FormatException {
      return const <String, dynamic>{};
    }
  }
}

/// LLM 调用异常（用户可读文案：AskAI 调用方捕获展示）。
class AIProviderException implements Exception {
  /// 构造异常。
  AIProviderException(this.message);

  /// 异常消息。
  final String message;

  @override
  String toString() => 'AIProviderException: $message';
}
