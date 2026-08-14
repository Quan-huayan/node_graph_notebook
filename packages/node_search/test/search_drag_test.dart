/// 搜索节点三向拖拽测试（M7.3 Flowing UI）：
/// 搜索结果行 = Draggable → 拖到画布 = 卡片（位置键直写）/
/// 拖到工具栏 = 按钮（CreateToolbarButtonCommand）。落点语义全部
/// 复用既有 DragTarget，本测试验证三向链路。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph/node_graph.dart';
import 'package:node_search/node_search.dart';
import 'package:plugon/plugon.dart';

/// 种子：canvas + 工具栏 + 笔记 + 搜索面板（Search + Graph 插件）。
Future<HostRuntime> seed(Directory root) async {
  final host = HostRuntime(dataRoot: root);
  final now = DateTime.now();
  <StoredNode>[
    StoredNode(
      id: 'toolbar-root',
      title: '工具栏',
      metadata: const <String, dynamic>{'kind': 'toolbar-root'},
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'canvas',
      title: '画布',
      metadata: const <String, dynamic>{'kind': 'canvas'},
      createdAt: now,
      updatedAt: now,
    ),
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
    plugins: <Plugin>[GraphPlugin(), SearchPlugin()],
    rootNodeId: 'toolbar-root',
  );
  return host;
}

/// 测试壳：AppBar 工具栏 + 左搜索面板 + 右画布。
class _Harness extends StatelessWidget {
  const _Harness({required this.host});

  final HostRuntime host;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        actions: [
          HookView(host: host, nodeId: 'toolbar-root', kind: 'toolbar-root'),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 240,
            child: HookView(
              host: host,
              nodeId: 'search-panel',
              kind: 'sidebar-panel',
            ),
          ),
          Expanded(child: GraphCanvas(host: host)),
        ],
      ),
    ),
  );
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_search_drag');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  testWidgets('拖搜索结果到画布 → 位置键直写 + 卡片出现', (tester) async {
    final host = await seed(root);
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    // 搜索出 noteA。
    await tester.enterText(find.byType(TextField), '第一篇');
    await tester.pump();
    expect(find.text('第一篇笔记'), findsOneWidget);

    // 拖结果行到画布中心。
    final canvas = find.byType(GraphCanvas);
    final row = find.text('第一篇笔记');
    await tester.drag(row, tester.getCenter(canvas) - tester.getCenter(row));
    await tester.pumpAndSettle();
    // SnackBar 定时器。
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 位置键直写（判据②）——画布成员 = 外观位置。
    expect(
      parseCanvasPosition(host.uiStateStore.get(canvasPositionKey('noteA'))),
      isNotNull,
    );
    expect(
      find.descendant(of: canvas, matching: find.text('第一篇笔记')),
      findsOneWidget,
    );
    // 零结构写入。
    expect(host.graph.get('noteA')!.references, isEmpty);
  });

  testWidgets('拖搜索结果到工具栏 → 按钮节点创建', (tester) async {
    final host = await seed(root);
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '第二篇');
    await tester.pump();
    expect(find.text('第二篇笔记'), findsOneWidget);

    final toolbar = find.byType(ToolbarActionsRow);
    final row = find.text('第二篇笔记');
    await tester.drag(row, tester.getCenter(toolbar) - tester.getCenter(row));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    final button = host.graph.get('toolbar-open-noteB');
    expect(button, isNotNull);
    expect(button!.metadata['action'], 'node.open');
    expect(button.metadata['target'], 'noteB');
    // 按钮出现在工具栏（tooltip = 标题）。
    expect(find.byTooltip('第二篇笔记'), findsOneWidget);
  });

  testWidgets('拖搜索结果到工具栏按钮后点击 → 打开节点对话框', (tester) async {
    final host = await seed(root);
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '第一篇');
    await tester.pump();
    final toolbar = find.byType(ToolbarActionsRow);
    final row = find.text('第一篇笔记');
    await tester.drag(row, tester.getCenter(toolbar) - tester.getCenter(row));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 点击新按钮 → 'node.open' targeted → 节点对话框（笔记 = 编辑器视图）。
    await tester.tap(find.byTooltip('第一篇笔记'));
    await tester.pumpAndSettle();
    // 对话框出现（HookView kind='open' 渲染笔记 Hook）。
    expect(find.byType(Dialog), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
