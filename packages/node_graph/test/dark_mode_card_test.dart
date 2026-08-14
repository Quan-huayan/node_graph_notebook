/// 暗色卡片配色测试（P2-5：暗色模式默认卡片色加暗色变体）。
///
/// kind 默认配色亮度感知：暗色主题下 ai/folder 卡片用深色 tint
/// （对比度合格），浅色主题保持 50 系 pastel；用户自定义样式色
/// 不受亮度影响（显式选择）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph/node_graph.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;
  late HostRuntime host;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('ngn_dark_card');
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
      StoredNode(
        id: 'ai1',
        title: 'AI 节点',
        metadata: const <String, dynamic>{'kind': 'ai'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'folder1',
        title: '文件夹A',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    host.uiStateStore.set(canvasPositionKey('ai1'), const <String, dynamic>{
      'x': 100.0,
      'y': 100.0,
    });
    host.uiStateStore.set(
      canvasPositionKey('folder1'),
      const <String, dynamic>{'x': 300.0, 'y': 100.0},
    );
    await host.start(
      plugins: <Plugin>[GraphPlugin()],
      rootNodeId: 'canvas',
      rootKind: 'graph',
    );
  });

  Future<void> pumpWith(Brightness brightness, WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(body: GraphCanvas(host: host)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('暗色主题：ai/folder 卡片用暗色变体', (tester) async {
    await pumpWith(Brightness.dark, tester);

    final aiCard = tester.widget<Card>(find.widgetWithText(Card, 'AI 节点'));
    final folderCard = tester.widget<Card>(find.widgetWithText(Card, '文件夹A'));
    expect(aiCard.color, const Color(0xFF26263B)); // indigo 暗 tint。
    expect(folderCard.color, const Color(0xFF2A2619)); // amber 暗 tint。
  });

  testWidgets('浅色主题：保持 50 系 pastel', (tester) async {
    await pumpWith(Brightness.light, tester);

    final aiCard = tester.widget<Card>(find.widgetWithText(Card, 'AI 节点'));
    final folderCard = tester.widget<Card>(find.widgetWithText(Card, '文件夹A'));
    expect(aiCard.color, const Color(0xFFE8EAF6)); // indigo 50。
    expect(folderCard.color, const Color(0xFFFFF8E1)); // amber 50。
  });
}
