/// 画布交互测试（M6 graph 插件，对齐旧节点操作资产的新架构形态）：
///
/// 双击空白创建节点（判据① 数据命令 + 位置键）→ 右键菜单编辑/删除
/// （级联清理）→ 拖卡片到卡片建立连接（L1 实例）→ 自连接拒绝。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph/node_graph.dart';
import 'package:plugon/plugon.dart';

/// 种子 + 启动（命令路由需要插件注册）。
Future<HostRuntime> seed(
  Directory root, {
  Map<String, Offset> positions = const <String, Offset>{
    'noteA': Offset(100, 100),
    'noteB': Offset(420, 200),
  },
}) async {
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
  ].forEach(host.graph.save);
  for (final entry in positions.entries) {
    host.uiStateStore.set(canvasPositionKey(entry.key), <String, dynamic>{
      'x': entry.value.dx,
      'y': entry.value.dy,
    });
  }
  await host.start(plugins: <Plugin>[GraphPlugin()], rootNodeId: 'root');
  return host;
}

/// 测试壳：全屏画布。
class _Harness extends StatefulWidget {
  const _Harness({required this.host});

  final HostRuntime host;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: GraphCanvas(host: widget.host)),
  );
}

/// 画布内的节点卡片文本。
Finder canvasCard(String title) =>
    find.descendant(of: find.byType(GraphCanvas), matching: find.text(title));

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_interact');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  testWidgets('双击空白 → 创建对话框 → 节点 + 位置键（判据①+②）', (tester) async {
    final host = await seed(root);
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    // 空白处双击（两点距离 < 20px，间隔 < 300ms）。
    final point = tester.getCenter(find.byType(GraphCanvas));
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(point);
    await tester.pumpAndSettle();

    // 创建对话框。
    await tester.enterText(find.widgetWithText(TextField, '标题'), '新建笔记');
    await tester.enterText(
      find.widgetWithText(TextField, '内容（markdown）'),
      '双击创建的正文',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 节点落盘 + 位置键（双击点）→ 画布卡片出现。
    final created = host.graph.getAll().where((n) => n.title == '新建笔记').single;
    expect(created.content, '双击创建的正文');
    expect(host.uiStateStore.get(canvasPositionKey(created.id)), isNotNull);
    expect(canvasCard('新建笔记'), findsOneWidget);
  });

  testWidgets('右键菜单 → 编辑 → 标题/内容更新（UpdateNodeCommand）', (tester) async {
    final host = await seed(root);
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    // 右键卡片。
    final gesture = await tester.startGesture(
      tester.getCenter(canvasCard('笔记A')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    // 菜单 → 编辑 → 修改标题。
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '标题'), '改名A');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(host.graph.get('noteA')!.title, '改名A');
    expect(canvasCard('改名A'), findsOneWidget);
  });

  testWidgets('右键菜单 → 删除 → 级联清理（节点 + 连接 + 位置键）', (tester) async {
    final host = await seed(root);
    // 先建连接 noteA ↔ noteB。
    final now = DateTime.now();
    host.graph.save(
      StoredNode(
        id: 'conn-ab',
        title: 'connect',
        references: const <String, String>{'from': 'noteA', 'to': 'noteB'},
        createdAt: now,
        updatedAt: now,
      ),
    );
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    // 右键 → 删除 → 确认。
    final gesture = await tester.startGesture(
      tester.getCenter(canvasCard('笔记A')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last); // 确认对话框的删除按钮。
    await tester.pumpAndSettle();

    expect(host.graph.get('noteA'), isNull);
    expect(host.graph.get('conn-ab'), isNull); // 级联：连接实例。
    expect(host.graph.get('noteB'), isNotNull);
    expect(host.uiStateStore.get(canvasPositionKey('noteA')), isNull);
    expect(canvasCard('笔记A'), findsNothing);

    // SnackBar 定时器。
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('拖卡片到另一卡片 → 连接实例（L1 引用两端）', (tester) async {
    final host = await seed(root);
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    // 拖 noteA 卡片到 noteB 卡片中心（drop 命中内层卡片 DragTarget）。
    final from = tester.getCenter(canvasCard('笔记A'));
    final to = tester.getCenter(canvasCard('笔记B'));
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final conn = host.graph.getAll().firstWhere(
      (n) => const ConnectionConcept().validate(n),
    );
    expect(conn.references, <String, String>{'from': 'noteA', 'to': 'noteB'});
    // 两端位置未变（连接不是移动）。
    expect(
      parseCanvasPosition(host.uiStateStore.get(canvasPositionKey('noteA'))),
      const Offset(100, 100),
    );

    // SnackBar 定时器。
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('拖到卡片附近（边缘外 20px）→ 就近判定连接（容差）', (tester) async {
    final host = await seed(root);
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    // 拖 noteA 到 noteB 卡片右边缘外 20px（不精确落在卡片上）。
    final from = tester.getCenter(canvasCard('笔记A'));
    final to =
        tester.getCenter(canvasCard('笔记B')) +
        const Offset(110, 0); // 卡片半宽 90 + 20px 容差内。
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final conn = host.graph.getAll().firstWhere(
      (n) => const ConnectionConcept().validate(n),
    );
    expect(conn.references, <String, String>{'from': 'noteA', 'to': 'noteB'});

    // SnackBar 定时器。
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('打开节点对话框：外壳带关闭按钮（M7.2 D1 画布责任）', (tester) async {
    final host = await seed(root);
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    await tester.tap(canvasCard('笔记A'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    // 外壳 = 画布提供（CanvasConcept 责任）：关闭按钮可用。
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('负坐标卡片可命中（世界容器覆盖负区，修正回归）', (tester) async {
    // 相机 pan 后拖拽可产生负坐标位置（用户实测：卡片可见但点不到——
    // 世界容器从 (0,0) 开始，负坐标卡片在容器边界外，Stack 命中失败）。
    final host = await seed(
      root,
      positions: <String, Offset>{
        'noteA': const Offset(-200, -100),
        'noteB': const Offset(420, 200),
      },
    );
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    // 点击负坐标卡片 → 命中 → 打开 = 渲染节点 Hook（M7 修正：
    // Dialog + HookView——AIHook 对话 / 笔记 Hook 编辑器）。
    await tester.tap(canvasCard('笔记A'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('拖卡片到自己 → 拒绝（自连接，无连接实例）', (tester) async {
    final host = await seed(root);
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    final center = tester.getCenter(canvasCard('笔记A'));
    final gesture = await tester.startGesture(center);
    await gesture.moveTo(center + const Offset(40, 0)); // 仍在卡片内。
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      host.graph.getAll().where((n) => const ConnectionConcept().validate(n)),
      isEmpty,
    );
  });
}
