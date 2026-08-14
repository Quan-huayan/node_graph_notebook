/// 杀手演示端到端验收（00 宪章 / architecture.md §9，M7 AI 落地）。
///
/// 00：「把一篇笔记拖进 AI 节点——它重新解释自己的形态，变成一段对话。
/// 拖进文件夹——它变成列表项。拖上画布——它变成图节点。同一个数据
/// 实体，在不同容器中流动并变形，全程无数据副本。」
///
/// 全链路（app 组合根装配全部插件）：
/// 1. 创建笔记（CreateNodeCommand，判据①）
/// 2. 拖入 folder → contain 实例（结构变更，L1 引用两端）
/// 3. 拖上画布 → 位置直写（判据②，零结构写入）
/// 4. 拖进 AI 节点 → chat 实例（会话创建，L1 引用两端）
/// 5. 发消息 → AppendMessage（用户消息落盘）→ AskAI（Mock 回复落盘）
///    → 对话形态（chat content = markdown 消息记录）
///
/// 不变量断言（00 §4.2/4.3）：笔记在全程零引用修改（无数据副本）、
/// 唯一 owner 唯一存储（结构只进 Graph）、前端结构零持久化。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_ai/node_ai.dart';
import 'package:node_folder/node_folder.dart';
import 'package:node_graph/node_graph.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;
  late HostRuntime host;
  final writes = <WriteResult>[];

  setUp(() async {
    root = Directory.systemTemp.createTempSync('ngn_killerdemo');
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
        id: 'folderA',
        title: '我的文件夹',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'canvas',
        title: '画布',
        metadata: const <String, dynamic>{'kind': 'canvas'},
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
        id: 'contain-root-folderA',
        title: 'contain:folderA',
        references: const <String, String>{
          'parent': 'root',
          'child': 'folderA',
        },
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    // servicesProvider：宿主最新 provider 入口（M7 修正，见 main.dart）。
    ServiceProvider resolveServices() => host.serviceProvider;
    await host.start(
      plugins: <Plugin>[
        FolderPlugin(servicesProvider: resolveServices),
        GraphPlugin(servicesProvider: resolveServices),
        AiPlugin(
          provider: const MockAIProvider(delay: Duration.zero),
          servicesProvider: resolveServices,
        ),
      ],
      rootNodeId: 'root',
    );
    host.commandBus.attach(writes.add);
  });

  test('杀手演示全链路：笔记在容器间流动变形，全程无数据副本', () async {
    // 1. 创建笔记（判据① 数据命令）。
    await host.commandBus.dispatch<CreateNodeCommand, CreateNodeResult>(
      const CreateNodeCommand(id: 'noteX', title: '知识笔记', content: '这是核心知识。'),
    );

    // 2. 拖入 folder（contain 实例，结构变更）。
    await host.commandBus.dispatch<MoveNodesCommand, MoveNodesResult>(
      const MoveNodesCommand(containerId: 'folderA', childId: 'noteX'),
    );
    final contain = host.graph.getAll().firstWhere(
      (n) => n.references['child'] == 'noteX',
    );
    expect(contain.references['parent'], 'folderA');
    expect(childrenOf(host.graph, 'folderA'), contains('noteX'));

    // 3. 拖上画布（判据②：外观位置直写，零结构写入）。
    final structureBefore = host.graph.getAll().length;
    host.uiStateStore.set(canvasPositionKey('noteX'), <String, dynamic>{
      'x': 300,
      'y': 300,
    });
    expect(host.graph.getAll().length, structureBefore); // 无结构写入。
    expect(host.uiStateStore.get(canvasPositionKey('noteX')), <String, dynamic>{
      'x': 300,
      'y': 300,
    });

    // 4. 拖进 AI 节点（chat 实例，会话创建）。
    await host.commandBus.dispatch<DropIntoAICommand, DropIntoAIResult>(
      const DropIntoAICommand(aiNodeId: 'aiNode', sourceId: 'noteX'),
    );
    final chat = chatOfSource(host.graph, 'noteX')!;
    expect(chat.references, <String, String>{
      'ai': 'aiNode',
      'source': 'noteX',
    });

    // 5. 变对话：发送消息 → 用户消息落盘 → Mock 回复落盘。
    await host.commandBus.dispatch<AppendMessageCommand, AppendMessageResult>(
      AppendMessageCommand(chatId: chat.id, message: '请总结这篇笔记'),
    );
    await host.commandBus.dispatch<AskAICommand, AskAIResult>(
      AskAICommand(chatId: chat.id),
    );
    final messages = parseMessages(host.graph.get(chat.id)!.content);
    expect(messages, hasLength(2));
    expect(messages[0].role, ChatRole.user);
    expect(messages[0].text, '请总结这篇笔记');
    expect(messages[1].role, ChatRole.ai);
    expect(messages[1].text, contains('Mock 回复'));

    // ---- 不变量断言（00 §4.2/4.3）----
    // 同一数据实体流动变形：笔记全程零引用修改（无数据副本）。
    final note = host.graph.get('noteX')!;
    expect(note.references, isEmpty);
    expect(note.content, '这是核心知识。');
    expect(note.title, '知识笔记');
    // 唯一 owner 唯一存储：结构（contain/chat 实例）只进 Graph。
    for (final write in writes) {
      expect(write.affectedNodeIds, isNotEmpty);
    }
    // 前端结构零持久化：重启（重建 HostRuntime）后从 Graph 重建会话。
    final contentBeforeRestart = host.graph.get(chat.id)!.content;
    final root2 = Directory.systemTemp.createTempSync('ngn_killerdemo2');
    addTearDown(() {
      if (root2.existsSync()) {
        root2.deleteSync(recursive: true);
      }
    });
    // 同一数据根（root 目录）重建宿主 = 重启恢复（架构 §5.5）。
    final host2 = HostRuntime(dataRoot: root);
    ServiceProvider resolve2() => host2.serviceProvider;
    await host2.start(
      plugins: <Plugin>[
        FolderPlugin(servicesProvider: resolve2),
        GraphPlugin(servicesProvider: resolve2),
        AiPlugin(
          provider: const MockAIProvider(delay: Duration.zero),
          servicesProvider: resolve2,
        ),
      ],
      rootNodeId: 'root',
    );
    final restoredChat = chatOfSource(host2.graph, 'noteX')!;
    expect(restoredChat.references['ai'], 'aiNode');
    expect(restoredChat.content, contentBeforeRestart);
  });
}
