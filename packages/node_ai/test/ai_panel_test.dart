/// AI 面板测试（M7.3）：CreateAIPanelCommand 落盘/幂等/环校验、
/// AIPanelConcept 匹配、侧边栏语义服务覆盖（AI → 面板命令，其他 → null）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_ai/node_ai.dart';
import 'package:plugon/plugon.dart';

/// 种子：root(folder) + aiNode + noteA + AiPlugin。
Future<HostRuntime> seed(Directory root) async {
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
    StoredNode(id: 'noteA', title: '笔记A', createdAt: now, updatedAt: now),
  ].forEach(host.graph.save);
  await host.start(plugins: <Plugin>[AiPlugin()], rootNodeId: 'root');
  return host;
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_ai_panel');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  test('CreateAIPanelCommand：面板落盘 + references + AI 节点零变更', () async {
    final host = await seed(root);
    final result = await host.commandBus
        .dispatch<CreateAIPanelCommand, CreateAIPanelResult>(
          CreateAIPanelCommand(aiNodeId: 'aiNode', sidebarRootId: 'root'),
        );
    expect(result.panelId, 'ai-panel-aiNode');

    final panel = host.graph.get('ai-panel-aiNode')!;
    expect(panel.references['sidebar'], 'root');
    expect(panel.references['ai'], 'aiNode');
    expect(const AIPanelConcept().validate(panel), isTrue);
    // AI 节点零变更（L0 匹配不被破坏）。
    final ai = host.graph.get('aiNode')!;
    expect(ai.references, isEmpty);
    expect(const AIConcept().validate(ai), isTrue);
  });

  test('幂等：同 AI 节点重复钉面板 → 复用同一面板', () async {
    final host = await seed(root);
    final first = await host.commandBus
        .dispatch<CreateAIPanelCommand, CreateAIPanelResult>(
          CreateAIPanelCommand(aiNodeId: 'aiNode', sidebarRootId: 'root'),
        );
    final second = await host.commandBus
        .dispatch<CreateAIPanelCommand, CreateAIPanelResult>(
          CreateAIPanelCommand(aiNodeId: 'aiNode', sidebarRootId: 'root'),
        );
    expect(second.panelId, first.panelId);
    expect(
      host.graph
          .getAll()
          .where((n) => const AIPanelConcept().validate(n))
          .length,
      1,
    );
  });

  test('多 AI 节点 → 多面板实例（零硬编码）', () async {
    final host = await seed(root);
    // 再建一个 AI 节点（多 AI 场景）。
    host.graph.save(
      StoredNode(
        id: 'aiNode2',
        title: '第二个 AI',
        metadata: const <String, dynamic>{'kind': 'ai'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await host.commandBus.dispatch<CreateAIPanelCommand, CreateAIPanelResult>(
      CreateAIPanelCommand(aiNodeId: 'aiNode', sidebarRootId: 'root'),
    );
    await host.commandBus.dispatch<CreateAIPanelCommand, CreateAIPanelResult>(
      CreateAIPanelCommand(aiNodeId: 'aiNode2', sidebarRootId: 'root'),
    );
    final panels = host.graph
        .getAll()
        .where((n) => const AIPanelConcept().validate(n))
        .toList();
    expect(panels.length, 2);
    expect(panels.map((n) => n.references['ai']).toSet(), <String>{
      'aiNode',
      'aiNode2',
    });
  });

  test('chatsOf 反查：面板节点（references.ai 无 source）不得当会话',
      () async {
    // 回归（M7.3 实测崩溃）：面板节点 references {sidebar, ai} 也持有
    // references.ai——不过滤时 `references['source']!` 空值崩溃
    // （拖 AI 入侧边栏钉面板后，打开 tab / 结构变更重渲染即崩）。
    final host = await seed(root);
    await host.commandBus.dispatch<CreateAIPanelCommand, CreateAIPanelResult>(
      const CreateAIPanelCommand(aiNodeId: 'aiNode', sidebarRootId: 'root'),
    );
    // 建一个真实会话（拖笔记入 AI）。
    await host.commandBus.dispatch<DropIntoAICommand, DropIntoAIResult>(
      const DropIntoAICommand(aiNodeId: 'aiNode', sourceId: 'noteA'),
    );

    // 不抛、只含真实会话的 source。
    final sources = chatsOf(host.graph, 'aiNode').toList();
    expect(sources, <String>['noteA']);
  });

  test('侧边栏枚举：面板节点 references.sidebar == root → 成为 tab', () async {
    final host = await seed(root);
    await host.commandBus.dispatch<CreateAIPanelCommand, CreateAIPanelResult>(
      CreateAIPanelCommand(aiNodeId: 'aiNode', sidebarRootId: 'root'),
    );
    // SidebarTabsView 枚举条件（references.sidebar == root.id）。
    final panels = host.graph
        .getAll()
        .where((n) => n.references['sidebar'] == 'root')
        .toList();
    expect(panels.length, 1);
    expect(panels.first.id, 'ai-panel-aiNode');
  });

  test('语义服务覆盖：AI 节点 → CreateAIPanelCommand；普通节点 → null', () async {
    final host = await seed(root);
    final semantics = host.serviceProvider.get<SidebarDropSemantics>();
    final aiCommand = semantics(
      draggedNodeId: 'aiNode',
      targetContainerId: 'root',
    );
    expect(aiCommand, isA<CreateAIPanelCommand>());
    expect((aiCommand as CreateAIPanelCommand).sidebarRootId, 'root');
    // 非 AI 节点 → null（folder 默认语义）。
    final noteCommand = semantics(
      draggedNodeId: 'noteA',
      targetContainerId: 'root',
    );
    expect(noteCommand, isNull);
  });

  test('环校验：root 已引用面板 → 面板引用 root 成环 → 拒绝', () async {
    final host = await seed(root);
    // 制造环：root 引用面板 id（已存在的"反向"引用）→ 面板引用
    // {root, aiNode} 使 root → 面板 → root 成环。
    host.graph.save(
      StoredNode(
        id: 'root',
        title: '根',
        references: const <String, String>{'p': 'ai-panel-aiNode'},
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await expectLater(
      host.commandBus.dispatch<CreateAIPanelCommand, CreateAIPanelResult>(
        CreateAIPanelCommand(aiNodeId: 'aiNode', sidebarRootId: 'root'),
      ),
      throwsA(isA<CycleError>()),
    );
    // 面板未落盘（环拒绝，无副作用）。
    expect(host.graph.get('ai-panel-aiNode'), isNull);
  });
}
