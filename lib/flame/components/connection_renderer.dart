import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/theme/app_theme.dart';

/// 连接线渲染组件
class ConnectionRenderer extends Component {
  ConnectionRenderer({
    required List<Connection> connections,
    required Map<String, Vector2> nodePositions,
    required this.theme,
    this.showConnections = true,
  })  : _connections = connections,
        _nodePositions = nodePositions;

  List<Connection> _connections;
  Map<String, Vector2> _nodePositions;
  final AppThemeData theme;
  bool showConnections;

  /// 更新连接和节点位置
  void updateConnections({
    required List<Connection> connections,
    required Map<String, Vector2> nodePositions,
    bool? showConnections,
  }) {
    _connections = connections;
    _nodePositions = nodePositions;
    if (showConnections != null) {
      this.showConnections = showConnections;
    }
  }

  List<Connection> get connections => _connections;
  Map<String, Vector2> get nodePositions => _nodePositions;

  @override
  void render(Canvas canvas) {
    if (!showConnections) return;
    
    for (final connection in connections) {
      _drawConnection(canvas, connection);
    }
  }

  void _drawConnection(Canvas canvas, Connection connection) {
    final fromPos = nodePositions[connection.fromNodeId];
    final toPos = nodePositions[connection.toNodeId];

    if (fromPos == null || toPos == null) return;

    // 计算连接线的绘制点
    final start = _calculateEdgePoint(fromPos, toPos, isStart: true);
    final end = _calculateEdgePoint(toPos, fromPos, isStart: false);

    // 使用统一的绘制样式
    final paint = _getPaintForConnection(connection);

    // 根据线条样式绘制连接线
    _drawLine(canvas, start, end, paint, connection.lineStyle);

    // 统一绘制箭头（所有连接都显示箭头）
    _drawArrow(canvas, start, end, paint);

    // 绘制标签
    if (connection.role != null) {
      _drawLabel(canvas, start, end, connection.role!);
    }
  }

  void _drawLine(Canvas canvas, Vector2 start, Vector2 end, Paint paint, LineStyle lineStyle) {
    if (lineStyle == LineStyle.solid) {
      canvas.drawLine(
        Offset(start.x, start.y),
        Offset(end.x, end.y),
        paint,
      );
    } else {
      // 虚线或点线
      final path = Path()
        ..moveTo(start.x, start.y)
        ..lineTo(end.x, end.y);

      // 创建虚线路径
      final dashWidth = lineStyle == LineStyle.dashed ? 10.0 : 3.0;
      final dashSpace = lineStyle == LineStyle.dashed ? 5.0 : 3.0;

      final dashedPath = _createDashedPath(path, dashWidth, dashSpace);

      canvas.drawPath(dashedPath, paint);
    }
  }

  Path _createDashedPath(Path source, double dashWidth, double dashSpace) {
    final Path dest = Path();
    final PathMetrics metrics = source.computeMetrics();

    for (final PathMetric metric in metrics) {
      double distance = 0.0;
      bool draw = true;

      while (distance < metric.length) {
        final double len = draw ? dashWidth : dashSpace;
        if (draw) {
          dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }

    return dest;
  }

  Vector2 _calculateEdgePoint(Vector2 from, Vector2 to, {required bool isStart}) {
    // 简化：直接返回中心点
    // 实际应该根据节点尺寸计算边缘交点
    return from;
  }

  Paint _getPaintForConnection(Connection connection) {
    // 使用统一的连接线颜色
    final color = theme.connections.defaultColor;
    return Paint()
      ..color = color
      ..strokeWidth = connection.thickness
      ..style = PaintingStyle.stroke;
  }

  // LineStyle 现在在 _drawLine 方法中处理


  void _drawArrow(Canvas canvas, Vector2 start, Vector2 end, Paint paint) {
    final direction = (end - start).normalized();
    final arrowSize = 10.0;

    // 计算箭头两侧的点
    final perpendicular = Vector2(-direction.y, direction.x);
    final arrowPoint1 = end - direction * arrowSize + perpendicular * (arrowSize / 2);
    final arrowPoint2 = end - direction * arrowSize - perpendicular * (arrowSize / 2);

    final arrowPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(end.x, end.y)
      ..lineTo(arrowPoint1.x, arrowPoint1.y)
      ..lineTo(arrowPoint2.x, arrowPoint2.y)
      ..close();

    canvas.drawPath(path, arrowPaint);
  }

  void _drawLabel(Canvas canvas, Vector2 start, Vector2 end, String label) {
    final midPoint = (start + end) / 2;

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: theme.text.secondary,
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // 绘制标签背景
    final bgPaint = Paint()
      ..color = theme.backgrounds.primary.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final bgRect = Rect.fromLTWH(
      midPoint.x - textPainter.width / 2 - 4,
      midPoint.y - textPainter.height / 2 - 2,
      textPainter.width + 8,
      textPainter.height + 4,
    );

    canvas.drawRect(bgRect, bgPaint);
    textPainter.paint(
      canvas,
      Offset(
        midPoint.x - textPainter.width / 2,
        midPoint.y - textPainter.height / 2,
      ),
    );
  }
}
