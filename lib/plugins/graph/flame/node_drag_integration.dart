import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui_layout/coordinate_system.dart';
import '../../../../core/ui_layout/ui_layout_service.dart';
import '../../../../core/utils/logger.dart';
import 'components/node_component.dart';
import 'drag_feedback.dart';

const _log = AppLogger('NodeDragIntegration');

/// 节点拖拽集成层（简化版本）
///
/// **职责：**
/// - 集成NodeDragController功能到NodeComponent
/// - 处理拖拽事件并触发节点流动
/// - 提供基本的拖拽反馈
///
/// **架构说明：**
/// - 这是一个临时的集成层，用于在NodeDragController完全实现之前提供基本功能
/// - 将来会被完整的NodeDragController替代
class NodeDragIntegration extends Component with HasGameReference {
  /// 创建节点拖拽集成层
  NodeDragIntegration({
    required this.layoutService,
    required this.buildContext,
  });

  /// UI布局服务
  final UILayoutService layoutService;

  /// Flutter构建上下文
  final BuildContext buildContext;

  /// 当前正在拖拽的节点组件
  NodeComponent? _draggingNode;

  /// 拖拽起始位置
  Offset? _dragStartPosition;

  /// 拖拽反馈组件
  DragFeedbackComponent? _feedbackComponent;

  /// 目标Hook区域高亮组件
  HookDropZoneHighlight? _highlightComponent;

  /// 当前检测到的目标Hook ID
  String? _targetHookId;

  @override
  void onLoad() async {
    await super.onLoad();

    // 创建拖拽反馈组件
    _feedbackComponent = DragFeedbackComponent();
    add(_feedbackComponent!);

    // 创建目标区域高亮组件
    _highlightComponent = HookDropZoneHighlight();
    add(_highlightComponent!);

    _log.info('NodeDragIntegration loaded');
  }

  /// 开始拖拽节点
  void startDrag(NodeComponent nodeComponent, DragStartEvent event) {
    if (_draggingNode != null) {
      _log.warning('Drag already in progress, ignoring new drag');
      return;
    }

    _log.info('Starting drag for node: ${nodeComponent.node.id}');

    _draggingNode = nodeComponent;

    // 使用event.localPosition获取本地坐标（Vector2转Offset）
    _dragStartPosition = Offset(
      event.localPosition.x,
      event.localPosition.y,
    );

    // 显示拖拽反馈
    if (_feedbackComponent != null) {
      _feedbackComponent!.show(nodeComponent, _dragStartPosition!);
      _log.debug('Showing drag feedback at: $_dragStartPosition');
    }
  }

  /// 更新拖拽位置
  void updateDrag(DragUpdateEvent event, NodeComponent nodeComponent) {
    if (_draggingNode == null || _draggingNode != nodeComponent) return;

    final localPosition = event.localDelta;
    _log.debug('Dragging delta: $localPosition');

    // 计算新的屏幕位置
    if (_dragStartPosition != null) {
      final newPosition = Offset(
        _dragStartPosition!.dx + event.localDelta.x,
        _dragStartPosition!.dy + event.localDelta.y,
      );

      // 更新反馈位置
      _feedbackComponent?.updatePosition(newPosition);

      // 检测目标Hook
      final newTargetHook = detectHookAtPosition(newPosition);

      // 如果目标Hook变化，更新高亮
      if (newTargetHook != _targetHookId) {
        _targetHookId = newTargetHook;

        if (newTargetHook != null) {
          // 高亮目标Hook区域
          final bounds = getHookBounds(newTargetHook);
          if (bounds != null) {
            _highlightComponent?.highlightZone(bounds);
            _log.debug('Highlighting hook: $newTargetHook');
          }
        } else {
          // 清除高亮
          _highlightComponent?.clearHighlight();
        }
      }
    }
  }

  /// 结束拖拽
  void endDrag(DragEndEvent event, NodeComponent nodeComponent) {
    if (_draggingNode == null || _draggingNode != nodeComponent) return;

    final nodeId = nodeComponent.node.id;
    _log.info('Ending drag for node: $nodeId, targetHook: $_targetHookId');

    // 如果有目标Hook，移动节点
    if (_targetHookId != null) {
      _moveNodeToHook(nodeId, _targetHookId!);
    } else {
      // 没有目标Hook，节点留在Graph中
      _log.debug('No target hook, node stays in graph');
    }

    // 清理拖拽状态
    _cleanupDrag();
  }

  /// 移动节点到目标Hook
  void _moveNodeToHook(String nodeId, String targetHookId) async {
    try {
      _log.info('Moving node $nodeId to hook $targetHookId');

      // 调用UILayoutService移动节点
      await layoutService.moveNode(
        nodeId: nodeId,
        targetHookId: targetHookId,
        newPosition: const LocalPosition.absolute(0, 0), // 临时位置
      );

      _log.info('Node $nodeId moved to hook $targetHookId');
    } catch (e) {
      _log.error('Failed to move node to hook: $e');
    }
  }

  /// 取消拖拽
  void cancelDrag() {
    if (_draggingNode == null) return;

    _log.info('Canceling drag for node: ${_draggingNode!.node.id}');

    // 清理拖拽状态
    _cleanupDrag();
  }

  /// 清理拖拽状态
  void _cleanupDrag() {
    // 隐藏反馈组件
    _feedbackComponent?.hide();

    // 清除高亮
    _highlightComponent?.clearHighlight();

    // 清除状态
    _draggingNode = null;
    _dragStartPosition = null;
    _targetHookId = null;
  }

  /// 检测位置是否在某个Hook区域内
  String? detectHookAtPosition(Offset screenPosition) {
    try {
      return layoutService.getHookAtPosition(screenPosition);
    } catch (e) {
      _log.warning('Failed to detect hook at position: $e');
      return null;
    }
  }

  /// 获取Hook的屏幕边界
  Rect? getHookBounds(String hookId) {
    try {
      return layoutService.getHookBounds(hookId);
    } catch (e) {
      _log.warning('Failed to get hook bounds for $hookId: $e');
      return null;
    }
  }
}
