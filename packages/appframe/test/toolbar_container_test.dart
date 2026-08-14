/// 工具栏容器测试（M7.2，E1：00 删除清单"工具栏 = 容器 Node 的 Hook"）。
///
/// ToolbarContainerConcept 自动枚举子级（childNodeIdsOf = 全部
/// ToolbarConcept 命中节点）→ 容器 Hook 渲染按钮行 → 子级 HookView
/// 递归——AppShell 零手扫。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_toolbar');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  testWidgets('工具栏容器自动枚举子级按钮（Hook 递归，非手扫）', (tester) async {
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(id: 'root', title: '根', createdAt: now, updatedAt: now),
      StoredNode(
        id: 'toolbar-root',
        title: '工具栏',
        metadata: const <String, dynamic>{'kind': 'toolbar-root'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'btn-a',
        title: '按钮A',
        metadata: const <String, dynamic>{
          'kind': 'toolbar',
          'icon': 'settings',
          'tooltip': 'A 提示',
          'action': 'no.such.a',
        },
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'btn-b',
        title: '按钮B',
        metadata: const <String, dynamic>{
          'kind': 'toolbar',
          'icon': 'graphic_eq',
          'tooltip': 'B 提示',
          'action': 'no.such.b',
        },
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    await host.start(
      plugins: const <Plugin>[],
      rootNodeId: 'root',
      rootKind: 'sidebar',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: <Widget>[
              HookView(
                host: host,
                nodeId: 'toolbar-root',
                kind: 'toolbar-root',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // 容器自动枚举：两个按钮都渲染（无需手扫/逐个渲染）。
    expect(find.byTooltip('A 提示'), findsOneWidget);
    expect(find.byTooltip('B 提示'), findsOneWidget);
  });

  test('容器语义：childNodeIdsOf = 全部 ToolbarConcept 命中节点', () {
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    final container = StoredNode(
      id: 'toolbar-root',
      title: '工具栏',
      metadata: const <String, dynamic>{'kind': 'toolbar-root'},
      createdAt: now,
      updatedAt: now,
    );
    host.graph
      ..save(container)
      ..save(
        StoredNode(
          id: 'btn-a',
          title: '按钮A',
          metadata: const <String, dynamic>{'kind': 'toolbar'},
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..save(
        StoredNode(id: 'note', title: '笔记', createdAt: now, updatedAt: now),
      );

    final children = const ToolbarContainerConcept()
        .childNodeIdsOf(container, host.graph)!
        .toList();

    expect(children, <String>['btn-a']); // 只枚举按钮，不枚举普通节点。
  });
}
