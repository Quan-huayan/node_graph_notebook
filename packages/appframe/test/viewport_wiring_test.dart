/// 视口接线契约测试（P2-4，架构 §5.1 生产接线）：
///
/// HostRuntime 缺省装配 QuadTreeViewportQuery（不再是无视口物化的
/// 空实现）——onViewportChanged 只物化视口内成员，视口外节点保持
/// 未物化（10⁶ 窗口化的机制侧真实行为）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/plugon.dart';

void main() {
  test('缺省视口查询接线：onViewportChanged 只物化视口内成员', () async {
    final root = Directory.systemTemp.createTempSync('ngn_viewport');
    addTearDown(() => root.deleteSync(recursive: true));
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
      StoredNode(id: 'near', title: '近处', createdAt: now, updatedAt: now),
      StoredNode(id: 'far', title: '远处', createdAt: now, updatedAt: now),
    ].forEach(host.graph.save);
    host.uiStateStore.set(canvasPositionKey('near'), const <String, dynamic>{
      'x': 100.0,
      'y': 100.0,
    });
    host.uiStateStore.set(canvasPositionKey('far'), const <String, dynamic>{
      'x': 5000.0,
      'y': 5000.0,
    });

    await host.start(plugins: const <Plugin>[], rootNodeId: 'canvas', rootKind: 'graph');

    // 视口变化 → 视口内物化（兜底 Concept 永不空洞），视口外不物化。
    host.uiManager.onViewportChanged(
      const ValueRect(x: 0, y: 0, width: 800, height: 600),
    );
    expect(host.uiManager.hookFor('near', 'graph'), isNotNull);
    expect(host.uiManager.hookFor('far', 'graph'), isNull);

    // 视口移动 → 远节点物化（索引查询侧真实生效，非空实现）。
    host.uiManager.onViewportChanged(
      const ValueRect(x: 4500, y: 4500, width: 800, height: 600),
    );
    expect(host.uiManager.hookFor('far', 'graph'), isNotNull);
  });
}
