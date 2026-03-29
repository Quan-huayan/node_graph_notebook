import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import 'spatial_index_manager.dart';

/// 视锥裁剪管理器
///
/// 根据相机可见区域动态控制节点的可见性
/// 只渲染可见区域内的节点，大幅提升性能
class ViewFrustumCuller {
  /// 构造函数
  ViewFrustumCuller({
    this.updateInterval = 0.1, // 更新间隔（秒）
    this.paddingFactor = 1.2, // 可见区域扩展因子（避免边缘闪烁）
  });

  /// 更新间隔（秒）
  final double updateInterval;

  /// 可见区域扩展因子
  /// 1.0 表示精确匹配，1.2 表示扩展20%
  final double paddingFactor;

  /// 空间索引管理器
  late final SpatialIndexManager _spatialIndex;

  /// 上次更新时间
  double _lastUpdateTime = 0;

  /// 当前可见边界
  Rect? _currentVisibleBounds;

  /// 上次可见边界
  Rect? _lastVisibleBounds;

  /// 父组件（用于添加/移除节点）
  Component? _parent;

  /// 初始化
  ///
  /// [spatialIndex] 空间索引管理器
  /// [parent] 父组件（用于添加/移除节点）
  void init(SpatialIndexManager spatialIndex, Component parent) {
    _spatialIndex = spatialIndex;
    _parent = parent;
  }

  /// 更新可见节点
  ///
  /// [camera] 相机组件
  /// [visibleRect] 可见矩形
  /// [dt] 时间增量
  void updateVisibleNodes(CameraComponent camera, Rect visibleRect, double dt) {
    if (_parent == null) return;

    _lastUpdateTime += dt;

    // 如果更新间隔未到，跳过
    if (_lastUpdateTime < updateInterval) {
      return;
    }

    _lastUpdateTime = 0.0;

    // 计算扩展后的可见边界
    final paddedBounds = _paddedBounds(visibleRect);

    // 如果可见边界没有变化，跳过更新
    if (_lastVisibleBounds != null &&
        _boundsSimilar(_lastVisibleBounds!, paddedBounds)) {
      return;
    }

    _currentVisibleBounds = paddedBounds;
    _lastVisibleBounds = paddedBounds;

    // 查询可见区域内的节点
    final visibleNodes = _spatialIndex.queryVisible(paddedBounds);

    // 更新所有节点的可见性（通过添加/移除）
    final allNodes = _spatialIndex.allNodes;
    final visibleIds = visibleNodes.map((n) => n.node.id).toSet();

    for (final node in allNodes) {
      final shouldBeVisible = visibleIds.contains(node.node.id);
      final isCurrentlyChild = _parent!.children.contains(node);

      if (shouldBeVisible && !isCurrentlyChild) {
        // 应该可见但当前不是子节点 - 添加到父组件
        _parent!.add(node);
      } else if (!shouldBeVisible && isCurrentlyChild) {
        // 不应该可见但是子节点 - 从父组件移除
        _parent!.remove(node);
      }
    }
  }

  /// 扩展可见边界
  ///
  /// [bounds] 原始边界
  /// 返回扩展后的边界
  Rect _paddedBounds(Rect bounds) {
    final paddingX = bounds.width * (paddingFactor - 1) / 2;
    final paddingY = bounds.height * (paddingFactor - 1) / 2;

    return Rect.fromLTRB(
      bounds.left - paddingX,
      bounds.top - paddingY,
      bounds.right + paddingX,
      bounds.bottom + paddingY,
    );
  }

  /// 比较两个边界是否相似
  ///
  /// [a] 边界A
  /// [b] 边界B
  /// 返回是否相似（差异小于10%）
  bool _boundsSimilar(Rect a, Rect b) {
    const threshold = 0.1; // 10%阈值

    final widthDiff = (a.width - b.width).abs() / a.width;
    final heightDiff = (a.height - b.height).abs() / a.height;
    final positionDiff = (a.topLeft - b.topLeft).distance /
        (a.width + a.height).abs().clamp(1.0, double.infinity);

    return widthDiff < threshold &&
        heightDiff < threshold &&
        positionDiff < threshold;
  }

  /// 强制更新可见节点（立即更新，不考虑间隔）
  void forceUpdate(CameraComponent camera, Rect visibleRect) {
    _lastUpdateTime = updateInterval; // 确保立即更新
    updateVisibleNodes(camera, visibleRect, 0);
  }

  /// 重置状态
  void reset() {
    _lastUpdateTime = 0.0;
    _currentVisibleBounds = null;
    _lastVisibleBounds = null;
  }

  /// 获取当前可见边界
  Rect? get currentVisibleBounds => _currentVisibleBounds;

  /// 获取可见节点数量
  int get visibleNodeCount {
    if (_currentVisibleBounds == null) return 0;
    return _spatialIndex.queryVisible(_currentVisibleBounds!).length;
  }

  /// 获取裁剪效率（0.0 - 1.0）
  /// 1.0 表示完美裁剪（只渲染可见节点）
  /// 0.0 表示无裁剪（渲染所有节点）
  double getCullingEfficiency() {
    final totalNodes = _spatialIndex.nodeCount;
    if (totalNodes == 0) return 1;

    final visibleCount = visibleNodeCount;
    return 1.0 - (visibleCount / totalNodes);
  }
}
