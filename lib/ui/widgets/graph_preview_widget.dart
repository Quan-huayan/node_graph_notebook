import 'package:flutter/material.dart';
import '../../core/models/models.dart';

/// 图形预览 widget - 显示节点关系的迷你图
class GraphPreviewWidget extends StatelessWidget {
  const GraphPreviewWidget({
    super.key,
    required this.nodes,
  });

  final List<Node> nodes;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No nodes to preview'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 标题栏
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.account_tree, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Graph Preview',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${nodes.length} nodes',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),

        // 预览区域
        Expanded(
          child: CustomPaint(
            painter: _GraphPreviewPainter(nodes),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _GraphPreviewPainter extends CustomPainter {
  _GraphPreviewPainter(this.nodes);

  final List<Node> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    // 简单的网格布局
    final cols = (nodes.length / 3).ceil().clamp(1, 5);
    final rows = (nodes.length / cols).ceil();

    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    // 绘制连接线
    final linePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final x1 = (i % cols) * cellWidth + cellWidth / 2;
      final y1 = (i ~/ cols) * cellHeight + cellHeight / 2;

      // 绘制到其他节点的连接
      for (final entry in node.references.entries) {
        final targetIndex = nodes.indexWhere((n) => n.id == entry.key);
        if (targetIndex >= 0 && targetIndex != i) {
          final x2 = (targetIndex % cols) * cellWidth + cellWidth / 2;
          final y2 = (targetIndex ~/ cols) * cellHeight + cellHeight / 2;

          canvas.drawLine(
            Offset(x1, y1),
            Offset(x2, y2),
            linePaint,
          );
        }
      }
    }

    // 绘制节点
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final x = (i % cols) * cellWidth + cellWidth / 2;
      final y = (i ~/ cols) * cellHeight + cellHeight / 2;

      // 节点背景
      final nodePaint = Paint()
        ..color = node.isFolder
            ? Colors.blue.withValues(alpha: 0.3)
            : Colors.green.withValues(alpha: 0.3);

      final nodeStroke = Paint()
        ..color = node.isFolder ? Colors.blue : Colors.green
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final nodeRadius = (cellWidth < cellHeight ? cellWidth : cellHeight) / 3;

      canvas.drawCircle(Offset(x, y), nodeRadius, nodePaint);
      canvas.drawCircle(Offset(x, y), nodeRadius, nodeStroke);

      // 节点编号
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_GraphPreviewPainter oldDelegate) {
    return oldDelegate.nodes != nodes;
  }
}
