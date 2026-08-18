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

  testWidgets('搜索面板：输入过滤（防抖后）→ 结果列表 + 计数', (tester) async {
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

    // 防抖窗口内不触发搜索；停顿 150ms 后出结果。
    await tester.enterText(find.byType(TextField), '第一篇');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('第一篇笔记'), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('第一篇笔记'), findsOneWidget);
    expect(find.text('第二篇笔记'), findsNothing);
    // 结果计数（找到 1 个结果）。
    expect(
      find.text(
        host.i18nService.t('search.resultsCount').replaceFirst('%s', '1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('搜索面板：无匹配 → 空结果文案（区别于未输入）', (tester) async {
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(id: 'noteA', title: '第一篇笔记', createdAt: now, updatedAt: now),
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

    await tester.enterText(find.byType(TextField), '不存在的关键词');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(host.i18nService.t('search.noResults')), findsOneWidget);
  });

  testWidgets('搜索面板：Ctrl+F 信号 → 聚焦输入框（键盘直达）', (tester) async {
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(id: 'noteA', title: '第一篇笔记', createdAt: now, updatedAt: now),
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

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode?.hasFocus, isFalse);

    // 壳层信号（NotebookApp Ctrl+F 触发）→ 输入框获得焦点。
    host.shellSignals.requestSearchFocus();
    await tester.pump();
    expect(field.focusNode?.hasFocus, isTrue);
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
