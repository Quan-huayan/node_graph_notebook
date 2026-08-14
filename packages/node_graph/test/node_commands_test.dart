/// 节点操作命令测试（M6 graph 插件）：
///
/// 创建/更新/删除/连接——纯 DTO + Handler（03 §四），CommandBus 路由。
/// 不变量断言：删除级联（引用实例 + 位置键）、连接 = L1 实例（无向幂等）、
/// 自连接拒绝（环校验）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph/node_graph.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;
  late HostRuntime host;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('ngn_cmds');
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
        id: 'canvas',
        title: '画布',
        metadata: const <String, dynamic>{'kind': 'canvas'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(id: 'noteA', title: '笔记A', createdAt: now, updatedAt: now),
      StoredNode(id: 'noteB', title: '笔记B', createdAt: now, updatedAt: now),
    ].forEach(host.graph.save);
    host.uiStateStore
      ..set(canvasPositionKey('noteA'), <String, dynamic>{'x': 100, 'y': 100})
      ..set(canvasPositionKey('noteB'), <String, dynamic>{'x': 300, 'y': 200});
    await host.start(plugins: <Plugin>[GraphPlugin()], rootNodeId: 'root');
  });

  test('CreateNode：落盘 + 写结果', () async {
    final result = await host.commandBus
        .dispatch<CreateNodeCommand, CreateNodeResult>(
          const CreateNodeCommand(id: 'n1', title: '新笔记', content: '正文'),
        );
    expect(result.affectedNodeIds, <String>{'n1'});
    final node = host.graph.get('n1')!;
    expect(node.title, '新笔记');
    expect(node.content, '正文');
  });

  test('UpdateNode：标题/内容更新（data 粒度）', () async {
    final result = await host.commandBus
        .dispatch<UpdateNodeCommand, UpdateNodeResult>(
          const UpdateNodeCommand(nodeId: 'noteA', title: '改名了'),
        );
    expect(result.changeKind, ChangeKind.data);
    expect(host.graph.get('noteA')!.title, '改名了');
    expect(host.graph.get('noteA')!.content, isNull);
  });

  test('UpdateNode：不存在的节点 → StateError', () async {
    expect(
      () => host.commandBus.dispatch<UpdateNodeCommand, UpdateNodeResult>(
        const UpdateNodeCommand(nodeId: 'ghost'),
      ),
      throwsStateError,
    );
  });

  test('DeleteNode：级联删除引用实例 + 位置键清理', () async {
    // 造关系实例：contain（parent/child）与 connect（from/to）引用 noteA。
    final now = DateTime.now();
    host.graph.save(
      StoredNode(
        id: 'contain-x',
        title: 'contain:x',
        references: const <String, String>{'parent': 'root', 'child': 'noteA'},
        createdAt: now,
        updatedAt: now,
      ),
    );
    host.graph.save(
      StoredNode(
        id: 'conn-x',
        title: 'connect:x',
        references: const <String, String>{'from': 'noteA', 'to': 'noteB'},
        createdAt: now,
        updatedAt: now,
      ),
    );

    final result = await host.commandBus
        .dispatch<DeleteNodeCommand, DeleteNodeResult>(
          const DeleteNodeCommand(nodeId: 'noteA'),
        );

    expect(
      result.affectedNodeIds,
      containsAll(<String>['noteA', 'contain-x', 'conn-x']),
    );
    expect(host.graph.get('noteA'), isNull);
    expect(host.graph.get('contain-x'), isNull);
    expect(host.graph.get('conn-x'), isNull);
    expect(host.graph.get('noteB'), isNotNull); // 无辜节点不受牵连。
    // 位置键同步清理（判据② 外观与结构删除一致）。
    expect(host.uiStateStore.get(canvasPositionKey('noteA')), isNull);
  });

  test('ConnectNodes：创建连接实例（L1，references {from,to}）', () async {
    final result = await host.commandBus
        .dispatch<ConnectNodesCommand, ConnectNodesResult>(
          const ConnectNodesCommand(from: 'noteA', to: 'noteB'),
        );
    expect(result.affectedNodeIds, containsAll(<String>['noteA', 'noteB']));
    final conn = host.graph.getAll().firstWhere(
      (n) => const ConnectionConcept().validate(n),
    );
    expect(conn.references, <String, String>{'from': 'noteA', 'to': 'noteB'});
    // 无向：两端自身零引用（L0 不被修改）。
    expect(host.graph.get('noteA')!.references, isEmpty);
    expect(host.graph.get('noteB')!.references, isEmpty);
  });

  test('ConnectNodes：反向连接幂等（无向边）', () async {
    await host.commandBus.dispatch<ConnectNodesCommand, ConnectNodesResult>(
      const ConnectNodesCommand(from: 'noteA', to: 'noteB'),
    );
    final count = host.graph
        .getAll()
        .where((n) => const ConnectionConcept().validate(n))
        .length;
    await host.commandBus.dispatch<ConnectNodesCommand, ConnectNodesResult>(
      const ConnectNodesCommand(from: 'noteB', to: 'noteA'),
    );
    expect(
      host.graph
          .getAll()
          .where((n) => const ConnectionConcept().validate(n))
          .length,
      count,
    );
  });

  test('ConnectNodes：自连接 → CycleError（环校验）', () async {
    expect(
      () => host.commandBus.dispatch<ConnectNodesCommand, ConnectNodesResult>(
        const ConnectNodesCommand(from: 'noteA', to: 'noteA'),
      ),
      throwsA(isA<CycleError>()),
    );
  });

  test('ConnectionConcept：结构匹配（{from,to} 完整，多余键拒绝）', () {
    const concept = ConnectionConcept();
    expect(
      concept.validate(
        FallbackNode(
          id: 'c',
          title: 'c',
          references: const <String, String>{'from': 'a', 'to': 'b'},
        ),
      ),
      isTrue,
    );
    expect(
      concept.validate(
        FallbackNode(
          id: 'c',
          title: 'c',
          references: const <String, String>{'from': 'a'},
        ),
      ),
      isFalse,
    );
    expect(
      concept.validate(
        FallbackNode(
          id: 'c',
          title: 'c',
          references: const <String, String>{
            'from': 'a',
            'to': 'b',
            'extra': 'c',
          },
        ),
      ),
      isFalse,
    );
  });

  group('P1-2 撤销契约（inverse 往返）', () {
    test('UpdateNode：inverse 恢复旧标题/内容', () async {
      final result = await host.commandBus
          .dispatch<UpdateNodeCommand, UpdateNodeResult>(
            const UpdateNodeCommand(nodeId: 'noteA', title: '新标题'),
          );
      final inverse = result.inverse;
      expect(inverse, isA<UpdateNodeCommand>());
      await host.commandBus.executeRaw(inverse!);
      expect(host.graph.get('noteA')!.title, '笔记A');
    });

    test('CreateNode：inverse = 删除；执行后节点消失', () async {
      final result = await host.commandBus
          .dispatch<CreateNodeCommand, CreateNodeResult>(
            const CreateNodeCommand(id: 'n9', title: '临时'),
          );
      await host.commandBus.executeRaw(result.inverse!);
      expect(host.graph.get('n9'), isNull);
    });

    test('DeleteNode：inverse 恢复节点 + 级联关系实例 + 位置键', () async {
      // 先建 contain 关系实例（引用 noteA——删除时被级联）。
      final now = DateTime.now();
      host.graph.save(
        StoredNode(
          id: 'contain-x',
          title: 'contain:x',
          references: const <String, String>{'parent': 'root', 'child': 'noteA'},
          createdAt: now,
          updatedAt: now,
        ),
      );
      final result = await host.commandBus
          .dispatch<DeleteNodeCommand, DeleteNodeResult>(
            const DeleteNodeCommand(nodeId: 'noteA'),
          );
      expect(host.graph.get('noteA'), isNull);
      expect(host.graph.get('contain-x'), isNull);
      expect(host.uiStateStore.get(canvasPositionKey('noteA')), isNull);

      final inverse = result.inverse;
      expect(inverse, isA<RestoreNodeCommand>());
      await host.commandBus.executeRaw(inverse!);

      expect(host.graph.get('noteA')!.title, '笔记A');
      expect(host.graph.get('contain-x'), isNotNull);
      expect(
        host.uiStateStore.get(canvasPositionKey('noteA')),
        <String, dynamic>{'x': 100, 'y': 100},
      );
    });

    test('ConnectNodes：inverse = 删除连接实例', () async {
      final result = await host.commandBus
          .dispatch<ConnectNodesCommand, ConnectNodesResult>(
            const ConnectNodesCommand(from: 'noteA', to: 'noteB'),
          );
      await host.commandBus.executeRaw(result.inverse!);
      expect(host.graph.get('conn-noteA-noteB'), isNull);
    });

    test('总线撤销栈全链路：dispatch 自动 record → undo/redo 往返', () async {
      await host.commandBus
          .dispatch<UpdateNodeCommand, UpdateNodeResult>(
            const UpdateNodeCommand(nodeId: 'noteA', title: '撤销前'),
          );
      expect(host.undoManager.canUndo, isTrue);

      await host.undoManager.undo();
      expect(host.graph.get('noteA')!.title, '笔记A');
      expect(host.undoManager.canRedo, isTrue);

      await host.undoManager.redo();
      expect(host.graph.get('noteA')!.title, '撤销前');
    });
  });
}
