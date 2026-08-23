/// 文件夹内新建测试（B3，01-D 写路径 + P1-2 对偶撤销）。
///
/// 覆盖：笔记 + contain 实例双写落盘；一步撤销（inverse = DeleteNodeCommand
/// 级联删 contain，UndoManager Ctrl+Z 闭合）；目标文件夹不存在 → 失败可见。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_folder/node_folder.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;
  late HostRuntime host;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('ngn_folder_create');
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
        id: 'folderA',
        title: '文件夹A',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    await host.start(plugins: <Plugin>[FolderPlugin()], rootNodeId: 'root');
  });

  test('文件夹内新建：笔记 + contain 实例双写落盘', () async {
    final result = await host.commandBus.dispatch<
        CreateNodeInFolderCommand, CreateNodeInFolderResult>(
      const CreateNodeInFolderCommand(
        folderId: 'folderA',
        id: 'new-note',
        title: '新笔记',
        content: '正文',
      ),
    );
    final note = host.graph.get('new-note');
    expect(note, isNotNull);
    expect(note!.title, '新笔记');
    expect(note.content, '正文');
    // contain 实例（L1 引用两端——读侧反查落地）。
    final contain = host.graph
        .getAll()
        .firstWhere((n) => n.references['child'] == 'new-note');
    expect(contain.references['parent'], 'folderA');
    expect(
      result.affectedNodeIds,
      containsAll(<String>{'new-note', 'folderA'}),
    );
    // 一步撤销：删除新笔记（级联删 contain）。
    expect(result.inverse, isA<DeleteNodeCommand>());
    expect((result.inverse! as DeleteNodeCommand).nodeId, 'new-note');
  });

  test('目标文件夹不存在 → 抛错（架构 §8 失败可见）', () async {
    await expectLater(
      host.commandBus.dispatch<CreateNodeInFolderCommand,
          CreateNodeInFolderResult>(
        const CreateNodeInFolderCommand(
          folderId: 'missing',
          id: 'new-note',
          title: '新笔记',
        ),
      ),
      throwsA(isA<StateError>()),
    );
    expect(host.graph.get('new-note'), isNull);
  });
}