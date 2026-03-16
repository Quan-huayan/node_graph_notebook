import 'dart:math' show sqrt;

import 'package:vector_math/vector_math.dart';

import '../../../../core/execution/cpu_task.dart';

/// 连接路径计算任务
///
/// 在后台 isolate 中计算节点间的连接路径
/// 支持直线、贝塞尔曲线等多种路径类型
class ConnectionPathTask extends CPUTask<ConnectionPathResult> {
  /// 创建连接路径计算任务
  ConnectionPathTask({
    required this.start,
    required this.end,
    this.curvature = 0.5,
    this.pathType = ConnectionPathType.bezier,
  });

  /// 起始点
  final Vector2 start;
  /// 结束点
  final Vector2 end;
  /// 曲线曲率（仅贝塞尔曲线）
  final double curvature;
  /// 路径类型
  final ConnectionPathType pathType;

  @override
  String get name => 'ConnectionPath($start -> $end)';

  @override
  String get taskType => 'ConnectionPath';

  @override
  Map<String, dynamic> serialize() => {
      'taskType': taskType,
      'taskName': name,
      'start': {'x': start.x, 'y': start.y},
      'end': {'x': end.x, 'y': end.y},
      'curvature': curvature,
      'pathType': pathType.name,
    };

  @override
  Future<ConnectionPathResult> execute() async {
    switch (pathType) {
      case ConnectionPathType.straight:
        return _calculateStraightPath();
      case ConnectionPathType.bezier:
        return _calculateBezierPath();
      case ConnectionPathType.step:
        return _calculateStepPath();
    }
  }

  /// 计算直线路径
  ConnectionPathResult _calculateStraightPath() => ConnectionPathResult(
      path: [start, end],
      length: start.distanceTo(end),
    );

  /// 计算贝塞尔曲线路径
  ConnectionPathResult _calculateBezierPath() {
    // 计算控制点
    final midPoint = (start + end) / 2;
    final direction = (end - start).normalized();
    final perpendicular = Vector2(-direction.y, direction.x);

    // 控制点偏移量
    final offset = perpendicular * (start.distanceTo(end) * curvature);
    final controlPoint = midPoint + offset;

    // 生成贝塞尔曲线上的点（用于渲染）
    final points = <Vector2>[];
    const segments = 20;
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final point = _calculateBezierPoint(start, controlPoint, end, t);
      points.add(point);
    }

    // 估算曲线长度（分段累加）
    double length = 0;
    for (var i = 0; i < points.length - 1; i++) {
      length += points[i].distanceTo(points[i + 1]);
    }

    return ConnectionPathResult(
      path: points,
      length: length,
      controlPoint: controlPoint,
    );
  }

  /// 计算二阶贝塞尔曲线上的点
  Vector2 _calculateBezierPoint(Vector2 p0, Vector2 p1, Vector2 p2, double t) {
    final mt = 1 - t;
    return p0 * mt * mt + p1 * 2 * mt * t + p2 * t * t;
  }

  /// 计算折线路径
  ConnectionPathResult _calculateStepPath() {
    final midX = (start.x + end.x) / 2;

    // 水平优先的折线
    final points = [
      start,
      Vector2(midX, start.y),
      Vector2(midX, end.y),
      end,
    ];

    // 计算总长度
    double length = 0;
    for (var i = 0; i < points.length - 1; i++) {
      length += points[i].distanceTo(points[i + 1]);
    }

    return ConnectionPathResult(path: points, length: length);
  }
}

/// 连接路径类型
enum ConnectionPathType {
  /// 直线
  straight,

  /// 贝塞尔曲线
  bezier,

  /// 折线
  step,
}

/// 连接路径计算结果
class ConnectionPathResult {
  /// 创建连接路径计算结果
  const ConnectionPathResult({
    required this.path,
    required this.length,
    this.controlPoint,
  });

  /// 路径上的点序列
  final List<Vector2> path;

  /// 路径总长度
  final double length;

  /// 控制点（仅贝塞尔曲线）
  final Vector2? controlPoint;
}

/// 序列化的连接路径任务（用于 isolate 内部）
class ConnectionPathTaskSerialized extends CPUTask<Map<String, dynamic>> {
  /// 创建序列化的连接路径任务
  ///
  /// ### 参数
  /// - `_data` - 包含任务数据的 Map
  ConnectionPathTaskSerialized(this._data);

  final Map<String, dynamic> _data;

  @override
  String get name => _data['taskName'] as String;

  @override
  String get taskType => 'ConnectionPath';

  @override
  Map<String, dynamic> serialize() => _data;

  @override
  Future<Map<String, dynamic>> execute() async {
    final startX = _data['startX'] as double;
    final startY = _data['startY'] as double;
    final endX = _data['endX'] as double;
    final endY = _data['endY'] as double;
    final curvature = _data['curvature'] as double? ?? 0.5;

    // 计算贝塞尔曲线路径
    final start = Vector2(startX, startY);
    final end = Vector2(endX, endY);

    // 计算控制点
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    final distance = sqrt(dx * dx + dy * dy);

    final controlPoint = Vector2(
      start.x + dx * 0.5 - dy * curvature,
      start.y + dy * 0.5 + dx * curvature,
    );

    // 生成路径点（简化版，实际使用更多点）
    final points = <Map<String, double>>[];
    const segments = 20;
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final x = (1 - t) * (1 - t) * start.x +
          2 * (1 - t) * t * controlPoint.x +
          t * t * end.x;
      final y = (1 - t) * (1 - t) * start.y +
          2 * (1 - t) * t * controlPoint.y +
          t * t * end.y;
      points.add({'x': x, 'y': y});
    }

    // 计算路径长度（简化估算）
    final length = distance * (1 + curvature.abs());

    return {
      'path': points,
      'length': length,
      'controlPoint': {
        'x': controlPoint.x,
        'y': controlPoint.y,
      },
    };
  }
}