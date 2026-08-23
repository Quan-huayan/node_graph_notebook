/// C2/C5 测试（node_graph 域）。
///
/// C2 属性面板 = metadata 编辑（UpdateNodeCommand.metadata 整体替换；
/// 对偶撤销恢复旧 metadata；重启后保持——判据②③ 验收线）。
/// C5 最近打开键级联：删除节点 → recent.* 外观键同步清理（Obsidian
/// 最近文件语义：删除后不残留）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph/node_graph.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;
  late HostRuntime host;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('ngn_meta_recent');
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
      StoredNode(id: 'a', title: '笔记A', createdAt: now, updatedAt: now),
    ].forEach(host.graph.save);
    await host.start(
      plugins: <Plugin>[GraphPlugin(servicesProvider: () => host.serviceProvider)],
      rootNodeId: 'root',
    );
  });

  test('C2 属性写：metadata 整体替换 + 对偶撤销恢复旧值', () async {
    final result = await host.commandBus.dispatch<UpdateNodeCommand,
        UpdateNodeResult>(
      const UpdateNodeCommand(
        nodeId: 'a',
        metadata: <String, dynamic>{'tags': <String>['x', 'y']},
      ),
    );
    expect(host.graph.get('a')!.metadata['tags'], <String>['x', 'y']);
    // 对偶 = 恢复旧 metadata（空 map）。
    expect(result.inverse, isA<UpdateNodeCommand>());
    final inverse = result.inverse! as UpdateNodeCommand;
    expect(inverse.metadata, <String, dynamic>{});
    await host.commandBus.executeRaw(inverse);
    expect(
      host.graph.get('a')!.metadata.containsKey('tags'),
      isFalse,
    );
  });

  test('C2 重启保持：metadata 落盘跨 HostRuntime 重启留存（验收 6）', () async {
    await host.commandBus.dispatch<UpdateNodeCommand, UpdateNodeResult>(
      const UpdateNodeCommand(
        nodeId: 'a',
        metadata: <String, dynamic>{'tags': <String>['保持'], 'prio': 1},
      ),
    );
    // 重启（同数据根新 host，重装插件）。
    final host2 = HostRuntime(dataRoot: root);
    await host2.start(
      plugins: <Plugin>[GraphPlugin(servicesProvider: () => host2.serviceProvider)],
      rootNodeId: 'root',
    );
    expect(
      host2.graph.get('a')!.metadata['tags'],
      <String>['保持'],
    );
    expect(host2.graph.get('a')!.metadata['prio'], 1);
  });

  test('C5 级联：删除节点 → recent.* 外观键同步清理', () async {
    // 模拟打开记录（openNodeDialog 写 recent.<ts> → nodeId）。
    host.uiStateStore
      ..set('recent.111', 'a')
      ..set('recent.222', 'a')
      ..set('recent.333', 'other');
    await host.commandBus
        .dispatch<DeleteNodeCommand, DeleteNodeResult>(
      const DeleteNodeCommand(nodeId: 'a'),
    );
    expect(host.graph.get('a'), isNull);
    // 引用 a 的 recent 键全部被删；无关键保留。
    final recent = host.uiStateStore.getByPrefix('recent.');
    expect(recent.containsKey('recent.111'), isFalse);
    expect(recent.containsKey('recent.222'), isFalse);
    expect(recent['recent.333'], 'other');
  });
}