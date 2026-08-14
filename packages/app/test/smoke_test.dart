/// Smoke 测试：应用壳（AppShell）可启动（HostRuntime + Hook 渲染不崩溃）。
///
/// M7 修正（app 零 UI）：应用壳在 appframe（Hook 承载 UI）——
/// sidebar = FolderHook 渲染文件夹树；画布 = CanvasHook 渲染 GraphCanvas。
/// 断言：侧边栏渲染文件夹；画布渲染有位置的成员卡片；工具栏按钮
/// （UI 节点）渲染。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_folder/node_folder.dart';
import 'package:node_graph/node_graph.dart';
import 'package:plugon/plugon.dart';

void main() {
  testWidgets('应用壳启动并渲染 sidebar + 画布 + 工具栏', (tester) async {
    final root = Directory.systemTemp.createTempSync('ngn_smoke');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    host.graph
      ..save(
        StoredNode(
          id: 'root',
          title: '根目录',
          metadata: const <String, dynamic>{'kind': 'folder'},
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..save(
        StoredNode(
          id: 'canvas',
          title: '画布',
          metadata: const <String, dynamic>{'kind': 'canvas'},
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..save(
        StoredNode(id: 'noteB', title: '笔记B', createdAt: now, updatedAt: now),
      )
      // M7.2：工具栏容器节点（容器 Hook 自动枚举子级按钮）。
      ..save(
        StoredNode(
          id: 'toolbar-root',
          title: '工具栏',
          metadata: const <String, dynamic>{'kind': 'toolbar-root'},
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..save(
        StoredNode(
          id: 'toolbar-test',
          title: '测试按钮',
          metadata: const <String, dynamic>{
            'kind': 'toolbar',
            'icon': 'settings',
            'tooltip': '测试',
            'action': 'no.such',
          },
          createdAt: now,
          updatedAt: now,
        ),
      );
    // 画布成员 = 外观位置（判据②）。
    host.uiStateStore.set(canvasPositionKey('noteB'), <String, dynamic>{
      'x': 100,
      'y': 100,
    });
    // servicesProvider：宿主最新 provider 入口（M7 修正，见 main.dart）。
    ServiceProvider resolveServices() => host.serviceProvider;
    await host.start(
      plugins: <Plugin>[
        FolderPlugin(servicesProvider: resolveServices),
        GraphPlugin(servicesProvider: resolveServices),
      ],
      rootNodeId: 'root',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(host: host, rootNodeId: 'root'),
      ),
    );
    await tester.pump();

    // 侧边栏 = Hook 树递归（FolderHook → FolderView 容器 →
    // 子级 HookView 递归）：根目录容器 + 未归类区。
    expect(find.text('根目录'), findsWidgets);
    expect(find.text('未归类笔记'), findsWidgets);
    // 画布渲染有位置的成员卡片（CanvasHook → GraphCanvas）。
    expect(
      find.descendant(of: find.byType(GraphCanvas), matching: find.text('笔记B')),
      findsOneWidget,
    );
    // 工具栏按钮（UI 节点 → ToolbarHook → IconButton）。
    expect(find.byTooltip('测试'), findsOneWidget);

    // M7.1（UIManager 事件驱动端到端）：改标题（data 写）→ 画布卡片
    // 定向更新（成员经物化 Hook 渲染；侧栏未归类区兜底 Hook 空呈现）。
    await host.commandBus.dispatch<UpdateNodeCommand, UpdateNodeResult>(
      UpdateNodeCommand(nodeId: 'noteB', title: '改名笔记B', content: 'x'),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(GraphCanvas),
        matching: find.text('改名笔记B'),
      ),
      findsOneWidget,
    );
  });
}
