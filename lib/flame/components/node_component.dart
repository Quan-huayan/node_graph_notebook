import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:node_graph_notebook/ui/blocs/blocs.dart';
import '../../core/models/models.dart';
import '../../core/services/theme/app_theme.dart';

/// Flame 节点渲染组件（BLoC 集成版本）
class NodeComponent extends PositionComponent with DragCallbacks, TapCallbacks, SecondaryTapCallbacks, DoubleTapCallbacks {
  NodeComponent({
    required this.node,
    required this.viewConfig,
    required this.theme,
    this.bloc,
    this.onTap,
    this.onDragUpdateCallback,
    this.onDragEndCallback,
    this.onSecondaryTap,
    this.onDoubleTap,
    Vector2? position,
  }) : super(
          position: position ??
              Vector2(node.position.dx.toDouble(), node.position.dy.toDouble()),
          size: _calculateSize(node),
        ) {
    _initPaints();
    _initTextPainters();
  }

  static Vector2 _calculateSize(Node node) {
    // 文件夹节点使用稍大的尺寸
    if (node.isFolder) {
      return Vector2(200, 80);
    }
    switch (node.viewMode) {
      case NodeViewMode.titleOnly:
        return Vector2(150, 40);
      case NodeViewMode.compact:
        return Vector2(80, 80);
      case NodeViewMode.titleWithPreview:
        return Vector2(250, 120);
      case NodeViewMode.fullContent:
        return Vector2(400, 300);
    }
  }

  final Node node;
  final GraphViewConfig viewConfig;
  final AppThemeData theme;
  final GraphBloc? bloc; // 可选的 BLoC，如果提供则使用 BLoC 模式
  final Function(Node)? onTap;
  final Function(Node, Offset)? onDragUpdateCallback; // 拖拽过程中回调
  final Function(Node, Offset)? onDragEndCallback;
  final Function(Node, Offset)? onSecondaryTap;
  final Function(Node)? onDoubleTap;

  bool _isSelected = false;
  bool _isHovered = false;
  late Paint _borderPaint;
  late Paint _backgroundPaint;
  late Paint _selectedPaint;
  late TextPainter _titlePainter;
  late TextPainter _contentPainter;
  late TextPainter _fullContentPainter;

  void _initPaints() {
    // 边框
    _borderPaint = Paint()
      ..color = _getNodeColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _getStrokeWidth();

    // 背景
    _backgroundPaint = Paint()
      ..color = _getBackgroundColor()
      ..style = PaintingStyle.fill;

    // 选中状态
    _selectedPaint = Paint()
      ..color = theme.nodes.selectedOverlay
      ..style = PaintingStyle.fill;
  }

  double _getStrokeWidth() {
    if (node.isFolder) return 2.5;
    switch (node.viewMode) {
      case NodeViewMode.compact:
        return 1.5;
      default:
        return 2.0;
    }
  }

  void _initTextPainters() {
    // 标题
    final titleFontSize = _getTitleFontSize();
    _titlePainter = TextPainter(
      text: TextSpan(
        text: node.title,
        style: TextStyle(
          color: theme.text.primary,
          fontSize: titleFontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    _titlePainter.layout(maxWidth: width - 16);

    // 根据视图模式初始化内容绘制器
    if (node.isFolder) {
      // 文件夹节点显示包含的节点数量
      final childCount = node.references.values
          .where((ref) => ref.type == ReferenceType.contains)
          .length;
      _contentPainter = TextPainter(
        text: TextSpan(
          text: '$childCount item${childCount != 1 ? "s" : ""}',
          style: TextStyle(
            color: theme.text.secondary,
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      _contentPainter.layout();
      return;
    }

    switch (node.viewMode) {
      case NodeViewMode.titleOnly:
        // 不需要内容绘制器
        break;
      case NodeViewMode.compact:
        // 紧凑模式只显示首字母
        _contentPainter = TextPainter(
          text: TextSpan(
            text: node.title.isNotEmpty ? node.title[0].toUpperCase() : '?',
            style: TextStyle(
              color: theme.text.onDark,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        _contentPainter.layout();
        break;
      case NodeViewMode.titleWithPreview:
        final preview = _getPreviewText();
        _contentPainter = TextPainter(
          text: TextSpan(
            text: preview,
            style: TextStyle(
              color: theme.text.secondary,
              fontSize: 12,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 3,
          ellipsis: '...',
        );
        _contentPainter.layout(maxWidth: width - 16);
        break;
      case NodeViewMode.fullContent:
        if (node.content != null && node.content!.isNotEmpty) {
          _fullContentPainter = TextPainter(
            text: TextSpan(
              text: node.content,
              style: TextStyle(
                color: theme.text.primary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          _fullContentPainter.layout(maxWidth: width - 16);
        }
        break;
    }
  }

  double _getTitleFontSize() {
    if (node.isFolder) return 14;
    switch (node.viewMode) {
      case NodeViewMode.compact:
        return 10;
      case NodeViewMode.titleOnly:
        return 12;
      case NodeViewMode.titleWithPreview:
        return 14;
      case NodeViewMode.fullContent:
        return 16;
    }
  }

  Color _getNodeColor() {
    if (node.color != null) {
      return Color(int.parse(node.color!, radix: 16));
    }
    if (node.isFolder) {
      return theme.nodes.folderPrimary;
    }
    return theme.nodes.nodePrimary;
  }

  Color _getBackgroundColor() {
    if (_isHovered) {
      return theme.nodes.hoverBackground;
    }
    if (node.isFolder) {
      return theme.nodes.folderBackground;
    }
    switch (node.viewMode) {
      case NodeViewMode.compact:
        return _getNodeColor();
      default:
        return theme.nodes.nodeBackground;
    }
  }

  String _getPreviewText() {
    if (node.content == null) return '';
    final lines = node.content!.split('\n');
    final contentLines = lines.skip(1).where((l) => l.isNotEmpty).take(3);
    return contentLines.join('\n');
  }

  @override
  void render(Canvas canvas) {
    // 文件夹节点使用特殊渲染
    if (node.isFolder) {
      _renderFolder(canvas);
      return;
    }
    // 根据视图模式渲染不同形状
    switch (node.viewMode) {
      case NodeViewMode.compact:
        _renderCompact(canvas);
        break;
      default:
        _renderStandard(canvas);
        break;
    }
  }

  void _renderFolder(Canvas canvas) {
    // 绘制文件夹图标样式的背景
    final path = Path();
    final tabWidth = 40.0;
    final tabHeight = 15.0;

    // 文件夹标签
    path.moveTo(8, 0);
    path.lineTo(8 + tabWidth, 0);
    path.lineTo(8 + tabWidth + 8, tabHeight);
    path.lineTo(width - 8, tabHeight);
    path.lineTo(width - 8, height - 8);
    path.lineTo(8, height - 8);
    path.close();

    canvas.drawPath(path, _backgroundPaint);

    // 绘制边框
    canvas.drawPath(path, _borderPaint);

    // 绘制选中状态
    if (_isSelected) {
      canvas.drawPath(path, _selectedPaint);
    }

    // 绘制文件夹图标
    canvas.drawCircle(const Offset(20, 20), 8, _borderPaint);

    // 绘制标题
    _titlePainter.paint(canvas, const Offset(36, 10));

    // 绘制子项数量
    _contentPainter.paint(canvas, Offset(36, _titlePainter.height + 14));

    // 绘制引用计数
    _drawReferenceCount(canvas);
  }

  void _renderStandard(Canvas canvas) {
    // 绘制背景（圆角矩形）
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        const Radius.circular(8),
      ),
      _backgroundPaint,
    );

    // 绘制选中状态
    if (_isSelected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, width, height),
          const Radius.circular(8),
        ),
        _selectedPaint,
      );
    }

    // 绘制边框
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        const Radius.circular(8),
      ),
      _borderPaint,
    );

    // 绘制内容
    _renderContent(canvas);
  }

  void _renderCompact(Canvas canvas) {
    final centerX = width / 2;
    final centerY = height / 2;

    // 绘制圆形背景
    canvas.drawCircle(
      Offset(centerX, centerY),
      width / 2 - 2,
      _backgroundPaint,
    );

    // 绘制选中状态
    if (_isSelected) {
      canvas.drawCircle(
        Offset(centerX, centerY),
        width / 2 - 2,
        _selectedPaint,
      );
    }

    // 绘制边框
    canvas.drawCircle(
      Offset(centerX, centerY),
      width / 2 - 2,
      _borderPaint,
    );

    // 绘制首字母
    if (node.viewMode == NodeViewMode.compact) {
      _contentPainter.paint(
        canvas,
        Offset(centerX - _contentPainter.width / 2, centerY - _contentPainter.height / 2),
      );
    }
  }

  void _renderContent(Canvas canvas) {
    switch (node.viewMode) {
      case NodeViewMode.titleOnly:
        _titlePainter.paint(canvas, const Offset(8, 8));
        break;
      case NodeViewMode.compact:
        // 已在 _renderCompact 中处理
        break;
      case NodeViewMode.titleWithPreview:
        _titlePainter.paint(canvas, const Offset(8, 8));
        _contentPainter.paint(canvas, Offset(8, _titlePainter.height + 8));
        break;
      case NodeViewMode.fullContent:
        _titlePainter.paint(canvas, const Offset(8, 8));
        final painter = _fullContentPainter;
        // ignore: unnecessary_null_comparison
        if (painter != null) {
          painter.paint(canvas, Offset(8, _titlePainter.height + 12));
        }
        break;
    }

    // 绘制引用计数（非紧凑模式）
    if (node.viewMode != NodeViewMode.compact) {
      _drawReferenceCount(canvas);
    }
  }

  void _drawReferenceCount(Canvas canvas) {
    if (node.references.isEmpty) return;

    final countText = '${node.references.length}';
    final countPainter = TextPainter(
      text: TextSpan(
        text: countText,
        style: TextStyle(
          color: theme.ui.badge,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    countPainter.layout();

    final badgePaint = Paint()
      ..color = theme.ui.badgeBackground
      ..style = PaintingStyle.fill;

    final badgeSize = 18.0;
    final badgePosition = Offset(width - badgeSize - 4, height - badgeSize - 4);

    canvas.drawCircle(
      Offset(badgePosition.dx + badgeSize / 2, badgePosition.dy + badgeSize / 2),
      badgeSize / 2,
      badgePaint,
    );

    countPainter.paint(
      canvas,
      Offset(
        badgePosition.dx + (badgeSize - countPainter.width) / 2,
        badgePosition.dy + (badgeSize - countPainter.height) / 2,
      ),
    );
  }

  @override
  bool containsPoint(Vector2 point) {
    switch (node.viewMode) {
      case NodeViewMode.compact:
        final centerX = width / 2;
        final centerY = height / 2;
        final distance = (point - Vector2(centerX, centerY)).length;
        return distance <= width / 2;
      default:
        return point.x >= 0 && point.x <= width && point.y >= 0 && point.y <= height;
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _isSelected = true;
    _backgroundPaint.color = theme.backgrounds.tertiary;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    position += event.localDelta;

    // 拖拽过程中实时通知更新连线位置
    final currentPosition = Offset(position.x, position.y);
    onDragUpdateCallback?.call(node, currentPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _backgroundPaint.color = _getBackgroundColor();

    final newPosition = Offset(position.x, position.y);

    // 如果有 BLoC，分发移动事件
    if (bloc != null) {
      bloc!.add(NodeMoveEvent(node.id, newPosition));
    }

    // 保留旧回调以兼容非 BLoC 模式
    onDragEndCallback?.call(node, newPosition);
  }

  @override
  void onTapDown(TapDownEvent event) {
    _isHovered = true;
  }

  @override
  void onTapUp(TapUpEvent event) {
    _isSelected = !_isSelected;

    // 如果有 BLoC，分发选择事件
    if (bloc != null) {
      bloc!.add(NodeSelectEvent(node.id));
    }

    onTap?.call(node);
    _isHovered = false;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _isHovered = false;
  }

  @override
  void onSecondaryTapDown(SecondaryTapDownEvent event) {
    // 使用 devicePosition 获取全局设备坐标
    onSecondaryTap?.call(node, Offset(event.devicePosition.x, event.devicePosition.y));
  }

  @override
  void onDoubleTapDown(DoubleTapDownEvent event) {
    onDoubleTap?.call(node);
  }

  void setSelected(bool selected) {
    _isSelected = selected;
  }

  void updateNode(Node newNode) {
    // 更新位置
    position = Vector2(
      newNode.position.dx.toDouble(),
      newNode.position.dy.toDouble(),
    );
    // 重新计算尺寸
    size = _calculateSize(newNode);
    // 重新初始化绘制
    _initPaints();
    _initTextPainters();
  }
}
