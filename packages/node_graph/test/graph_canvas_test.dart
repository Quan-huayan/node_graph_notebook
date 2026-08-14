/// GraphCanvas 端到端测试（M6 graph 插件验收，00 杀手演示"拖上画布→图节点"）。
///
/// 场景：成员 = 外观位置（判据②）→ 拖入画布（零结构写入）→ 画布内拖动
/// → 可见性对话框（位置键增删）→ 相机持久化 + 重启恢复（投影不变式 §5.5）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph/node_graph.dart';

/// 种子：canvas 节点 + noteA/noteB + folderA；[positions] 写画布位置。
HostRuntime seed(Directory root, {Map<String, Offset> positions = const {}}) {
  final host = HostRuntime(dataRoot: root);
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
      id: 'noteA',
      title: '笔记A',
      content: 'A 的内容',
      createdAt: now,
      updatedAt: now,
    ),
    StoredNode(
      id: 'noteB',
      title: '笔记B',
      content: 'B 的内容',
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
  for (final entry in positions.entries) {
    host.uiStateStore.set(canvasPositionKey(entry.key), <String, dynamic>{
      'x': entry.value.dx,
      'y': entry.value.dy,
    });
  }
  return host;
}

/// 测试壳：侧边栏（Draggable 笔记行）+ 画布 + 管理按钮。
/// 管理按钮打开对话框，关闭后 setState 刷新（对齐 app 壳宿主行为）。
class _Harness extends StatefulWidget {
  const _Harness({required this.host});

  final HostRuntime host;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        title: const Text('测试'),
        actions: [
          Builder(
            builder: (appBarContext) => IconButton(
              icon: const Icon(Icons.graphic_eq),
              tooltip: '管理画布节点',
              onPressed: () async {
                await showDialog<void>(
                  context:
                      appBarContext, // MaterialApp 之下（Navigator/Localizations）。
                  builder: (context) => GraphNodesDialog(
                    graph: widget.host.graph,
                    uiStateStore: widget.host.uiStateStore,
                    i18n: widget.host.i18nService,
                  ),
                );
                if (mounted) {
                  setState(() {});
                }
              },
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 200, child: _SidebarNotes(host: widget.host)),
          Expanded(child: GraphCanvas(host: widget.host)),
        ],
      ),
    ),
  );
}

/// 侧边栏：非画布节点全部显示为 Draggable 行（拖拽源，对齐 app 壳）。
class _SidebarNotes extends StatelessWidget {
  const _SidebarNotes({required this.host});

  final HostRuntime host;

  @override
  Widget build(BuildContext context) {
    final nodes = host.graph
        .getAll()
        .where((n) => !const CanvasConcept().validate(n))
        .toList();
    return ListView(
      children: [
        for (final node in nodes)
          Draggable<String>(
            data: node.id,
            feedback: Material(
              color: Colors.transparent,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(node.title),
                ),
              ),
            ),
            child: ListTile(dense: true, title: Text(node.title, maxLines: 1)),
          ),
      ],
    );
  }
}

/// 画布内的节点卡片（断言定位用）。
Finder canvasCard(String title) =>
    find.descendant(of: find.byType(GraphCanvas), matching: find.text(title));

/// 对话框内的文本（与侧边栏重名，需作用域限定）。
Finder dialogText(String text) => find.descendant(
  of: find.byType(GraphNodesDialog),
  matching: find.text(text),
);

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_canvas');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  testWidgets('渲染有位置的成员；无位置节点不渲染（成员 = 外观位置）', (tester) async {
    final host = seed(
      root,
      positions: <String, Offset>{'noteB': const Offset(100, 100)},
    );
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    expect(canvasCard('笔记B'), findsOneWidget);
    // 无位置键 → 非画布成员（00 杀手演示"拖上画布才变成图节点"）。
    expect(canvasCard('笔记A'), findsNothing);
  });

  testWidgets('侧边栏拖入画布 → 位置直写 + 卡片出现 + 零结构写入（判据②）', (tester) async {
    final host = seed(
      root,
      positions: <String, Offset>{'noteB': const Offset(100, 100)},
    );
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    final beforeIds = host.graph.getAll().map((n) => n.id).toSet();

    // 从侧边栏拖 noteA 到画布中心。
    final noteA = find.text('笔记A');
    final canvasCenter = tester.getCenter(find.byType(GraphCanvas));
    await tester.drag(noteA, canvasCenter - tester.getCenter(noteA));
    await tester.pumpAndSettle();

    // 位置已写入（外观存储）。
    final position = parseCanvasPosition(
      host.uiStateStore.get(canvasPositionKey('noteA')),
    );
    expect(position, isNotNull);
    // 卡片出现。
    expect(canvasCard('笔记A'), findsOneWidget);
    // 零结构写入（投影不变式 4.1）：节点集合与内容不变。
    expect(host.graph.getAll().map((n) => n.id).toSet(), beforeIds);
    expect(host.graph.get('noteA')!.references, isEmpty);
    expect(host.graph.get('noteA')!.title, '笔记A');

    // SnackBar 自动关闭定时器（防 pending timer）。
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('画布内拖动卡片 → 位置更新（外观直写，即时拖拽）', (tester) async {
    final host = seed(
      root,
      positions: <String, Offset>{'noteB': const Offset(100, 100)},
    );
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    // 卡片上按下即拖（即时 Draggable，slop 18 < pan slop 36 → 拖卡片赢）。
    // childDragAnchorStrategy：drop offset = 卡片原位左上 + 拖拽位移；
    // position 语义 = 卡片中心（+半尺寸）；画布局部坐标 = 全局 - 原点。
    final cardTopLeft = tester.getTopLeft(find.byType(NodeCard));
    final origin = tester.getTopLeft(find.byType(GraphCanvas));
    final gesture = await tester.startGesture(
      tester.getCenter(canvasCard('笔记B')),
    );
    await gesture.moveBy(const Offset(150, 50));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final position = parseCanvasPosition(
      host.uiStateStore.get(canvasPositionKey('noteB')),
    );
    expect(
      position!.dx,
      closeTo(cardTopLeft.dx + cardSize.width / 2 + 150 - origin.dx, 1),
    );
    expect(
      position.dy,
      closeTo(cardTopLeft.dy + cardSize.height / 2 + 50 - origin.dy, 1),
    );
    // 拖卡片 ≠ 画布平移（手势竞争修复：卡片拖拽不触发相机 pan）。
    expect(host.uiStateStore.get('camera.main.canvas@graph'), isNull);

    // SnackBar 自动关闭定时器（防 pending timer）。
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('可见性对话框：取消勾选 → 位置键移除；勾选 → 默认布局位置', (tester) async {
    final host = seed(
      root,
      positions: <String, Offset>{'noteB': const Offset(100, 100)},
    );
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    // 打开对话框 → 可选项 = 用户节点（画布自身/关系节点不在内）。
    await tester.tap(find.byIcon(Icons.graphic_eq));
    await tester.pumpAndSettle();
    expect(dialogText('笔记A'), findsOneWidget);
    expect(dialogText('笔记B'), findsOneWidget);
    expect(dialogText('文件夹A'), findsOneWidget);
    expect(dialogText('画布'), findsNothing);

    // 取消勾选 noteB → 应用 → 位置键移除（节点离开画布）。
    await tester.tap(dialogText('笔记B'));
    await tester.pump();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(host.uiStateStore.get(canvasPositionKey('noteB')), isNull);
    expect(canvasCard('笔记B'), findsNothing);

    // 重新打开 → 勾选 noteA → 应用 → 默认布局位置写入（网格槽位确定性）。
    await tester.tap(find.byIcon(Icons.graphic_eq));
    await tester.pumpAndSettle();
    await tester.tap(dialogText('笔记A'));
    await tester.pump();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(
      parseCanvasPosition(host.uiStateStore.get(canvasPositionKey('noteA'))),
      const Offset(60, 60),
    );
    expect(canvasCard('笔记A'), findsOneWidget);
  });

  testWidgets('相机 pan → camera.main.<hookId> 持久化；重启恢复（§5.5）', (tester) async {
    final host = seed(
      root,
      positions: <String, Offset>{'noteB': const Offset(100, 100)},
    );
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    // 拖拽 pan（对齐 Flutter 官方 InteractiveViewer 测试手势模式）。
    final center = tester.getCenter(find.byType(GraphCanvas));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.moveTo(center + const Offset(200, 100));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400)); // 防抖写盘。

    const cameraKey = 'camera.main.canvas@graph';
    final saved = host.uiStateStore.get(cameraKey);
    expect(saved, isA<Map<String, dynamic>>());
    final matrix = Matrix4.fromList(
      ((saved as Map<String, dynamic>)['m'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
    final tx = matrix.getTranslation().x;
    final ty = matrix.getTranslation().y;
    expect(tx != 0 || ty != 0, isTrue, reason: 'pan 后相机矩阵应非恒等');

    // 卡片屏幕位置 = 世界左上 (10, 52) + 相机平移 + 画布偏移 (200, 56)。
    final cardTopLeft = tester.getTopLeft(find.byType(NodeCard));
    expect(cardTopLeft.dx, closeTo(210 + tx, 1.5));
    expect(cardTopLeft.dy, closeTo(108 + ty, 1.5));

    // 重启：新 HostRuntime 读同一数据根 → 矩阵恢复 → 渲染位置一致。
    final reopened = HostRuntime(dataRoot: root);
    final restored =
        reopened.uiStateStore.get(cameraKey) as Map<String, dynamic>;
    expect((restored['m'] as List<dynamic>).length, 16);

    await tester.pumpWidget(_Harness(host: reopened));
    await tester.pump();
    expect(canvasCard('笔记B'), findsOneWidget);
    final restoredTopLeft = tester.getTopLeft(find.byType(NodeCard));
    expect(restoredTopLeft.dx, closeTo(210 + tx, 1.5));
    expect(restoredTopLeft.dy, closeTo(108 + ty, 1.5));
  });

  testWidgets('孤儿位置键惰性 GC：节点不存在的位置在触达时清理（02 §2.3）', (tester) async {
    final host = seed(
      root,
      positions: <String, Offset>{'noteB': const Offset(100, 100)},
    );
    // 制造孤儿：noteA 有位置但节点已被删除。
    host.uiStateStore.set(canvasPositionKey('noteA'), <String, dynamic>{
      'x': 10,
      'y': 10,
    });
    host.graph.delete('noteA');

    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    expect(host.uiStateStore.get(canvasPositionKey('noteA')), isNull);
  });

  testWidgets('外部位置键写入 → 画布自动刷新（观察者通道，M7.2 D2）', (tester) async {
    // 无成员种子：noteA 不在画布。
    final host = seed(root);
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();
    expect(
      find.descendant(of: find.byType(GraphCanvas), matching: find.text('笔记A')),
      findsNothing,
    );

    // 模拟可见性对话框（外部写入方）：直写位置键（02 §2.3 观察者通道）。
    host.uiStateStore.set(canvasPositionKey('noteA'), <String, dynamic>{
      'x': 100,
      'y': 100,
    });
    await tester.pump(); // post-frame 延迟重建。
    await tester.pump();

    expect(
      find.descendant(of: find.byType(GraphCanvas), matching: find.text('笔记A')),
      findsOneWidget,
    );
  });

  testWidgets('缩放按钮 → 相机矩阵带缩放持久化；重启恢复完整矩阵（M7.3）', (tester) async {
    final host = seed(
      root,
      positions: <String, Offset>{'noteB': const Offset(100, 100)},
    );
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    // 放大两次（相对因子 1.25）→ 防抖写盘。
    await tester.tap(find.byIcon(Icons.zoom_in));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.zoom_in));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 防抖 300ms。

    const cameraKey = 'camera.main.canvas@graph';
    final saved = host.uiStateStore.get(cameraKey) as Map<String, dynamic>;
    final matrix = Matrix4.fromList(
      (saved['m'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
    );
    expect(matrix.getMaxScaleOnAxis(), closeTo(1.25 * 1.25, 0.01));

    // 缩小一次 → 回退到 1.25。
    await tester.tap(find.byIcon(Icons.zoom_out));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final shrunk = Matrix4.fromList(
      ((host.uiStateStore.get(cameraKey) as Map<String, dynamic>)['m']
              as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
    expect(shrunk.getMaxScaleOnAxis(), closeTo(1.25, 0.01));

    // 重启：新 HostRuntime 恢复完整矩阵（缩放不再归 1）。
    final reopened = HostRuntime(dataRoot: root);
    await tester.pumpWidget(_Harness(host: reopened));
    await tester.pump();
    final restored = Matrix4.fromList(
      ((reopened.uiStateStore.get(cameraKey) as Map<String, dynamic>)['m']
              as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
    expect(restored.getMaxScaleOnAxis(), closeTo(1.25, 0.01));
  });

  testWidgets('适应视图：成员包围盒中心映射到视口中心（M7.3）', (tester) async {
    final host = seed(
      root,
      positions: <String, Offset>{
        'noteB': const Offset(100, 100),
        'noteA': const Offset(600, 400),
      },
    );
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.fit_screen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 防抖写盘。

    final saved =
        host.uiStateStore.get('camera.main.canvas@graph')
            as Map<String, dynamic>;
    final matrix = Matrix4.fromList(
      (saved['m'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
    );

    // 包围盒（成员中心 ± 卡片半尺寸）中心 → 视口中心。
    const center = Offset(350, 250);
    final viewport = tester.getSize(find.byType(GraphCanvas));
    final mapped = MatrixUtils.transformPoint(matrix, center);
    expect(mapped.dx, closeTo(viewport.width / 2, 1.5));
    expect(mapped.dy, closeTo(viewport.height / 2, 1.5));
  });
}
