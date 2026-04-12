import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/logger.dart';
import 'components/node_component.dart';

const _log = AppLogger('DragFeedback');

/// 拖拽反馈组件 - 显示拖拽时的"幽灵"图像
///
/// **职责：**
/// - 渲染被拖拽节点的半透明图像
/// - 跟随鼠标/手指移动
/// - 提供视觉反馈，让用户知道正在拖拽什么
///
/// **架构说明：**
/// - 作为PositionComponent添加到GraphWorld
/// - 使用Picture缓存节点渲染结果
/// - 只在拖拽时可见
class DragFeedbackComponent extends PositionComponent {
  /// 创建拖拽反馈组件
  DragFeedbackComponent();

  /// 节点的幽灵图像
  ui.Image? _ghostImage;

  /// 节点尺寸
  Vector2? _nodeSize;

  /// 是否正在显示
  bool _isVisible = false;

  /// 是否可见
  bool get isVisible => _isVisible;

  /// 显示拖拽反馈
  ///
  /// [nodeComponent] - 被拖拽的节点组件
  /// [screenPosition] - 屏幕位置
  ///
  /// **架构说明：**
  /// - 捕获节点组件的渲染结果
  /// - 创建半透明的"幽灵"图像
  /// - 将组件移动到指定位置
  void show(NodeComponent nodeComponent, Offset screenPosition) {
    _log.debug('Showing drag feedback for node: ${nodeComponent.node.id}');

    // 捕获节点渲染结果
    _captureNodeImage(nodeComponent);

    // 设置位置
    position.setValues(screenPosition.dx, screenPosition.dy);

    // 设置可见性
    _isVisible = true;
    // opacity = 0.5; // PositionComponent没有opacity属性
  }

  /// 更新拖拽反馈位置
  ///
  /// [screenPosition] - 新的屏幕位置
  ///
  /// **架构说明：**
  /// - 使用缓动效果平滑移动到新位置
  /// - 提供更流畅的拖拽体验
  void updatePosition(Offset screenPosition) {
    // 使用线性插值实现缓动效果
    // lerp factor: 0.15 提供平滑但响应迅速的移动
    const lerpFactor = 0.15;

    final currentX = position.x;
    final currentY = position.y;
    final targetX = screenPosition.dx;
    final targetY = screenPosition.dy;

    // 线性插值: current + (target - current) * factor
    final newX = currentX + (targetX - currentX) * lerpFactor;
    final newY = currentY + (targetY - currentY) * lerpFactor;

    position.setValues(newX, newY);
  }

  /// 隐藏拖拽反馈
  ///
  /// **架构说明：**
  /// - 设置为不可见
  /// - 释放缓存的图像
  void hide() {
    _log.debug('Hiding drag feedback');

    _isVisible = false;
    // opacity = 0.0; // PositionComponent没有opacity属性

    // 释放图像缓存
    _ghostImage?.dispose();
    _ghostImage = null;
    _nodeSize = null;
  }

  /// 捕获节点渲染结果为图像
  ///
  /// [nodeComponent] - 要捕获的节点组件
  ///
  /// **架构说明：**
  /// - 使用PictureRecorder捕获节点渲染
  /// - 创建ui.Image用于后续渲染
  /// - 缓存图像避免重复渲染
  void _captureNodeImage(NodeComponent nodeComponent) {
    try {
      // 获取节点尺寸
      _nodeSize = nodeComponent.size;

      // 使用PictureRecorder捕获节点渲染
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 渲染节点到canvas
      // 注意：需要保存和恢复canvas状态
      canvas.save();

      // 应用节点的变换（位置、缩放等）
      // 由于我们只需要节点的视觉外观，不需要应用位置变换
      // 只需要渲染节点本身

      // 调用节点的render方法
      nodeComponent.render(canvas);

      canvas.restore();

      // 结束录制并创建Picture
      final picture = recorder.endRecording();

      // 将Picture转换为ui.Image
      // 注意：toImage是异步方法，但我们在这里使用同步方式
      // 在实际应用中，可能需要在onLoad中预先捕获
      picture.toImage(
        _nodeSize!.x.toInt(),
        _nodeSize!.y.toInt(),
      ).then((image) {
        _ghostImage = image;
        _log.debug('Captured node image: $_nodeSize');
      }).catchError((error) {
        _log.error('Failed to convert picture to image: $error');
      });
    } catch (e) {
      _log.error('Failed to capture node image: $e');
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_isVisible) {
      return;
    }

    // 如果有捕获的图像，渲染图像
    if (_ghostImage != null && _nodeSize != null) {
      // 设置半透明效果
      final paint = Paint()
        ..color = const Color(0x80FFFFFF) // 50%透明度
        ..filterQuality = FilterQuality.medium;

      // 渲染图像
      canvas.drawImage(
        _ghostImage!,
        Offset(position.x, position.y),
        paint,
      );
    } else {
      // 降级方案：渲染一个半透明的矩形作为占位符
      final paint = Paint()
        ..color = const Color(0x80FFFFFF) // 白色，50%透明度
        ..style = PaintingStyle.fill;

      final size = _nodeSize ?? Vector2(100, 50);
      canvas.drawRect(
        Rect.fromLTWH(position.x, position.y, size.x, size.y),
        paint,
      );

      // 绘制边框
      final borderPaint = Paint()
        ..color = const Color(0xFF3B82F6) // 蓝色边框
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(
        Rect.fromLTWH(position.x, position.y, size.x, size.y),
        borderPaint,
      );
    }
  }

  @override
  void onRemove() {
    // 清理资源
    hide();
    super.onRemove();
  }
}

/// Hook放置区域高亮组件
///
/// **职责：**
/// - 高亮显示可放置的Hook区域
/// - 提供视觉反馈，让用户知道可以放置在哪里
///
/// **架构说明：**
/// - 作为PositionComponent添加到GraphWorld
/// - 渲染在所有其他组件之上（高z-index）
/// - 只在有拖拽且检测到目标Hook时可见
class HookDropZoneHighlight extends PositionComponent {
  /// 创建Hook放置区域高亮组件
  HookDropZoneHighlight();

  /// 高亮区域（屏幕坐标）
  Rect? _highlightZone;

  /// 高亮颜色
  static const _highlightColor = Color(0x3D3B82F6); // 蓝色，25%透明度

  /// 边框颜色
  static const _borderColor = Color(0xFF3B82F6); // 蓝色，100%不透明

  /// 是否正在高亮
  bool get isHighlighting => _highlightZone != null;

  /// 高亮显示区域
  ///
  /// [zone] - 要高亮的区域（屏幕坐标）
  ///
  /// **架构说明：**
  /// - 设置高亮区域
  /// - 设置组件位置和尺寸
  /// - 设置可见性
  void highlightZone(Rect zone) {
    _log.debug('Highlighting zone: $zone');

    _highlightZone = zone;

    // 更新组件位置和尺寸
    position.setValues(zone.left, zone.top);
    size.setValues(zone.width, zone.height);

    // 确保组件在最上层
    // priority = 1000;
  }

  /// 清除高亮
  ///
  /// **架构说明：**
  /// - 清除高亮区域
  /// - 设置为不可见
  void clearHighlight() {
    _log.debug('Clearing highlight');

    _highlightZone = null;
  }

  @override
  void render(Canvas canvas) {
    if (_highlightZone == null) {
      return;
    }

    // 绘制半透明背景
    final backgroundPaint = Paint()
      ..color = _highlightColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      backgroundPaint,
    );

    // 绘制虚线边框
    _drawDashedRect(canvas);

    // 绘制"放置到..."提示文本
    _paintHintText(canvas);
  }

  /// 绘制虚线矩形边框
  ///
  /// **架构说明：**
  /// - Flutter的Canvas不直接支持虚线
  /// - 使用PathEffect创建虚线效果
  void _drawDashedRect(Canvas canvas) {
    final borderPaint = Paint()
      ..color = _borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // 创建虚线路径
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.x, size.y));

    // 使用DashPathEffect创建虚线效果
    // 参数：虚线长度、间隔长度
    final dashPath = _createDashPath(path, const [10.0, 5.0]);

    canvas.drawPath(dashPath, borderPaint);
  }

  /// 创建虚线路径
  ///
  /// [source] - 源路径
  /// [dashArray] - 虚线模式 [线段长度, 间隔长度, ...]
  ///
  /// 返回虚线路径
  Path _createDashPath(Path source, List<double> dashArray) {
    final dashPath = Path();
    var distance = 0.0;
    var dashIndex = 0;
    var draw = true;

    for (final metric in source.computeMetrics()) {
      while (distance < metric.length) {
        final length = dashArray[dashIndex % dashArray.length];
        if (draw) {
          dashPath.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        dashIndex++;
        draw = !draw;
      }
      distance = 0.0;
      dashIndex = 0;
      draw = true;
    }

    return dashPath;
  }

  /// 绘制提示文本
  ///
  /// **架构说明：**
  /// - 在高亮区域中心显示文本
  /// - 使用TextPainter绘制文本
  void _paintHintText(Canvas canvas) {
    // 创建文本样式
    const textStyle = TextStyle(
      color: Color(0xFFFFFFFF), // 白色
      fontSize: 14,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          color: Color(0x80000000), // 黑色阴影
          offset: Offset(1, 1),
          blurRadius: 2,
        ),
      ],
    );

    // 创建文本绘制器
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '放置到这里',
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // 计算文本布局
    textPainter.layout();

    // 计算文本位置（居中）
    final textOffset = Offset(
      (size.x - textPainter.width) / 2,
      (size.y - textPainter.height) / 2,
    );

    // 绘制文本
    textPainter.paint(canvas, textOffset);
  }

  @override
  void onRemove() {
    clearHighlight();
    super.onRemove();
  }
}
