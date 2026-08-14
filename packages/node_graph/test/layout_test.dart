/// 布局测试（M7.3）：三种算法确定性输出、position 键落盘、
/// changeKind = ui（不发失效事件）、邻接构建（connect/contain 计入）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph/node_graph.dart';
import 'package:plugon/plugon.dart';

/// 种子：canvas + 5 笔记 + 连接/包含关系 + 位置。
Future<HostRuntime> seed(Directory root) async {
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
    StoredNode(id: 'a', title: 'A', createdAt: now, updatedAt: now),
    StoredNode(id: 'b', title: 'B', createdAt: now, updatedAt: now),
    StoredNode(id: 'c', title: 'C', createdAt: now, updatedAt: now),
    StoredNode(id: 'd', title: 'D', createdAt: now, updatedAt: now),
    StoredNode(id: 'e', title: 'E', createdAt: now, updatedAt: now),
    // 连接 a-b、a-c（L1 实例）+ 包含 a 在 canvas（模拟 folder 语义）。
    StoredNode(
      id: 'conn-ab',
      title: '连接',
      references: const <String, String>{'from': 'a', 'to': 'b'},
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'conn-ac',
      title: '连接',
      references: const <String, String>{'from': 'a', 'to': 'c'},
      createdAt: now,
      updatedAt: now,
    ),
  ].forEach(host.graph.save);
  // 成员位置（重叠摆放——布局后应散开）。
  host.uiStateStore
    ..set(canvasPositionKey('a'), <String, dynamic>{'x': 100, 'y': 100})
    ..set(canvasPositionKey('b'), <String, dynamic>{'x': 100, 'y': 100})
    ..set(canvasPositionKey('c'), <String, dynamic>{'x': 100, 'y': 100})
    ..set(canvasPositionKey('d'), <String, dynamic>{'x': 500, 'y': 400})
    ..set(canvasPositionKey('e'), <String, dynamic>{'x': 500, 'y': 400});
  await host.start(plugins: <Plugin>[GraphPlugin()], rootNodeId: 'canvas');
  return host;
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_layout');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  Map<String, Offset> positionsOf(HostRuntime host) {
    final result = <String, Offset>{};
    host.uiStateStore.getByPrefix(canvasPositionPrefix).forEach((key, value) {
      final id = key.substring(canvasPositionPrefix.length);
      final position = parseCanvasPosition(value);
      if (position != null) {
        result[id] = position;
      }
    });
    return result;
  }

  test('力导向：全部成员坐标落盘 + changeKind = ui', () async {
    final host = await seed(root);
    var structureEvents = 0;
    host.uiManager.addListener((event) {
      if (event.changeKind == ChangeKind.structure) {
        structureEvents++;
      }
    });

    final result = await host.commandBus
        .dispatch<ApplyLayoutCommand, ApplyLayoutResult>(
          ApplyLayoutCommand(algorithm: LayoutAlgorithm.force),
        );
    expect(result.changeKind, ChangeKind.ui);
    final positions = positionsOf(host);
    expect(positions.keys.toSet(), <String>{'a', 'b', 'c', 'd', 'e'});
    // 重叠点散开（力导向）。
    final pa = positions['a']!;
    final pb = positions['b']!;
    expect((pa - pb).distance, greaterThan(1), reason: '重叠节点应被斥力分开');
    // 无 NaN。
    for (final p in positions.values) {
      expect(p.dx.isFinite, isTrue);
      expect(p.dy.isFinite, isTrue);
    }
    // ui 变更不发结构失效事件。
    expect(structureEvents, 0);
    // 连接实例（L1）不受布局影响（无位置键）。
    expect(host.graph.get('conn-ab'), isNotNull);
  });

  test('网格：确定性行宽布局', () async {
    final host = await seed(root);
    await host.commandBus.dispatch<ApplyLayoutCommand, ApplyLayoutResult>(
      ApplyLayoutCommand(algorithm: LayoutAlgorithm.grid),
    );
    final positions = positionsOf(host);
    // 5 节点 → 列 = ceil(√5) = 3 → 第 3 行 (0, 320)。
    expect(positions['a'], const Offset(0, 0));
    expect(positions['b'], const Offset(240, 0));
    expect(positions['c'], const Offset(480, 0));
    expect(positions['d'], const Offset(0, 160));
    expect(positions['e'], const Offset(240, 160));
  });

  test('树状：连接 a-b/a-c → 网络分层，b/c 在 a 下一层；全部覆盖', () async {
    final host = await seed(root);
    await host.commandBus.dispatch<ApplyLayoutCommand, ApplyLayoutResult>(
      ApplyLayoutCommand(algorithm: LayoutAlgorithm.tree),
    );
    final positions = positionsOf(host);
    // 无向邻接下无入度集为空 → 分量兜底：排序最小 id（a）为网络根（层 0）；
    // b/c 经连接 → 层 1；d/e 孤立 → 自为根（层 0）。
    expect(positions['a']!.dy, 0);
    expect(positions['b']!.dy, 160);
    expect(positions['c']!.dy, 160);
    expect(positions['d']!.dy, 0);
    expect(positions['e']!.dy, 0);
    // 全部成员覆盖（孤立分量不丢失）。
    expect(positions.keys.toSet(), <String>{'a', 'b', 'c', 'd', 'e'});
  });

  test('增量引擎：只重算影响区域', () async {
    final host = await seed(root);
    final graph = host.graph;
    final nodes = graph.getAll();
    final engine = IncrementalLayoutEngine();
    engine.initializeLayout(nodes, positionsOf(host), <String, List<String>>{
      'a': <String>['b', 'c'],
      'b': <String>['a'],
      'c': <String>['a'],
    });
    // 只标记 a 变化 → 影响区域 = a 及其 2 跳内邻居。
    engine.markChanged(<String>['a']);
    final affected = engine.performIncrementalLayout(
      nodes,
      <String, List<String>>{
        'a': <String>['b', 'c'],
        'b': <String>['a'],
        'c': <String>['a'],
      },
    );
    expect(affected, containsAll(<String>['a', 'b', 'c']));
    // 未受影响节点位置不变。
    final before = positionsOf(host);
    expect(engine.getPosition('d'), before['d']);
  });

  test('目标子集：只布局指定节点', () async {
    final host = await seed(root);
    await host.commandBus.dispatch<ApplyLayoutCommand, ApplyLayoutResult>(
      ApplyLayoutCommand(
        algorithm: LayoutAlgorithm.grid,
        targets: <String>{'a', 'b'},
      ),
    );
    final positions = positionsOf(host);
    expect(positions['a'], const Offset(0, 0));
    expect(positions['b'], const Offset(240, 0));
    // 未指定节点不动。
    expect(positions['c'], const Offset(100, 100));
    expect(positions['d'], const Offset(500, 400));
  });
}
