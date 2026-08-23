/// C4 状态栏测试（Obsidian 状态栏语义）：节点计数（剔除 UI 代理——
/// toolbar-root/toolbar/面板等呈现节点不进计数）+ 单仓库模式不显示
/// 仓库名（多仓库名走 _vaultSwitcher，本测试只验壳级底线）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_folder/node_folder.dart';
import 'package:plugon/plugon.dart';

void main() {
  testWidgets('C4 状态栏：节点数不含 UI 代理，单仓库无仓库名', (tester) async {
    final root = Directory.systemTemp.createTempSync('ngn_status_bar');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    // 知识节点：root（folder）+ 2 笔记 = 3；UI 代理（toolbar-root/按钮/
    // tags-panel 实例）不应计入（isUiProxy 判定——呈现节点非笔记）。
    <StoredNode>[
      StoredNode(
        id: 'root',
        title: '根目录',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(id: 'a', title: '笔记A', createdAt: now, updatedAt: now),
      StoredNode(id: 'b', title: '笔记B', createdAt: now, updatedAt: now),
      StoredNode(
        id: 'toolbar-root',
        title: '工具栏',
        metadata: const <String, dynamic>{'kind': 'toolbar-root'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'toolbar-btn',
        title: '按钮',
        metadata: const <String, dynamic>{
          'kind': 'toolbar',
          'action': 'canvas.manage',
        },
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    await host.start(
      plugins: <Plugin>[FolderPlugin(servicesProvider: () => host.serviceProvider)],
      rootNodeId: 'root',
    );

    await tester.pumpWidget(
      MaterialApp(home: AppShell(host: host, rootNodeId: 'root')),
    );
    await tester.pump();

    // 计数 = 3（folder + 2 笔记；toolbar-root/按钮被 isUiProxy 剔除）。
    expect(find.text('3 个节点'), findsOneWidget);
    // 单仓库（vaultManager == null）→ 状态栏无仓库名。
    expect(find.textContaining('仓库：'), findsNothing);
  });
}