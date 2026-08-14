/// 文件夹打开呈现测试（M7.2，D1 弹框归属：FolderHook 'open' 形态 =
/// FolderContentsView 子级列表——容器打开呈现 = 各 Concept 自己的责任）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_folder/node_folder.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_folderopen');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  testWidgets('打开文件夹（kind=open）→ 子级列表（Hook 递归）', (tester) async {
    final host = HostRuntime(dataRoot: root);
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
        title: '子文件夹B',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'contain-b',
        title: 'contain:folderB',
        references: const <String, String>{
          'parent': 'folderA',
          'child': 'folderB',
        },
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    ServiceProvider resolveServices() => host.serviceProvider;
    await host.start(
      plugins: <Plugin>[FolderPlugin(servicesProvider: resolveServices)],
      rootNodeId: 'root',
      rootKind: 'sidebar',
    );

    // 打开 folderA = 渲染其 'open' Hook（外壳由发起方提供——此处直渲）。
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HookView(host: host, nodeId: 'folderA', kind: 'open'),
        ),
      ),
    );
    await tester.pump();

    // 子级 = Hook 递归（子文件夹平铺为 FolderView）。
    expect(find.text('子文件夹B'), findsOneWidget);
  });

  testWidgets('空文件夹打开 → 占位提示', (tester) async {
    final host = HostRuntime(dataRoot: root);
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
    ].forEach(host.graph.save);
    ServiceProvider resolveServices() => host.serviceProvider;
    await host.start(
      plugins: <Plugin>[FolderPlugin(servicesProvider: resolveServices)],
      rootNodeId: 'root',
      rootKind: 'sidebar',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HookView(host: host, nodeId: 'folderA', kind: 'open'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('（空文件夹）'), findsOneWidget);
  });

  testWidgets('语言切换 → 界面文案即时变化（i18n 壳层，M7.2）', (tester) async {
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(
        id: 'root',
        title: '根目录',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(id: 'note', title: '笔记', createdAt: now, updatedAt: now),
    ].forEach(host.graph.save);
    ServiceProvider resolveServices() => host.serviceProvider;
    await host.start(
      plugins: <Plugin>[FolderPlugin(servicesProvider: resolveServices)],
      rootNodeId: 'root',
      rootKind: 'sidebar',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(host: host, rootNodeId: 'root'),
      ),
    );
    await tester.pump();

    // 中文默认：未归类区标题来自语言包（不再硬编码）。
    expect(find.text('未归类笔记'), findsOneWidget);

    // 切换英文 → 壳级重建 → 文案即时变化（"语言设置形同虚设"修复）。
    host.i18nService.setLanguage(AppLanguage.en);
    await tester.pump();

    expect(find.text('Unfiled notes'), findsOneWidget);
  });
}
