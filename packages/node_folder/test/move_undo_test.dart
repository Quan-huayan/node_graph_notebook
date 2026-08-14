/// 移动撤销测试（P1-2，03 §四 撤销契约）：
///
/// MoveNodes 的对偶：有原父级 → 移回；无原父级（新建 contain）→
/// UncontainCommand 删除 contain 实例恢复"无归属"；幂等移动 → 不可撤销。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_folder/node_folder.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;
  late HostRuntime host;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('ngn_move_undo');
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
      StoredNode(
        id: 'folderB',
        title: '文件夹B',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(id: 'noteA', title: '笔记A', createdAt: now, updatedAt: now),
    ].forEach(host.graph.save);
    await host.start(plugins: <Plugin>[FolderPlugin()], rootNodeId: 'root');
  });

  test('有原父级：inverse = 移回原文件夹', () async {
    await host.commandBus.dispatch<MoveNodesCommand, MoveNodesResult>(
      const MoveNodesCommand(containerId: 'folderA', childId: 'noteA'),
    );
    final result = await host.commandBus
        .dispatch<MoveNodesCommand, MoveNodesResult>(
          const MoveNodesCommand(containerId: 'folderB', childId: 'noteA'),
        );
    expect(result.inverse, isA<MoveNodesCommand>());
    expect((result.inverse! as MoveNodesCommand).containerId, 'folderA');

    await host.commandBus.executeRaw(result.inverse!);
    final contain = host.graph
        .getAll()
        .firstWhere((n) => n.references['child'] == 'noteA');
    expect(contain.references['parent'], 'folderA');
  });

  test('无原父级：inverse = UncontainCommand（删除 contain 恢复无归属）', () async {
    final result = await host.commandBus
        .dispatch<MoveNodesCommand, MoveNodesResult>(
          const MoveNodesCommand(containerId: 'folderA', childId: 'noteA'),
        );
    expect(result.inverse, isA<UncontainCommand>());

    await host.commandBus.executeRaw(result.inverse!);
    final contain = host.graph
        .getAll()
        .where((n) => n.references['child'] == 'noteA')
        .firstOrNull;
    expect(contain, isNull);
  });

  test('幂等移动（已在目标容器）：inverse null', () async {
    await host.commandBus.dispatch<MoveNodesCommand, MoveNodesResult>(
      const MoveNodesCommand(containerId: 'folderA', childId: 'noteA'),
    );
    final result = await host.commandBus
        .dispatch<MoveNodesCommand, MoveNodesResult>(
          const MoveNodesCommand(containerId: 'folderA', childId: 'noteA'),
        );
    expect(result.inverse, isNull);
  });
}
