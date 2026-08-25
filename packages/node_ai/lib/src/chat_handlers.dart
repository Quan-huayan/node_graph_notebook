/// 对话命令 Handler（M7 AI 插件，写操作唯一执行者，01-D）：
///
/// - DropIntoAIHandler：查 references.source 的 chat 实例——无则创建
///   `{ai, source}`、有则更新 ai（同 contain 模式）；环校验双保险。
/// - AppendMessageHandler：用户消息 append 会话记录（chat content）落盘。
/// - AskAIHandler：**长任务 Handler**（03 §四）——读会话 + source 笔记
///   构造上下文 → AIProvider 回复 → append 落盘 → WriteResult 写后通知。
///   全部 async（Mock 延迟 / HTTP），不阻塞 UI 线程。
library;

import 'dart:convert';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

import 'ai_provider.dart';
import 'chat_commands.dart';
import 'chat_concept.dart';
import 'chat_messages.dart';
import 'function_calling/ai_tool.dart';
import 'function_calling/ai_tool_registry.dart';
import 'function_calling/function_calling_loop.dart';

/// 拖入 Handler：创建/更新 chat 实例（L1-node，引用两端）。
class DropIntoAIHandler
    extends CommandHandler<DropIntoAICommand, DropIntoAIResult> {
  /// [graphProvider] 延迟解析结构存储（registerExtensions 阶段无 provider）。
  DropIntoAIHandler({
    required Graph Function() graphProvider,
    AcyclicChecker? checker,
  }) : _graphProvider = graphProvider,
       _checker = checker ?? const AcyclicChecker();

  final Graph Function() _graphProvider;
  final AcyclicChecker _checker;

  @override
  Type get commandType => DropIntoAICommand;

  @override
  Future<DropIntoAIResult> handle(DropIntoAICommand command) async {
    final graph = _graphProvider();
    // 1. 现有 chat 实例（source == sourceId）→ 更新 ai；无 → 新建。
    //    （一个 source 一个会话，同 contain 模式，01 拍板 #30。）
    final existing = chatOfSource(graph, command.sourceId);
    final source = graph.get(command.sourceId);
    if (source == null) {
      throw StateError('拖入源不存在: ${command.sourceId}');
    }
    // 注：id 用连字符（Windows 文件名不容冒号）。
    final chatId =
        existing?.id ?? 'chat-${command.sourceId}-${command.aiNodeId}';
    final newRefs = <String, String>{
      'ai': command.aiNodeId,
      'source': command.sourceId,
    };
    // 2. 环校验（双保险：drop 预判 + Handler 二次，00 §2.3 执行点）。
    final cycle = _checker.check(
      affectedRefs: <String, Set<String>>{chatId: newRefs.values.toSet()},
      graph: graph,
    );
    if (cycle != null) {
      throw CycleError(cycle);
    }
    // 3. chat 实例落盘（L1-node，引用两端；笔记/AI 节点零变更）。
    final chat =
        existing ??
        StoredNode(
          id: chatId,
          title: '对话:${source.title}',
          createdAt: source.createdAt,
          updatedAt: source.updatedAt,
        );
    graph.save(chat.copyWith(references: newRefs));
    // 4. 写后通知（WriteResult → UI 管理器树重挂）。
    return DropIntoAIResult(
      affectedNodeIds: <String>{chatId, command.aiNodeId},
    );
  }
}

/// 追加用户消息 Handler（快命令）。
class AppendMessageHandler
    extends CommandHandler<AppendMessageCommand, AppendMessageResult> {
  /// [graphProvider] 延迟解析结构存储。
  AppendMessageHandler({required Graph Function() graphProvider})
    : _graphProvider = graphProvider;

  final Graph Function() _graphProvider;

  @override
  Type get commandType => AppendMessageCommand;

  @override
  Future<AppendMessageResult> handle(AppendMessageCommand command) async {
    final graph = _graphProvider();
    final chat = graph.get(command.chatId);
    if (chat == null) {
      throw StateError('会话不存在: ${command.chatId}');
    }
    final source = graph.get(chat.references['source'] ?? '');
    graph.save(
      chat.copyWith(
        content: appendMessage(
          content: chat.content,
          role: ChatRole.user,
          text: command.message,
          chatTitle: source?.title ?? chat.title,
        ),
      ),
    );
    return AppendMessageResult(affectedNodeIds: <String>{command.chatId});
  }
}

/// AI 回复 Handler（**长任务**，03 §四）：provider 调用 async 不阻塞 UI，
/// 结果通过写路径落盘（自然触发写后通知 → 对话重渲染）。
///
/// M7.3（Function Calling）：注册表非空 → 工具循环（complete 带 tools，
/// 模型可调用节点操作工具——经 CommandBus dispatch 判据①，写后通知
/// 让画布/树实时反映）；注册表空/无工具 → 旧 generate 路径（回归兼容）。
class AskAIHandler extends CommandHandler<AskAICommand, AskAIResult> {
  /// 注入结构存储、LLM 后端、工具注册表与命令总线（延迟解析；
  /// 后两者可空 = 无工具模式，兼容旧装配）。
  AskAIHandler({
    required Graph Function() graphProvider,
    required AIProvider Function() providerProvider,
    AIToolRegistry Function()? toolRegistryProvider,
    CommandBus Function()? commandBusProvider,
  }) : _graphProvider = graphProvider,
       _providerProvider = providerProvider,
       _toolRegistryProvider = toolRegistryProvider,
       _commandBusProvider = commandBusProvider;

  final Graph Function() _graphProvider;
  final AIProvider Function() _providerProvider;
  final AIToolRegistry Function()? _toolRegistryProvider;
  final CommandBus Function()? _commandBusProvider;

  @override
  Type get commandType => AskAICommand;

  @override
  Future<AskAIResult> handle(AskAICommand command) async {
    final graph = _graphProvider();
    final chat = graph.get(command.chatId);
    if (chat == null) {
      throw StateError('会话不存在: ${command.chatId}');
    }
    final source = graph.get(chat.references['source'] ?? '');
    if (source == null) {
      throw StateError('会话源笔记不存在: ${command.chatId}');
    }
    // 1. 构造上下文 prompt：会话记录 + 源笔记内容。
    final transcript = parseMessages(chat.content)
        .map((m) => '${m.role == ChatRole.user ? '用户' : 'AI'}: ${m.text}')
        .join('\n');
    final context = source.content?.trim();
    final prompt = [
      if (context != null && context.isNotEmpty) '笔记内容:\n$context\n',
      if (transcript.isNotEmpty) '对话记录:\n$transcript',
      '请针对笔记内容继续对话。',
    ].join('\n');
    // 2. 长任务：AIProvider 回复（async，不阻塞 UI）。
    final provider = _providerProvider();
    final tools =
        _toolRegistryProvider?.call().getAllTools() ?? const <AITool>[];
    final reply = tools.isEmpty
        ? await provider.generate(prompt)
        : await _runWithTools(
            provider,
            prompt,
            tools,
            graph,
            command.chatId,
            source,
          );
    // 3. 回复落盘（写路径 → 写后通知 → 对话重渲染；重读最新——
    // 工具循环期间 content 已多次追加，旧快照会互相覆盖）。
    final latest = graph.get(command.chatId) ?? chat;
    graph.save(
      latest.copyWith(
        content: appendMessage(
          content: latest.content,
          role: ChatRole.ai,
          text: reply,
          chatTitle: source.title,
        ),
      ),
    );
    return AskAIResult(affectedNodeIds: <String>{command.chatId});
  }

  /// 工具循环（工具调用/结果以 AI 角色文本落盘——可读、可 diff；
  /// 最终回复由调用方统一落盘）。**每次落盘重读最新 chat**——工具
  /// 循环期间 content 多次追加，陈旧快照会互相覆盖（M7.3 实测坑）。
  Future<String> _runWithTools(
    AIProvider provider,
    String prompt,
    List<AITool> tools,
    Graph graph,
    String chatId,
    Node source,
  ) async {
    const loop = FunctionCallingLoop();
    return loop.run(
      provider: provider,
      history: <AIMessage>[AIMessage(role: 'user', content: prompt)],
      tools: tools,
      executeTool: (tool, arguments) async {
        // R13 与 P0-1 一致：生产装配必经注入的 _commandBusProvider 运行时求值
        // （01 #47）；单插件测试可能未注入——此处显式断言即装配快速失败。
        final commandBus = _commandBusProvider!();
        final current = graph.get(chatId);
        if (current != null) {
          // 工具调用记录（AI 角色文本）。
          graph.save(
            current.copyWith(
              content: appendMessage(
                content: current.content,
                role: ChatRole.ai,
                text: '调用工具「${tool.name}」 参数: ${jsonEncode(arguments)}',
                chatTitle: source.title,
              ),
            ),
          );
          // P0-1（audit-node_ai #1 落实）：中间转录显式广播——长任务期间
          // 对话随工具步骤增量重绘（ChangeKind.data 定向重绘 chat Hook），
          // 不再等最终回复一次性刷新。PluginCommandBus.notifyListeners 与
          // dispatch 完成后的广播同语义（写后通知通道，见 core
          // plugin_command_bus.dart）。
          (commandBus as PluginCommandBus).notifyListeners(
            AskAIResult(affectedNodeIds: <String>{chatId}),
          );
        }
        final result = await tool.execute(
          arguments,
          AIToolContext(commandBus: commandBus, graph: graph),
        );
        final latest = graph.get(chatId);
        if (latest != null) {
          // 工具结果记录。
          graph.save(
            latest.copyWith(
              content: appendMessage(
                content: latest.content,
                role: ChatRole.ai,
                text: '工具结果: ${jsonEncode(result.toAIFriendlyFormat())}',
                chatTitle: source.title,
              ),
            ),
          );
          // P0-1（同上）：工具结果转录后同样显式广播（写后通知通道，
          // 语义同前注——notifyListeners 与 dispatch 完成后的广播一致）。
          (commandBus as PluginCommandBus).notifyListeners(
            AskAIResult(affectedNodeIds: <String>{chatId}),
          );
        }
        return result;
      },
    );
  }
}
