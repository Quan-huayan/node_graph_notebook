/// GlobalGraphDialog —— 全局图谱（C1：Obsidian Graph view 语义）。
///
/// 读侧只读（判据②/③ 不触碰）：节点 = 全图剔除 UI 代理（BacklinkService
/// .isUiProxy 同一判定）；边 = connect 实例（from/to）+ contain 实例
/// （parent/child）；布局 = IncrementalLayoutEngine（**纯内存**——位置
/// 只存局部变量，零 UIStateStore 写，不污染画布外观）。点击节点 →
/// openNodeDialog 共用外壳打开。
///
/// 打开方式：工具栏按钮（kind=='toolbar', action='graph.global'——可
/// 播种）+ 命令面板（按钮节点数据驱动自动入列）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

import 'layout/layout_engine.dart';

/// 全局图谱布局纯函数（单测入口——零存储副作用）。
///
/// 返回记录：positions（节点 id → Offset）+ edges（无向边 id 对）。
/// 邻接来自 connect（from/to）与 contain（parent/child）实例；
/// (0,0) 起步 → 力导向收敛（有限迭代，MVP 精度足够）。
({Map<String, Offset> positions, List<(String, String)> edges})
globalGraphLayout(Graph graph) {
  final engine = IncrementalLayoutEngine(maxIterations: 60);
  final nodes = <Node>[];
  final adjacency = <String, List<String>>{};
  for (final node in graph.getAll()) {
    if (BacklinkService.isUiProxy(node)) {
      continue;
    }
    // L1 关系实例（from/to/parent/child 引用）不占节点位——Obsidian 图：
    // 节点 = 知识 L0，边 = 关系实例；实例在下方 addEdge 里贡献邻接。
    if (node.references.containsKey('from') ||
        node.references.containsKey('to') ||
        node.references.containsKey('parent') ||
        node.references.containsKey('child')) {
      continue;
    }
    nodes.add(node);
    adjacency[node.id] = <String>[];
  }
  final edges = <(String, String)>[];
  // 无向边（connect / contain 双端各记一次）。
  void addEdge(String a, String b) {
    if (a == b || !adjacency.containsKey(a) || !adjacency.containsKey(b)) {
      return;
    }
    adjacency[a]!.add(b);
    adjacency[b]!.add(a);
    edges.add((a, b));
  }

  for (final node in graph.getAll()) {
    final refs = node.references;
    if (refs['from'] != null && refs['to'] != null) {
      addEdge(refs['from']!, refs['to']!);
    }
    if (refs['parent'] != null && refs['child'] != null) {
      addEdge(refs['parent']!, refs['child']!);
    }
  }
  // (0,0) 起步全量标记 → 力导向迭代展开。
  engine.initializeLayout(nodes, const <String, Offset>{}, adjacency);
  engine.markChanged(nodes.map((n) => n.id).toList());
  engine.performIncrementalLayout(nodes, adjacency);
  final positions = <String, Offset>{};
  for (final node in nodes) {
    positions[node.id] = engine.getPosition(node.id) ?? Offset.zero;
  }
  return (positions: positions, edges: edges);
}

/// 全局图谱对话框（只读：边 + 节点圈 + 点击打开）。
Future<void> showGlobalGraphDialog(BuildContext context, HostRuntime host) =>
    showDialog<void>(
      context: context,
      builder: (context) => _GlobalGraphDialog(host: host),
    );

class _GlobalGraphDialog extends StatelessWidget {
  const _GlobalGraphDialog({required this.host});

  final HostRuntime host;

  @override
  Widget build(BuildContext context) {
    final layout = globalGraphLayout(host.graph);
    final titles = <String, String>{
      for (final n in host.graph.getAll())
        if (layout.positions.containsKey(n.id)) n.id: n.title,
    };
    return Dialog(
      child: SizedBox(
        width: 720,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                tooltip: host.i18nService.t('dialog.close'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3,
                    child: GestureDetector(
                      onTapUp: (details) {
                        // 命中最近节点（半径 28 内）→ 打开（共用外壳）。
                        String? nearest;
                        var best = 28.0;
                        for (final entry in layout.positions.entries) {
                          final distance = (entry.value - details.localPosition)
                              .distance;
                          if (distance < best) {
                            best = distance;
                            nearest = entry.key;
                          }
                        }
                        if (nearest != null) {
                          openNodeDialog(context, host, nearest);
                        }
                      },
                      child: CustomPaint(
                        size: const Size(720, 560),
                        painter: _GraphPainter(
                          positions: layout.positions,
                          titles: titles,
                          edges: layout.edges,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 全局图谱绘制（边 = 线；节点 = 圈 + 标题）。
class _GraphPainter extends CustomPainter {
  const _GraphPainter({
    required this.positions,
    required this.titles,
    required this.edges,
  });

  /// 节点位置：id → Offset。
  final Map<String, Offset> positions;

  /// 标题映射：id → 标题。
  final Map<String, String> titles;

  /// 无向边 id 对。
  final List<(String, String)> edges;

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = const Color(0xFF9CA3AF)
      ..strokeWidth = 1;
    final nodePaint = Paint()..color = const Color(0xFF4F46E5);
    // 边（先画——节点圈盖在上面）。
    for (final (a, b) in edges) {
      final pa = positions[a];
      final pb = positions[b];
      if (pa == null || pb == null) {
        continue;
      }
      canvas.drawLine(pa, pb, edgePaint);
    }
    // 节点圈 + 标题。
    const textStyle = TextStyle(
      color: Color(0xFF1F2937),
      fontSize: 11,
    );
    for (final entry in positions.entries) {
      canvas.drawCircle(entry.value, 14, nodePaint);
      final title = titles[entry.key] ?? entry.key;
      final tp = TextPainter(
        text: TextSpan(text: title, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 96);
      tp.paint(
        canvas,
        Offset(
          entry.value.dx + 16,
          entry.value.dy - tp.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_GraphPainter oldDelegate) =>
      oldDelegate.positions != positions || oldDelegate.edges != edges;
}