/// 设置容器测试（M7.2 阶段 C：设置聚合 = Hook Tree——容器节点 +
/// references 反查枚举子级，零新扩展点）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_settings/node_settings.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_settings');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  test('容器语义：子级 = references.settings == 容器 id 反查', () {
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    final container = StoredNode(
      id: 'settings-root',
      title: '设置',
      metadata: const <String, dynamic>{'kind': 'settings-root'},
      createdAt: now,
      updatedAt: now,
    );
    host.graph
      ..save(container)
      ..save(
        StoredNode(
          id: 'settings-theme',
          title: '主题',
          references: const <String, String>{'settings': 'settings-root'},
          metadata: const <String, dynamic>{'kind': 'settings-theme'},
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..save(
        StoredNode(id: 'note', title: '笔记', createdAt: now, updatedAt: now),
      );

    final children = const SettingsContainerConcept()
        .childNodeIdsOf(container, host.graph)!
        .toList();

    expect(children, <String>['settings-theme']); // 只枚举指向容器的条目。
  });

  testWidgets('打开设置容器 → 条目列表（子 Hook 递归）', (tester) async {
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(
        id: 'settings-root',
        title: '设置',
        metadata: const <String, dynamic>{'kind': 'settings-root'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'settings-theme',
        title: '主题',
        references: const <String, String>{'settings': 'settings-root'},
        metadata: const <String, dynamic>{'kind': 'settings-theme'},
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    ServiceProvider resolveServices() => host.serviceProvider;
    await host.start(
      plugins: <Plugin>[SettingsPlugin(servicesProvider: resolveServices)],
      rootNodeId: 'settings-root',
      rootKind: 'sidebar',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HookView(host: host, nodeId: 'settings-root', kind: 'open'),
        ),
      ),
    );
    await tester.pump();

    // 条目行 = 子 Hook sidebar 形态（主题条目行）。
    expect(find.text('主题'), findsOneWidget);
  });
}
