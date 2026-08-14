/// Function Calling 测试（M7.3）：
/// 参数校验（原型污染拒绝）、注册表 owner 保护、脚本化工具调用 →
/// 节点命令实际落盘、循环终止/超限、AskAIHandler 全链路。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_ai/node_ai.dart';
import 'package:node_graph/node_graph.dart';
import 'package:plugon/plugon.dart';

void main() {
  test('参数校验：拒绝原型污染键（__proto__）', () {
    const validator = AIToolParameterValidator();
    expect(
      () => validator.validateParameters(
        'create_node',
        <String, dynamic>{
          '__proto__': <String, dynamic>{'x': 1},
        },
        <String, dynamic>{'properties': <String, dynamic>{}},
      ),
      throwsA(isA<AIToolParameterValidationException>()),
    );
  });

  test('参数校验：缺必需参数 / 类型不匹配', () {
    const validator = AIToolParameterValidator();
    expect(
      () => validator.validateParameters(
        'create_node',
        <String, dynamic>{'content': 'x'},
        <String, dynamic>{
          'properties': <String, dynamic>{
            'title': <String, dynamic>{'type': 'string'},
          },
          'required': <String>['title'],
        },
      ),
      throwsA(isA<AIToolParameterValidationException>()),
    );
    // 合法参数通过。
    validator.validateParameters(
      'create_node',
      <String, dynamic>{'title': 'ok'},
      <String, dynamic>{
        'properties': <String, dynamic>{
          'title': <String, dynamic>{'type': 'string'},
        },
        'required': <String>['title'],
      },
    );
  });

  test('注册表：注册/查/owner 保护/清空', () {
    final registry = AIToolRegistry();
    expect(registry.toolCount, 0);
    registry.registerTool(const CreateNodeTool(), pluginId: 'ai');
    expect(registry.hasTool('create_node'), isTrue);
    expect(registry.getTool('create_node'), isA<CreateNodeTool>());
    // 其他插件覆盖 → 拒绝。
    expect(
      () => registry.registerTool(const CreateNodeTool(), pluginId: 'other'),
      throwsA(isA<AIToolRegistrationException>()),
    );
    // 同插件重复注册 → 覆盖。
    registry.registerTool(const CreateNodeTool(), pluginId: 'ai');
    expect(registry.toolCount, 1);
    // OpenAI 格式。
    final openAI = registry.toOpenAIFormat();
    expect(openAI.first['type'], 'function');
    registry.clear();
    expect(registry.toolCount, 0);
  });

  test('工具循环：脚本化工具调用 → CreateNodeCommand 实际落盘 → 文本终止', () async {
    // 真 CommandBus + GraphPlugin handler（工具经 dispatch 判据①）。
    final root = Directory.systemTemp.createTempSync('ngn_fc');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(
        id: 'canvas',
        title: '画布',
        metadata: const <String, dynamic>{'kind': 'canvas'},
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    await host.start(plugins: <Plugin>[GraphPlugin()], rootNodeId: 'canvas');

    final provider = MockAIProvider(
      delay: Duration.zero,
      scriptedToolCalls: <ToolCallIntent>[
        ToolCallIntent(
          id: 'call-1',
          name: 'create_node',
          arguments: <String, dynamic>{'title': 'AI 创建的笔记'},
        ),
      ],
    );
    final loop = const FunctionCallingLoop();
    final reply = await loop.run(
      provider: provider,
      history: <AIMessage>[AIMessage(role: 'user', content: '帮我记一条笔记')],
      tools: <AITool>[const CreateNodeTool()],
      executeTool: (tool, arguments) async {
        final node = await tool.execute(
          arguments,
          AIToolContext(commandBus: host.commandBus, graph: host.graph),
        );
        return node;
      },
    );
    // 工具创建的节点已落盘（写后通知 → 画布可见）。
    expect(host.graph.getAll().where((n) => n.title == 'AI 创建的笔记').length, 1);
    // 脚本消费完 → 文本终止。
    expect(reply, contains('Mock 回复'));
  });

  test('工具循环：未知工具名 → 错误回填不中断', () async {
    final provider = MockAIProvider(
      delay: Duration.zero,
      scriptedToolCalls: <ToolCallIntent>[
        ToolCallIntent(
          id: 'call-x',
          name: 'no_such_tool',
          arguments: <String, dynamic>{},
        ),
      ],
    );
    final loop = const FunctionCallingLoop();
    final reply = await loop.run(
      provider: provider,
      history: <AIMessage>[AIMessage(role: 'user', content: 'x')],
      tools: const <AITool>[CreateNodeTool()],
      executeTool: (tool, arguments) async => AIToolResult.success(data: 'ok'),
    );
    expect(reply, contains('Mock 回复'));
  });

  test('工具循环：超限抛错（maxIterations 兜底）', () async {
    // 脚本永不消费完的 provider（覆盖 complete 恒返回工具调用）。
    final provider = _NeverEndingProvider();
    final loop = FunctionCallingLoop(maxIterations: 3);
    await expectLater(
      loop.run(
        provider: provider,
        history: <AIMessage>[AIMessage(role: 'user', content: 'x')],
        tools: <AITool>[const CreateNodeTool()],
        executeTool: (tool, arguments) async =>
            AIToolResult.success(data: 'ok'),
      ),
      throwsA(isA<AIProviderException>()),
    );
  });

  test('AskAIHandler 全链路：工具调用记录 + 最终回复落盘', () async {
    final root = Directory.systemTemp.createTempSync('ngn_fc2');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(
        id: 'root',
        title: '根',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'aiNode',
        title: 'AI 助手',
        metadata: const <String, dynamic>{'kind': 'ai'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'noteA',
        title: '笔记A',
        content: '关于主题的内容',
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    // 多插件场景：servicesProvider 注入（plugon loadPlugin 每次 dispose
    // 旧 provider——onLoad 快照在多插件下失效，M7 修正模式）。
    ServiceProvider resolveServices() => host.serviceProvider;
    await host.start(
      plugins: <Plugin>[
        AiPlugin(
          provider: MockAIProvider(
            delay: Duration.zero,
            scriptedToolCalls: <ToolCallIntent>[
              ToolCallIntent(
                id: 'call-1',
                name: 'create_node',
                arguments: <String, dynamic>{'title': 'AI 建的新节点'},
              ),
            ],
          ),
          servicesProvider: resolveServices,
        ),
        GraphPlugin(servicesProvider: resolveServices),
      ],
      rootNodeId: 'root',
    );
    // 建会话（拖入）+ 用户消息 + 提问。
    await host.commandBus.dispatch<DropIntoAICommand, DropIntoAIResult>(
      DropIntoAICommand(aiNodeId: 'aiNode', sourceId: 'noteA'),
    );
    final chatId = 'chat-noteA-aiNode';
    await host.commandBus.dispatch<AppendMessageCommand, AppendMessageResult>(
      AppendMessageCommand(chatId: chatId, message: '帮我记一条'),
    );
    await host.commandBus.dispatch<AskAICommand, AskAIResult>(
      AskAICommand(chatId: chatId),
    );

    final chat = host.graph.get(chatId)!;
    // 工具调用记录 + 结果记录 + 最终回复。
    expect(chat.content, contains('调用工具「create_node」'));
    expect(chat.content, contains('工具结果'));
    expect(chat.content, contains('Mock 回复'));
    // 工具创建的节点落盘。
    expect(host.graph.getAll().where((n) => n.title == 'AI 建的新节点').length, 1);
  });
}

/// 恒返回工具调用的 provider（超限测试）。
class _NeverEndingProvider implements AIProvider {
  @override
  String get serviceName => 'never';

  @override
  Future<String> generate(String prompt) async => 'text';

  @override
  Future<AssistantResponse> complete({
    required List<AIMessage> messages,
    List<AITool>? tools,
  }) async => AssistantResponse(
    content: null,
    toolCalls: <ToolCallIntent>[
      ToolCallIntent(
        id: 'call-n',
        name: 'create_node',
        arguments: const <String, dynamic>{},
      ),
    ],
  );
}
