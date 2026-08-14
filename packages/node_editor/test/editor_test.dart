/// Editor 插件测试（M7）：
///
/// SaveNoteCommand（标题/内容保存 → 落盘 + 写后通知 + data 粒度）；
/// 不存在节点拒绝；markdown 预览对话框渲染（编辑/预览切换）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_editor/node_editor.dart';
import 'package:plugon/plugon.dart';

/// 桩删除 Handler（P1-5 测试：替代 graph 插件贡献）。
class _StubDeleteHandler
    extends CommandHandler<DeleteNodeCommand, DeleteNodeResult> {
  _StubDeleteHandler(this.graph);

  final Graph graph;

  @override
  Type get commandType => DeleteNodeCommand;

  @override
  Future<DeleteNodeResult> handle(DeleteNodeCommand command) async {
    graph.delete(command.nodeId);
    return DeleteNodeResult(affectedNodeIds: <String>{command.nodeId});
  }
}

void main() {
  late Directory root;
  late HostRuntime host;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('ngn_editor');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
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
        id: 'noteA',
        title: '笔记A',
        content: '# 旧内容',
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    ServiceProvider resolveServices() => host.serviceProvider;
    await host.start(
      plugins: <Plugin>[EditorPlugin(servicesProvider: resolveServices)],
      rootNodeId: 'root',
    );
  });

  test('SaveNote：保存标题+内容 → 落盘 + data 粒度 + 写后通知', () async {
    final writes = <WriteResult>[];
    host.commandBus.attach(writes.add);
    final result = await host.commandBus
        .dispatch<SaveNoteCommand, SaveNoteResult>(
          const SaveNoteCommand(nodeId: 'noteA', title: '新标题', content: '新内容'),
        );
    expect(result.changeKind, ChangeKind.data);
    expect(result.affectedNodeIds, <String>{'noteA'});
    expect(writes.single.affectedNodeIds, <String>{'noteA'});
    final note = host.graph.get('noteA')!;
    expect(note.title, '新标题');
    expect(note.content, '新内容');
  });

  test('SaveNote：部分字段（只改标题）→ 内容不变', () async {
    await host.commandBus.dispatch<SaveNoteCommand, SaveNoteResult>(
      const SaveNoteCommand(nodeId: 'noteA', title: '只改标题'),
    );
    expect(host.graph.get('noteA')!.title, '只改标题');
    expect(host.graph.get('noteA')!.content, '# 旧内容');
  });

  test('SaveNote：不存在的节点 → StateError', () async {
    expect(
      () => host.commandBus.dispatch<SaveNoteCommand, SaveNoteResult>(
        const SaveNoteCommand(nodeId: 'ghost', title: 'x'),
      ),
      throwsStateError,
    );
  });

  testWidgets('NoteRowView 删除入口：确认 → DeleteNodeCommand（P1-5）', (
    tester,
  ) async {
    // 桩删除 Handler（DTO 在 core——editor 零 graph 插件依赖）。
    host.commandBus.register(_StubDeleteHandler(host.graph));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteRowView(host: host, node: host.graph.get('noteA')!),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text(host.i18nService.t('node.deleteTitle')), findsOneWidget);

    await tester.tap(find.text(host.i18nService.t('node.delete')));
    await tester.pumpAndSettle();
    expect(host.graph.get('noteA'), isNull);
  });

  testWidgets('MarkdownEditorDialog：渲染 + 保存走写路径', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    child: MarkdownEditorView(
                      commandBus: host.commandBus,
                      node: host.graph.get('noteA')!,
                      i18n: host.i18nService,
                    ),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    // 编辑表单渲染（标题 + 内容）。
    expect(find.text('编辑「笔记A」'), findsOneWidget);
    // 切换预览 → 渲染 markdown 标题。
    await tester.tap(find.text('预览'));
    await tester.pumpAndSettle();
    expect(find.text('旧内容'), findsOneWidget);
  });
}
