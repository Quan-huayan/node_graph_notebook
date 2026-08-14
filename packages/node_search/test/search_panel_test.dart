/// 搜索面板测试（M7.2：搜索在侧边栏 Tab——输入过滤 → 结果 → 打开）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_search/node_search.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_search');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  testWidgets('搜索面板：输入过滤 → 结果列表', (tester) async {
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(id: 'noteA', title: '第一篇笔记', createdAt: now, updatedAt: now),
      StoredNode(id: 'noteB', title: '第二篇笔记', createdAt: now, updatedAt: now),
      StoredNode(
        id: 'search-panel',
        title: '搜索',
        references: const <String, String>{'sidebar': 'root'},
        metadata: const <String, dynamic>{'kind': 'search-panel'},
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    await host.start(
      plugins: <Plugin>[SearchPlugin()],
      rootNodeId: 'noteA',
      rootKind: 'sidebar',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HookView(
            host: host,
            nodeId: 'search-panel',
            kind: 'sidebar-panel',
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '第一篇');
    await tester.pump();
    expect(find.text('第一篇笔记'), findsOneWidget);
    expect(find.text('第二篇笔记'), findsNothing);
  });

  testWidgets('搜索面板 Concept：结构匹配（kind + references.sidebar）', (tester) async {
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    host.graph.save(
      StoredNode(
        id: 'panel',
        title: '搜索',
        references: const <String, String>{'sidebar': 'root'},
        metadata: const <String, dynamic>{'kind': 'search-panel'},
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(
      const SearchPanelConcept().validate(host.graph.get('panel')!),
      isTrue,
    );
  });
}
