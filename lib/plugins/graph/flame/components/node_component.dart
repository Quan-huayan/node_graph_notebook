import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' hide Image;

import '../../../../../core/models/models.dart';
import '../../../../../core/services/theme/app_theme.dart';
import '../../bloc/graph_bloc.dart';
import '../../bloc/graph_event.dart';

/// Flame 节点渲染组件（BLoC 集成版本）
class NodeComponent extends PositionComponent
    with
        DragCallbacks,
        TapCallbacks,
        SecondaryTapCallbacks,
        DoubleTapCallbacks {
  /// 创建节点渲染组件
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
    this.onAIChatTap,
    Vector2? position,
  }) : super(
         position:
             position ??
             Vector2(node.position.dx.toDouble(), node.position.dy.toDouble()),
         size: _calculateSize(node),
       ) {
    _initPaints();
    _initTextPainters();
  }

  /// 计算节点大小
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

  /// 节点数据（可更新，通过 updateNode 方法同步最新状态）
  Node node;
  /// 视图配置
  final GraphViewConfig viewConfig;
  /// 应用主题
  final AppThemeData theme;
  /// 可选的 BLoC，如果提供则使用 BLoC 模式
  final GraphBloc? bloc;
  /// 点击回调
  final Function(Node)? onTap;
  /// 拖拽过程中回调
  final Function(Node, Offset)? onDragUpdateCallback;
  /// 拖拽结束回调
  final Function(Node, Offset)? onDragEndCallback;
  /// 右键点击回调
  final Function(Node, Offset)? onSecondaryTap;
  /// 双击回调
  final Function(Node)? onDoubleTap;
  /// AI 节点点击回调
  final Function(Node)? onAIChatTap;

  bool _isSelected = false;
  bool _isHovered = false;
  late Paint _borderPaint;
  late Paint _backgroundPaint;
  late Paint _selectedPaint;
  late TextPainter _titlePainter;
  late TextPainter _contentPainter;
  late TextPainter _fullContentPainter;
  TextPainter? _iconPainter; // 自定义图标绘制器（从 metadata['icon']）

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

    // 图标绘制器（如果节点有自定义图标）
    final icon = node.metadata['icon'] as String?;
    if (icon != null && icon.isNotEmpty) {
      _iconPainter = TextPainter(
        text: TextSpan(text: icon, style: const TextStyle(fontSize: 16)),
        textDirection: TextDirection.ltr,
      );
      _iconPainter!.layout();
    }
  }

  double _getStrokeWidth() {
    if (node.isFolder) return 2.5;
    switch (node.viewMode) {
      case NodeViewMode.compact:
        return 1.5;
      default:
        return 2;
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
      // 文件夹节点显示引用的节点数量
      final childCount = node.references.length;
      _contentPainter = TextPainter(
        text: TextSpan(
          text: '$childCount item${childCount != 1 ? "s" : ""}',
          style: TextStyle(color: theme.text.secondary, fontSize: 11),
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
        // 紧凑模式显示首字母或自定义图标
        final icon = node.metadata['icon'] as String?;
        final displayText = (icon != null && icon.isNotEmpty)
            ? icon
            : (node.title.isNotEmpty ? node.title[0].toUpperCase() : '?');
        _contentPainter = TextPainter(
          text: TextSpan(
            text: displayText,
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
            style: TextStyle(color: theme.text.secondary, fontSize: 12),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 3,
          ellipsis: '...',
        );
        _contentPainter.layout(maxWidth: width - 16);
        break;
      case NodeViewMode.fullContent:
        if (node.content != null && node.content!.isNotEmpty) {
          // 计算内容区域可用高度（节点高度 - 标题高度 - padding）
          final titleHeight = _titlePainter.height;
          final availableHeight =
              300 -
              titleHeight -
              24; // 8(top padding) + 8(title bottom) + 8(bottom padding)

          // 根据字体高度（fontSize * lineSpacing）计算最大行数
          const lineHeight = 11.0 * 1.4; // fontSize * height
          final maxLines = (availableHeight / lineHeight).floor();

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
            maxLines: maxLines > 0 ? maxLines : 1,
            ellipsis: '...',
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
      // 将十六进制颜色字符串（如 #FF6B6B）转换为 Color 对象
      final colorString = node.color!.replaceFirst('#', '0xFF');
      return Color(int.parse(colorString));
    }
    if (node.isFolder) {
      return theme.nodes.folderPrimary;
    }
    if (node.metadata.containsKey('isAI') && node.metadata['isAI'] == true) {
      return theme.status.info;
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
    if (node.metadata.containsKey('isAI') && node.metadata['isAI'] == true) {
      switch (node.viewMode) {
        case NodeViewMode.compact:
          return _getNodeColor();
        default:
          return theme.backgrounds.secondary;
      }
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
    // === 架构说明：节点类型渲染路由 ===
    // 设计意图：不同类型的节点使用不同的渲染方式
    // 实现方式：通过节点元数据判断类型，路由到对应的渲染方法
    // 扩展性：可添加更多特殊节点类型的渲染

    // AI 节点使用特殊渲染（显示 smart_toy 图标）
    if (node.metadata.containsKey('isAI') && node.metadata['isAI'] == true) {
      _renderAI(canvas);
      return;
    }

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
    const tabWidth = 40.0;
    const tabHeight = 15.0;

    // 文件夹标签
    path..moveTo(8, 0)
    ..lineTo(8 + tabWidth, 0)
    ..lineTo(8 + tabWidth + 8, tabHeight)
    ..lineTo(width - 8, tabHeight)
    ..lineTo(width - 8, height - 8)
    ..lineTo(8, height - 8)
    ..close();

    canvas..drawPath(path, _backgroundPaint)
    // 绘制边框
    ..drawPath(path, _borderPaint);

    // 绘制选中状态
    if (_isSelected) {
      canvas.drawPath(path, _selectedPaint);
    }

    // === 架构说明：文件夹图标渲染 ===
    // 设计意图：如果有自定义图标，显示自定义图标；否则显示默认文件夹圆圈
    // 实现方式：检查 _iconPainter，如果存在则绘制 emoji
    final hasCustomIcon = _iconPainter != null;
    final iconOffset = hasCustomIcon ? 28.0 : 0.0;

    if (hasCustomIcon) {
      // 绘制自定义图标
      _iconPainter!.paint(canvas, const Offset(10, 10));
    } else {
      // 绘制默认文件夹图标（圆圈）
      canvas.drawCircle(const Offset(20, 20), 8, _borderPaint);
    }

    // 绘制标题
    _titlePainter.paint(canvas, Offset(8 + iconOffset, 10));

    // 绘制子项数量
    _contentPainter.paint(
      canvas,
      Offset(8 + iconOffset, _titlePainter.height + 14),
    );

    // 绘制引用计数
    _drawReferenceCount(canvas);
  }

  /// === 架构说明：AI 节点渲染 ===
  /// 设计意图：AI 节点使用机器人图标（Icons.smart_toy）而非方框
  /// 功能：
  /// - 绘制圆形背景
  /// - 绘制机器人图标
  /// - 保持与其他节点一致的视觉风格
  ///
  /// 扩展性：可添加更多 AI 特定的视觉元素（如状态指示器等）
  void _renderAI(Canvas canvas) {
    final centerX = width / 2;
    final centerY = height / 2;
    final iconSize = width * 0.6; // 图标占节点 60% 大小

    // === 架构说明：AI 节点背景 ===
    // 设计意图：使用圆形背景突出 AI 节点
    // 颜色方案：使用主题色中的 info 色（通常为蓝色）
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
    canvas.drawCircle(Offset(centerX, centerY), width / 2 - 2, _borderPaint);

    // === 架构说明：AI 图标绘制 ===
    // 实现方式：使用 TextPainter 绘制 IconData
    // 说明：Flutter 的 Icons 通过 TextPainter 渲染到 Canvas
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.smart_toy.codePoint),
        style: TextStyle(
          color: _getNodeColor(),
          fontSize: iconSize,
          fontFamily: Icons.smart_toy.fontFamily,
          package: Icons.smart_toy.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )
    ..layout();

    // 居中绘制图标
    iconPainter.paint(
      canvas,
      Offset(centerX - iconPainter.width / 2, centerY - iconPainter.height / 2),
    );

    // 绘制引用计数（AI 节点也可能有连接）
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
    canvas.drawCircle(Offset(centerX, centerY), width / 2 - 2, _borderPaint);

    // 绘制首字母
    if (node.viewMode == NodeViewMode.compact) {
      _contentPainter.paint(
        canvas,
        Offset(
          centerX - _contentPainter.width / 2,
          centerY - _contentPainter.height / 2,
        ),
      );
    }
  }

  void _renderContent(Canvas canvas) {
    // === 架构说明：自定义图标渲染 ===
    // 设计意图：如果节点有自定义图标（metadata['icon']），在标题前显示
    // 实现方式：使用 TextPainter 绘制 emoji 字符
    // 位置：标题左侧，垂直居中对齐
    final hasCustomIcon = _iconPainter != null;
    final iconOffset = hasCustomIcon ? 20.0 : 0.0; // 为图标留出的空间

    switch (node.viewMode) {
      case NodeViewMode.titleOnly:
        if (hasCustomIcon) {
          _iconPainter!.paint(canvas, const Offset(8, 10));
        }
        _titlePainter.paint(canvas, Offset(8 + iconOffset, 8));
        break;
      case NodeViewMode.compact:
        // 已在 _renderCompact 中处理
        break;
      case NodeViewMode.titleWithPreview:
        if (hasCustomIcon) {
          _iconPainter!.paint(canvas, const Offset(8, 10));
        }
        _titlePainter.paint(canvas, Offset(8 + iconOffset, 8));
        _contentPainter.paint(
          canvas,
          Offset(8 + iconOffset, _titlePainter.height + 8),
        );
        break;
      case NodeViewMode.fullContent:
        if (hasCustomIcon) {
          _iconPainter!.paint(canvas, const Offset(8, 10));
        }
        _titlePainter.paint(canvas, Offset(8 + iconOffset, 8));
        final painter = _fullContentPainter;
        // ignore: unnecessary_null_comparison
        if (painter != null) {
          painter.paint(
            canvas,
            Offset(8 + iconOffset, _titlePainter.height + 12),
          );
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
    )
    ..layout();

    final badgePaint = Paint()
      ..color = theme.ui.badgeBackground
      ..style = PaintingStyle.fill;

    const badgeSize = 18.0;
    final badgePosition = Offset(width - badgeSize - 4, height - badgeSize - 4);

    canvas.drawCircle(
      Offset(
        badgePosition.dx + badgeSize / 2,
        badgePosition.dy + badgeSize / 2,
      ),
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
        return point.x >= 0 &&
            point.x <= width &&
            point.y >= 0 &&
            point.y <= height;
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

    // 拖拽过程中实时通知更新连线位置（发送中心点）
    final centerPosition = Offset(
      position.x + width / 2,
      position.y + height / 2,
    );
    onDragUpdateCallback?.call(node, centerPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _backgroundPaint.color = _getBackgroundColor();

    // 计算中心点位置
    final centerPosition = Offset(
      position.x + width / 2,
      position.y + height / 2,
    );

    // 如果有 BLoC，分发移动事件（存储中心点）
    if (bloc != null) {
      bloc!.add(NodeMoveEvent(node.id, centerPosition));
    }

    // 保留旧回调以兼容非 BLoC 模式
    onDragEndCallback?.call(node, centerPosition);
  }

  @override
  void onTapDown(TapDownEvent event) {
    _isHovered = true;
  }

  @override
  void onTapUp(TapUpEvent event) {
    // === 架构说明：AI 节点特殊处理 ===
    // 设计意图：AI 节点点击时打开聊天对话框，而不是常规选择
    // 实现方式：通过 onAIChatTap 回调通知外部显示对话框
    final isAINode =
        node.metadata.containsKey('isAI') && node.metadata['isAI'] == true;

    if (isAINode && onAIChatTap != null) {
      // AI 节点：打开聊天对话框
      onAIChatTap!(node);
      _isHovered = false;
      return;
    }

    // 常规节点：正常选择
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
    onSecondaryTap?.call(
      node,
      Offset(event.devicePosition.x, event.devicePosition.y),
    );
  }

  @override
  void onDoubleTapDown(DoubleTapDownEvent event) {
    onDoubleTap?.call(node);
  }

  /// 设置节点选中状态
  void setSelected(bool selected) {
    _isSelected = selected;
  }

  /// 更新节点数据
  ///
  /// 同步最新的节点数据到组件，包括位置、尺寸和渲染属性
  /// 🔥 优化：只在必要时重新创建渲染对象，避免不必要的内存分配和性能开销
  void updateNode(Node newNode) {
    // === 架构说明：节点数据同步 ===
    // 设计意图：同步最新的节点数据到组件
    // 实现方式：替换 node 引用，并更新相关的渲染属性
    // 注意：Node 是不可变对象，通过替换引用实现数据更新
    // 🔥 性能优化：增量更新，只在属性真正改变时重新创建对象

    final oldNode = node;
    node = newNode;

    // 🔥 优化：只更新位置（最常见的情况，不需要重新创建渲染对象）
    final newPosition = Vector2(
      newNode.position.dx.toDouble(),
      newNode.position.dy.toDouble(),
    );

    if (position != newPosition) {
      position = newPosition;
    }

    // 🔥 优化：检查哪些属性真正改变了，只重新创建必要的对象
    final needsSizeRecalculation = oldNode.viewMode != newNode.viewMode;
    final needsPaintRefresh = oldNode.color != newNode.color ||
                             oldNode.isFolder != newNode.isFolder ||
                             oldNode.metadata['isAI'] != newNode.metadata['isAI'] ||
                             oldNode.viewMode != newNode.viewMode;
    final needsTextRefresh = oldNode.title != newNode.title ||
                            oldNode.content != newNode.content ||
                            oldNode.viewMode != newNode.viewMode ||
                            oldNode.isFolder != newNode.isFolder ||
                            oldNode.references.length != newNode.references.length;

    // 只在需要时重新计算尺寸
    if (needsSizeRecalculation) {
      size = _calculateSize(newNode);
    }

    // 只在需要时重新初始化 Paint 对象
    if (needsPaintRefresh) {
      _updatePaints();
    }

    // 只在需要时重新初始化 TextPainter 对象
    if (needsTextRefresh) {
      _updateTextPainters(needsSizeRecalculation);
    }
  }

  /// 🔥 优化：增量更新 Paint 对象，只更新改变的属性
  void _updatePaints() {
    // 边框颜色或宽度可能改变
    _borderPaint
      ..color = _getNodeColor()
      ..strokeWidth = _getStrokeWidth();

    // 背景颜色可能改变
    _backgroundPaint.color = _getBackgroundColor();

    // 图标可能改变
    final icon = node.metadata['icon'] as String?;
    if (icon != null && icon.isNotEmpty) {
      if (_iconPainter == null) {
        _iconPainter = TextPainter(
          text: TextSpan(text: icon, style: const TextStyle(fontSize: 16)),
          textDirection: TextDirection.ltr,
        );
        _iconPainter!.layout();
      }
    } else {
      _iconPainter = null;
    }
  }

  /// 🔥 优化：增量更新 TextPainter 对象，只更新改变的内容
  void _updateTextPainters(bool needsLayout) {
    // 标题可能改变
    final titleFontSize = _getTitleFontSize();
    if (_titlePainter.text?.toPlainText() != node.title ||
        _titlePainter.text?.style?.fontSize != titleFontSize) {
      _titlePainter.text = TextSpan(
        text: node.title,
        style: TextStyle(
          color: theme.text.primary,
          fontSize: titleFontSize,
          fontWeight: FontWeight.bold,
        ),
      );
      _titlePainter.layout(maxWidth: width - 16);
    } else if (needsLayout) {
      _titlePainter.layout(maxWidth: width - 16);
    }

    // 内容可能改变
    _updateContentPainter(needsLayout);
  }

  /// 🔥 优化：更新内容绘制器
  void _updateContentPainter(bool needsLayout) {
    if (node.isFolder) {
      // 文件夹节点显示引用的节点数量
      final childCount = node.references.length;
      final newText = '$childCount item${childCount != 1 ? "s" : ""}';
      if (_contentPainter.text?.toPlainText() != newText) {
        _contentPainter.text = TextSpan(
          text: newText,
          style: TextStyle(color: theme.text.secondary, fontSize: 11),
        );
        _contentPainter.layout();
      }
    } else {
      // 根据视图模式更新内容
      switch (node.viewMode) {
        case NodeViewMode.titleOnly:
          // titleOnly 模式没有内容绘制器
          break;

        case NodeViewMode.compact:
          // compact 模式不显示内容
          break;

        case NodeViewMode.titleWithPreview:
          final previewText = _getPreviewText();
          if (_contentPainter.text?.toPlainText() != previewText) {
            _contentPainter.text = TextSpan(
              text: previewText,
              style: TextStyle(
                color: theme.text.secondary,
                fontSize: 11,
                height: 1.4,
              ),
            );
            _contentPainter.layout(maxWidth: width - 16);
          } else if (needsLayout) {
            _contentPainter.layout(maxWidth: width - 16);
          }
          break;

        case NodeViewMode.fullContent:
          if (node.content != null && node.content!.isNotEmpty) {
            final titleHeight = _titlePainter.height;
            final width = size.x;
            final availableHeight = size.y -
                titleHeight -
                24; // 8(top padding) + 8(title bottom) + 8(bottom padding)

            const lineHeight = 11.0 * 1.4;
            final maxLines = (availableHeight / lineHeight).floor();

            if (_fullContentPainter.text?.toPlainText() != node.content) {
              _fullContentPainter.text = TextSpan(
                text: node.content,
                style: TextStyle(
                  color: theme.text.primary,
                  fontSize: 11,
                  height: 1.4,
                ),
              );
              _fullContentPainter.maxLines = maxLines > 0 ? maxLines : 1;
              _fullContentPainter.ellipsis = '...';
              _fullContentPainter.layout(maxWidth: width - 16);
            } else if (needsLayout) {
              _fullContentPainter.layout(maxWidth: width - 16);
            }
          }
          break;
      }
    }
  }
}
