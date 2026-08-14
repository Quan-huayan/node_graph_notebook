/// 画布窗口化渲染测试（P2-4，架构 §7"每帧渲染 ≤ 视口内 Hook 数"
/// 的画布侧落地）：
///
/// - 成员渲染 = 可见集（相机矩阵 × 真实视口矩形 + 边缘余量）；
///   视口外成员不渲染、不物化（命中测试与渲染列表同源）。
/// - 平移后可见集重建：远处成员进入视口即渲染 + 物化，原成员离屏
///   即卸载渲染。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph/node_graph.dart';
import 'package:plugon/plugon.dart';

void main() {
  testWidgets('窗口化渲染：只渲染视口内成员，平移后可见集重建', (tester) async {
    final root = Directory.systemTemp.createTempSync('ngn_canvas_viewport');
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
      StoredNode(id: 'near', title: '近处笔记', createdAt: now, updatedAt: now),
      StoredNode(id: 'far', title: '远处笔记', createdAt: now, updatedAt: now),
    ].forEach(host.graph.save);
    host.uiStateStore.set(canvasPositionKey('near'), const <String, dynamic>{
      'x': 100.0,
      'y': 100.0,
    });
    host.uiStateStore.set(canvasPositionKey('far'), const <String, dynamic>{
      'x': 5000.0,
      'y': 5000.0,
    });
    await host.start(
      plugins: <Plugin>[GraphPlugin()],
      rootNodeId: 'canvas',
      rootKind: 'graph',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GraphCanvas(host: host)),
      ),
    );
    await tester.pump();

    // 初始视口（800×600 + 200 余量）：近处渲染，远处不渲染。
    expect(find.text('近处笔记'), findsOneWidget);
    expect(find.text('远处笔记'), findsNothing);
    // 物化状态与渲染同源：近处已物化，远处未物化。
    expect(host.uiManager.hookFor('near', 'graph'), isNotNull);
    expect(host.uiManager.hookFor('far', 'graph'), isNull);

    // 平移画布：远处进入视口，近处离屏。
    await tester.drag(find.byType(GraphCanvas), const Offset(-4500, -4500));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350)); // 视口推送防抖落定。

    expect(find.text('远处笔记'), findsOneWidget);
    expect(find.text('近处笔记'), findsNothing);
    expect(host.uiManager.hookFor('far', 'graph'), isNotNull);
  });
}
