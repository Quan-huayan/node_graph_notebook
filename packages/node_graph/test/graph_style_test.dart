/// 节点样式测试（M7.3，判据② 外观直写）：
/// 样式键 → 尺寸/颜色/形态在卡片壳层生效；默认按 kind 配色；
/// 样式对话框往返；删除节点同步清理样式键。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph/node_graph.dart';
import 'package:plugon/plugon.dart';

/// 种子：canvas + noteA/noteB/aiNode + 位置 + GraphPlugin（命令 handler）。
Future<HostRuntime> seed(
  Directory root, {
  Map<String, Offset> positions = const {},
}) async {
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
      id: 'aiNode',
      title: 'AI 助手',
      metadata: const <String, dynamic>{'kind': 'ai'},
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
  await host.start(plugins: <Plugin>[GraphPlugin()], rootNodeId: 'canvas');
  return host;
}

/// 测试壳：仅画布（无侧边栏）。
class _Harness extends StatelessWidget {
  const _Harness({required this.host});

  final HostRuntime host;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: GraphCanvas(host: host)),
  );
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_style');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  testWidgets('样式尺寸 → 卡片按样式宽高定位渲染', (tester) async {
    final host = await seed(
      root,
      positions: <String, Offset>{'noteB': const Offset(100, 100)},
    );
    host.uiStateStore.set(canvasStyleKey('noteB'), <String, dynamic>{
      'width': 260,
      'height': 140,
    });
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    final rect = tester.getRect(find.byType(NodeCard));
    expect(rect.width, closeTo(260, 0.1));
    expect(rect.height, closeTo(140, 0.1));
  });

  testWidgets('circle 模式 → 取 min 宽高方形 + ClipOval 裁剪', (tester) async {
    final host = await seed(
      root,
      positions: <String, Offset>{'noteB': const Offset(100, 100)},
    );
    // 默认 180x96 → circle 取 96 方形。
    host.uiStateStore.set(canvasStyleKey('noteB'), <String, dynamic>{
      'mode': 'circle',
    });
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    expect(find.byType(ClipOval), findsOneWidget);
    final rect = tester.getRect(find.byType(NodeCard));
    expect(rect.width, closeTo(rect.height, 0.1));
    expect(rect.width, closeTo(96, 0.1));
  });

  testWidgets('颜色样式 → Card 底色应用', (tester) async {
    final host = await seed(
      root,
      positions: <String, Offset>{'noteB': const Offset(100, 100)},
    );
    host.uiStateStore.set(canvasStyleKey('noteB'), <String, dynamic>{
      'color': '#EF5350',
    });
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    final card = tester.widget<Card>(find.byType(Card));
    expect(card.color, const Color(0xFFEF5350));
  });

  testWidgets('默认按 kind 配色：AI 节点 → indigo 50（无样式时）', (tester) async {
    final host = await seed(
      root,
      positions: <String, Offset>{'aiNode': const Offset(100, 100)},
    );
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    final card = tester.widget<Card>(find.byType(Card));
    expect(card.color, const Color(0xFFE8EAF6)); // indigo 50。
  });

  testWidgets('外部样式键写入 → 画布自动刷新（观察者通道）', (tester) async {
    final host = await seed(
      root,
      positions: <String, Offset>{'noteB': const Offset(100, 100)},
    );
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();
    expect(tester.getRect(find.byType(NodeCard)).width, closeTo(180, 0.1));

    // 外部写入（模拟样式对话框保存路径）。
    host.uiStateStore.set(canvasStyleKey('noteB'), <String, dynamic>{
      'width': 300,
      'height': 200,
    });
    await tester.pump();
    await tester.pump();

    expect(tester.getRect(find.byType(NodeCard)).width, closeTo(300, 0.1));
    expect(tester.getRect(find.byType(NodeCard)).height, closeTo(200, 0.1));
  });

  testWidgets('删除节点 → 样式键同步清理', (tester) async {
    final host = await seed(
      root,
      positions: <String, Offset>{'noteB': const Offset(100, 100)},
    );
    host.uiStateStore.set(canvasStyleKey('noteB'), <String, dynamic>{
      'width': 260,
    });
    await host.commandBus.dispatch<DeleteNodeCommand, DeleteNodeResult>(
      DeleteNodeCommand(nodeId: 'noteB'),
    );
    expect(host.uiStateStore.get(canvasPositionKey('noteB')), isNull);
    expect(host.uiStateStore.get(canvasStyleKey('noteB')), isNull);
  });

  testWidgets('拖拽反馈 = 样式克隆（底色/圆形随源卡，不闪白卡/不变矩形）', (
    tester,
  ) async {
    // 回归（M7.3）：旧反馈固定默认尺寸无底色——文件夹（amber 50）
    // 拖拽闪白卡；圆形节点拖拽变 180x96 矩形。
    final host = await seed(
      root,
      positions: <String, Offset>{'noteB': const Offset(100, 100)},
    );
    host.uiStateStore.set(canvasStyleKey('noteB'), <String, dynamic>{
      'mode': 'circle',
      'color': '#42A5F5',
    });
    await tester.pumpWidget(_Harness(host: host));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(NodeCard)),
    );
    await gesture.moveBy(const Offset(40, 40));
    await tester.pump();

    // 源卡 + 反馈均为蓝色圆形卡（≥2：反馈不再是无底色白卡）。
    final colored = find.byWidgetPredicate(
      (w) => w is Card && w.color == const Color(0xFF42A5F5),
    );
    expect(colored, findsNWidgets(2));
    // 反馈含圆形裁剪（≥2：源卡 ClipOval + 反馈 ClipOval）。
    expect(find.byType(ClipOval), findsNWidgets(2));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('NodeStyleDialog：选色保存 → 返回样式并序列化', (tester) async {
    // 放大窗口：色板 + 输入 + 形态选择在一屏内（防命中裁剪）。
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    NodeStyle? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<NodeStyle>(
                  context: context,
                  builder: (context) => NodeStyleDialog(
                    i18n: I18nService(),
                    initial: parseNodeStyle(<String, dynamic>{
                      'mode': 'circle',
                    }),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(NodeStyleDialog), findsOneWidget);

    // 选红色色块（palette[0]，dialog 作用域）→ 宽 240 → 保存。
    final dialogSwatches = find.descendant(
      of: find.byType(NodeStyleDialog),
      matching: find.byType(InkWell),
    );
    await tester.tap(dialogSwatches.first);
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '240');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(parseHexColor(result!.color), const Color(0xFFEF5350));
    expect(result!.width, 240);
    expect(result!.mode, NodeCardMode.circle); // 初始 circle 保持。
  });
}
