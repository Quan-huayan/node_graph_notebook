/// 对话命令测试（M7 杀手演示，01 拍板 #30-31）：
///
/// DropIntoAI（创建/更新会话、源不存在拒绝、写后通知）；
/// AppendMessage（用户消息落盘 data 粒度）；
/// AskAI（长任务 Handler：Mock 回复落盘、写后通知、不阻塞）。
/// 不变量：AI 节点/笔记 L0 零引用（拖入不改写笔记本体——无数据副本）、
/// 会话 = L1 实例引用两端、消息走写路径（Hook 不直接写 Graph）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_ai/node_ai.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;
  late HostRuntime host;
  final writes = <WriteResult>[];

  /// 拖入辅助：创建会话并返回 chat 实例 id。
  Future<String> createChat() async {
    await host.commandBus.dispatch<DropIntoAICommand, DropIntoAIResult>(
      const DropIntoAICommand(aiNodeId: 'aiNode', sourceId: 'noteA'),
    );
    return host.graph
        .getAll()
        .firstWhere((n) => n.references['source'] == 'noteA')
        .id;
  }

  setUp(() async {
    root = Directory.systemTemp.createTempSync('ngn_ai');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    writes.clear();
    host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(
        id: 'root',
        title: '根目录',
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
        content: '# 笔记A\n\n这是笔记内容。',
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    await host.start(
      // Mock 零延迟：测试不等待模拟思考。
      plugins: <Plugin>[
        AiPlugin(provider: const MockAIProvider(delay: Duration.zero)),
      ],
      rootNodeId: 'root',
    );
    host.commandBus.attach(writes.add);
  });

  group('DropIntoAI（拖笔记进 AI 节点）', () {
    test('无会话 → 创建 chat 实例（L1 引用两端），笔记零修改', () async {
      final result = await host.commandBus
          .dispatch<DropIntoAICommand, DropIntoAIResult>(
            const DropIntoAICommand(aiNodeId: 'aiNode', sourceId: 'noteA'),
          );
      expect(result.changeKind, ChangeKind.structure);
      // 写后通知（03 §四 WriteNotifier）。
      expect(writes, hasLength(1));
      expect(writes.single.affectedNodeIds, <String>{
        'chat-noteA-aiNode',
        'aiNode',
      });

      final chat = host.graph.get('chat-noteA-aiNode')!;
      expect(chat.references, <String, String>{
        'ai': 'aiNode',
        'source': 'noteA',
      });
      // 不变量（00 §4.2）：拖入不改写笔记本体——无数据副本。
      final note = host.graph.get('noteA')!;
      expect(note.references, isEmpty);
      expect(note.content, '# 笔记A\n\n这是笔记内容。');
      // 会话归属 = 读侧反查。
      expect(chatsOf(host.graph, 'aiNode'), <String>{'noteA'});
    });

    test('已有会话 → 更新 ai（拖到另一 AI 节点）', () async {
      await host.commandBus.dispatch<DropIntoAICommand, DropIntoAIResult>(
        const DropIntoAICommand(aiNodeId: 'aiNode', sourceId: 'noteA'),
      );
      host.graph.save(
        StoredNode(
          id: 'aiNode2',
          title: '另一个 AI',
          metadata: const <String, dynamic>{'kind': 'ai'},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await host.commandBus.dispatch<DropIntoAICommand, DropIntoAIResult>(
        const DropIntoAICommand(aiNodeId: 'aiNode2', sourceId: 'noteA'),
      );
      // 同一 chat 实例，ai 引用更新（同 contain 模式）。
      final chats = host.graph
          .getAll()
          .where((n) => n.references['source'] == 'noteA')
          .toList();
      expect(chats, hasLength(1));
      expect(chats.single.references['ai'], 'aiNode2');
      expect(chatsOf(host.graph, 'aiNode'), isEmpty);
      expect(chatsOf(host.graph, 'aiNode2'), <String>{'noteA'});
    });

    test('源笔记不存在 → StateError（不落盘）', () async {
      expect(
        () => host.commandBus.dispatch<DropIntoAICommand, DropIntoAIResult>(
          const DropIntoAICommand(aiNodeId: 'aiNode', sourceId: 'ghost'),
        ),
        throwsStateError,
      );
      expect(writes, isEmpty);
    });
  });

  group('AppendMessage（快命令：用户消息落盘）', () {
    late String chatId;

    setUp(() async {
      chatId = await createChat();
    });

    test('追加用户消息 → data 粒度 + 写后通知', () async {
      final result = await host.commandBus
          .dispatch<AppendMessageCommand, AppendMessageResult>(
            AppendMessageCommand(chatId: chatId, message: '你好，AI'),
          );
      expect(result.changeKind, ChangeKind.data);
      expect(result.affectedNodeIds, <String>{chatId});
      expect(writes.last.affectedNodeIds, <String>{chatId});

      final content = host.graph.get(chatId)!.content!;
      expect(content, contains('**用户**: 你好，AI'));
    });

    test('会话不存在 → StateError', () async {
      expect(
        () =>
            host.commandBus.dispatch<AppendMessageCommand, AppendMessageResult>(
              const AppendMessageCommand(chatId: 'ghost', message: '你好'),
            ),
        throwsStateError,
      );
    });
  });

  group('AskAI（长任务 Handler，03 §四）', () {
    late String chatId;

    setUp(() async {
      chatId = await createChat();
      await host.commandBus.dispatch<AppendMessageCommand, AppendMessageResult>(
        AppendMessageCommand(chatId: chatId, message: '总结这篇笔记'),
      );
    });

    test('Mock 回复落盘（写路径）+ 写后通知', () async {
      final result = await host.commandBus.dispatch<AskAICommand, AskAIResult>(
        AskAICommand(chatId: chatId),
      );
      expect(result.changeKind, ChangeKind.data);
      expect(result.affectedNodeIds, <String>{chatId});

      final messages = parseMessages(host.graph.get(chatId)!.content);
      expect(messages, hasLength(2));
      expect(messages[0].role, ChatRole.user);
      expect(messages[1].role, ChatRole.ai);
      expect(messages[1].text, contains('Mock 回复'));
      // 写后通知随命令完成到达（DropIntoAI + Append + Ask 各一次）。
      expect(writes, hasLength(3));
    });

    test('长任务完成（async 执行不冻结事件循环）', () async {
      // AskAI 是 Future——dispatch 返回前不冻结事件循环（Mock 延迟 0）。
      final future = host.commandBus.dispatch<AskAICommand, AskAIResult>(
        AskAICommand(chatId: chatId),
      );
      final result = await future;
      expect(result.changeKind, ChangeKind.data);
      expect(parseMessages(host.graph.get(chatId)!.content), hasLength(2));
    });

    test('会话不存在 → StateError（无写入）', () async {
      expect(
        () => host.commandBus.dispatch<AskAICommand, AskAIResult>(
          const AskAICommand(chatId: 'ghost'),
        ),
        throwsStateError,
      );
    });
  });
}
