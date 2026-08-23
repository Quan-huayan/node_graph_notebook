/// 全局图谱测试（C1）：布局纯函数产出位置 + 边；
/// 零 UIStateStore 写（判据② 不触碰——不污染画布外观）。
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
    root = Directory.systemTemp.createTempSync('ngn_global_graph');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    host = HostRuntime(dataRoot: root);
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
      StoredNode(
        id: 'conn-ab',
        title: '连接',
        references: const <String, String>{'from': 'a', 'to': 'b'},
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    await host.start(plugins: <Plugin>[GraphPlugin()], rootNodeId: 'canvas');
  });

  test('C1 全局图谱：位置全节点 + 边来自 connect 实例', () {
    final layout = globalGraphLayout(host.graph);
    // 剔除 UI 代理（canvas）——只含知识节点 a/b。
    expect(layout.positions.keys.toSet(), <String>{'a', 'b'});
    // 连接实例给出无向边 a-b（含 contain/connect 双语义来源）。
    expect(layout.edges, <(String, String)>[('a', 'b')]);
    // 位置非原点（力导向展开过——布局真实生效）。
    expect(layout.positions['a'], isNot(Offset.zero));
    expect(layout.positions['b'], isNot(Offset.zero));
    // 两个节点因引力彼此靠近（距离 < 起始距离的某阈值不存在——
    // 这里只断言有值且可读，具体坐标由引擎决定）。
    expect(layout.positions.values, hasLength(2));
  });

  test('C1 只读断言：布局纯内存——零 UIStateStore 键写入', () {
    // 计算前后外观键数不变（全局图谱不打任何 position.* 键——判据②，
    // 不污染画布外观；本库所有外观键均带 position. 前缀）。
    final before = host.uiStateStore.getByPrefix('position.').length;
    final layout = globalGraphLayout(host.graph);
    expect(layout.positions, isNotEmpty);
    final after = host.uiStateStore.getByPrefix('position.').length;
    expect(after, before);
  });
}