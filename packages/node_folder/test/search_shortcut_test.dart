/// 搜索快捷键测试（P1-4）：ShellSignals → 侧边栏切到搜索面板 tab。
///
/// 判据③：tab 选择是会话态——信号只通知不落盘（UIStateStore 是判据②
/// 外观通道）。本测试验证 node_folder 侧的信号响应（切换动作）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:node_folder/node_folder.dart';

void main() {
  testWidgets('搜索信号 → TabBar 切到搜索面板 tab（index +1）', (tester) async {
    final root = Directory.systemTemp.createTempSync('ngn_tab');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    final rootNode = StoredNode(
      id: 'root',
      title: '根目录',
      metadata: const <String, dynamic>{'kind': 'folder'},
      createdAt: now,
      updatedAt: now,
    );
    host.graph
      ..save(rootNode)
      ..save(
        StoredNode(
          id: 'search-panel',
          title: '搜索',
          references: const <String, String>{'sidebar': 'root'},
          metadata: const <String, dynamic>{'kind': 'search-panel'},
          createdAt: now,
          updatedAt: now,
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SidebarTabsView(host: host, node: rootNode),
        ),
      ),
    );
    // 初始 = 文件夹 tab（index 0）。
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 0);

    // 壳层信号（Ctrl+F 由 NotebookApp 触发）→ 切到搜索 tab。
    host.shellSignals.requestSearchFocus();
    await tester.pumpAndSettle();
    expect(tabBar.controller!.index, 1);
  });
}
