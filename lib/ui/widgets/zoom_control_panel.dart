import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/blocs.dart';

// 观感太差，暂时空置

/// 缩放控制面板
///
/// 显示在图视图的右下角，提供：
/// - 缩放级别显示（百分比）
/// - 缩放滑动条（快速调整）
/// - 缩放输入框（精确输入）
/// - 放大/缩小按钮（步进调整）
class ZoomControlPanel extends StatelessWidget {
  const ZoomControlPanel({
    super.key,
    required this.currentZoom,
  });

  final double currentZoom;

  @override
  Widget build(BuildContext context) {
    return Container(
      // === 面板容器设计 ===
      // 使用圆角矩形和半透明背景，使其悬浮在内容上方而不遮挡视野
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // 内边距：提供舒适的点击区域
      padding: const EdgeInsets.all(12),

      // === 面板内容布局 ===
      // 使用横向布局，从左到右：缩小按钮 | 滑动条 | 输入框 | 放大按钮
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 缩小按钮
          _ZoomButton(
            icon: Icons.remove,
            tooltip: '缩小 (Zoom Out)',
            onPressed: () => _adjustZoom(context, -0.1),
          ),

          const SizedBox(width: 8),

          // 缩放滑动条
          // 范围：10% - 500%，对应 zoom 值 0.1 - 5.0
          SizedBox(
            width: 150,
            child: Slider(
              value: currentZoom.clamp(0.1, 5.0),
              min: 0.1,
              max: 5.0,
              divisions: 49, // 将范围分为 49 个刻度，每个刻度 10%
              label: '${(currentZoom * 100).toStringAsFixed(0)}%',
              onChanged: (value) {
                _setZoom(context, value);
              },
            ),
          ),

          const SizedBox(width: 8),

          // 缩放输入框
          // 允许用户精确输入缩放比例（百分比）
          SizedBox(
            width: 70,
            child: TextField(
              key: ValueKey(currentZoom), // 当 zoom 变化时重建，更新显示值
              controller: TextEditingController(
                text: (currentZoom * 100).toStringAsFixed(0),
              ),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
                suffixText: '%',
                suffixStyle: TextStyle(fontSize: 10),
              ),
              onSubmitted: (value) {
                // 解析用户输入的百分比
                final percentage = double.tryParse(value);
                if (percentage != null && percentage >= 10 && percentage <= 500) {
                  _setZoom(context, percentage / 100);
                }
              },
            ),
          ),

          const SizedBox(width: 8),

          // 放大按钮
          _ZoomButton(
            icon: Icons.add,
            tooltip: '放大 (Zoom In)',
            onPressed: () => _adjustZoom(context, 0.1),
          ),
        ],
      ),
    );
  }

  /// 调整缩放级别（增量方式）
  ///
  /// 参数：
  /// - [context] - BuildContext，用于访问 BLoC
  /// - [delta] - 缩放增量（正数为放大，负数为缩小）
  ///
  /// 说明：
  /// - 以当前缩放级别为基础，增加或减少指定的量
  /// - 新的缩放级别会被限制在 0.1 - 5.0 范围内
  void _adjustZoom(BuildContext context, double delta) {
    final bloc = context.read<GraphBloc>();
    final currentZoom = bloc.state.viewState.zoomLevel;
    final newZoom = (currentZoom + delta).clamp(0.1, 5.0);
    bloc.add(ViewZoomEvent(newZoom));
  }

  /// 设置缩放级别（绝对值方式）
  ///
  /// 参数：
  /// - [context] - BuildContext，用于访问 BLoC
  /// - [zoom] - 目标缩放级别（0.1 - 5.0）
  ///
  /// 说明：
  /// - 直接设置指定的缩放级别
  /// - 用于滑动条拖动和输入框输入
  void _setZoom(BuildContext context, double zoom) {
    final bloc = context.read<GraphBloc>();
    final clampedZoom = zoom.clamp(0.1, 5.0);
    bloc.add(ViewZoomEvent(clampedZoom));
  }
}

/// 缩放按钮（放大/缩小）
class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}
