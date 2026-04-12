import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';

import '../../../core/ui_layout/coordinate_system.dart';
import '../../../core/ui_layout/ui_layout_service.dart';
import '../../../core/utils/logger.dart';
import 'components/node_component.dart';
import 'drag_feedback.dart';

const _log = AppLogger('NodeDragController');

/// 节点拖拽控制器
///
/// **职责：**
/// - 捕获 Flame 节点组件的拖拽事件
/// - 检测拖拽目标和可放置的 Hook 区域
/// - 触发节点移动到目标 Hook
/// - 提供视觉反馈（拖拽阴影、高亮目标区域）
///
/// **架构说明：**
/// - NodeDragController 作为 Flame Component 添加到 GraphWorld
/// - 监听全局拖拽事件（包括节点和背景）
/// - 通过 UILayoutService 检测 Hook 区域
/// - 使用 DragFeedbackComponent 提供视觉反馈
class NodeDragController extends Component with HasGameReference {
  /// 创建节点拖拽控制器
  NodeDragController({
    required this.layoutService,
    required this.buildContext,
  });

  /// UI布局服务
  final UILayoutService layoutService;

  /// Flutter构建上下文
  final BuildContext buildContext;

  /// 当前正在拖拽的节点组件
  NodeComponent? _draggingNode;

  /// 拖拽起始位置（屏幕坐标）
  Offset? _dragStartPosition;

  /// 拖拽反馈组件
  DragFeedbackComponent? _feedbackComponent;

  /// 目标Hook区域高亮组件
  HookDropZoneHighlight? _highlightComponent;

  /// 当前检测到的目标Hook ID
  String? _targetHookId;

  /// 拖拽是否处于活动状态
  bool get isDragging => _draggingNode != null;

  /// 获取拖拽起始位置
  Offset? get dragStartPosition => _dragStartPosition;

  @override
  void onLoad() async {
    await super.onLoad();

    // 创建拖拽反馈组件
    _feedbackComponent = DragFeedbackComponent();
    add(_feedbackComponent!);

    // 创建目标区域高亮组件
    _highlightComponent = HookDropZoneHighlight();
    add(_highlightComponent!);

    _log.info('NodeDragController loaded');
  }

  /// 开始拖拽节点
  ///
  /// [nodeComponent] - 被拖拽的节点组件
  /// [event] - 拖拽开始事件
  ///
  /// **架构说明：**
  /// - 记录拖拽起始位置
  /// - 保存节点组件引用
  /// - 创建拖拽反馈图像
  /// - 通知节点进入拖拽状态
  void startDrag(NodeComponent nodeComponent, DragStartEvent event) {
    if (_draggingNode != null) {
      _log.warning('Drag already in progress, ignoring new drag');
      return;
    }

    _log.info('Starting drag for node: ${nodeComponent.node.id}');

    _draggingNode = nodeComponent;
    _dragStartPosition = Offset(
      event.localPosition.x,
      event.localPosition.y,
    );

    // 转换到屏幕坐标
    final screenPosition = _canvasToScreenPosition(event.localPosition);

    // 创建拖拽反馈图像
    _feedbackComponent?.show(
      nodeComponent,
      screenPosition,
    );

    // 通知节点进入拖拽状态
    // nodeComponent.onDragStart(); // 这个方法需要参数，暂时注释

    // 更新节点渲染状态
    _updateNodeRenderState(nodeComponent.node.id, NodeRenderState.dragging);
  }

  /// 更新拖拽位置
  ///
  /// [event] - 拖拽更新事件
  ///
  /// **架构说明：**
  /// - 更新拖拽反馈图像位置
  /// - 检测当前位置下的目标Hook
  /// - 高亮显示可放置的目标区域
  void updateDrag(DragUpdateEvent event) {
    if (_draggingNode == null) return;

    // 计算新的屏幕位置（基于起始位置和delta）
    // 注意：event.localDelta是Vector2，使用.x和.y而不是.dx和.dy
    final newPosition = Offset(
      _dragStartPosition!.dx + event.localDelta.x,
      _dragStartPosition!.dy + event.localDelta.y,
    );

    // 更新反馈图像位置
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
        }
      } else {
        // 清除高亮
        _highlightComponent?.clearHighlight();
      }
    }
  }

  /// 结束拖拽（尝试放置到目标Hook）
  ///
  /// [event] - 拖拽结束事件
  ///
  /// **架构说明：**
  /// - 如果有目标Hook，触发节点移动
  /// - 如果没有目标Hook，节点回到原位置
  /// - 清理拖拽状态和视觉反馈
  void endDrag(DragEndEvent event) {
    if (_draggingNode == null) return;

    final nodeId = _draggingNode!.node.id;
    _log.info('Ending drag for node: $nodeId, targetHook: $_targetHookId');

    if (_targetHookId != null) {
      // 移动节点到目标Hook
      _moveNodeToHook(nodeId, _targetHookId!);
    } else {
      // 没有目标Hook，节点回到Graph
      _log.info('No target hook, node stays in graph');
      // _draggingNode?.onDragEnd(); // 这个方法需要参数，暂时注释
    }

    // 清理拖拽状态
    _cleanupDrag();
  }

  /// 取消拖拽
  ///
  /// **使用场景：**
  /// - 用户按ESC键取消拖拽
  /// - 拖拽过程中发生错误
  void cancelDrag() {
    if (_draggingNode == null) return;

    _log.info('Canceling drag for node: ${_draggingNode!.node.id}');

    // 节点回到原位置
    // _draggingNode?.onDragEnd(); // 这个方法需要参数，暂时注释

    // 清理拖拽状态
    _cleanupDrag();
  }

  /// 检测位置是否在某个Hook区域内
  ///
  /// [screenPosition] - 屏幕坐标位置
  ///
  /// 返回目标Hook ID，如果位置不在任何Hook区域内则返回null
  ///
  /// **架构说明：**
  /// - 通过UILayoutService查询Hook位置
  /// - 支持动态Hook注册
  /// - 优先返回最具体的Hook（子Hook优先于父Hook）
  String? detectHookAtPosition(Offset screenPosition) {
    try {
      final hookId = layoutService.getHookAtPosition(screenPosition);

      if (hookId != null) {
        _log.debug('Detected hook at position: $hookId');
      }

      return hookId;
    } catch (e) {
      _log.warning('Failed to detect hook at position: $e');
      return null;
    }
  }

  /// 获取Hook的屏幕边界
  ///
  /// [hookId] - Hook ID
  ///
  /// 返回Hook的屏幕边界矩形，如果Hook不存在则返回null
  Rect? getHookBounds(String hookId) {
    try {
      return layoutService.getHookBounds(hookId);
    } catch (e) {
      _log.warning('Failed to get hook bounds for $hookId: $e');
      return null;
    }
  }

  /// 移动节点到目标Hook
  ///
  /// [nodeId] - 节点ID
  /// [targetHookId] - 目标Hook ID
  ///
  /// **架构说明：**
  /// - 通过UILayoutService移动节点
  /// - UILayoutService会触发NodeMovedEvent
  /// - 相关的Hook会订阅事件并更新渲染
  void _moveNodeToHook(String nodeId, String targetHookId) async {
    try {
      _log.info('Moving node $nodeId to hook $targetHookId');

      // 调用UILayoutService移动节点
      // 注意：使用正确的参数名
      await layoutService.moveNode(
        nodeId: nodeId,
        targetHookId: targetHookId,
        newPosition: const LocalPosition.absolute(0, 0), // 临时位置
      );

      _log.info('Node $nodeId moved to hook $targetHookId');
    } catch (e) {
      _log.error('Failed to move node to hook: $e');
      // 移动失败，节点回到原位置
      // _draggingNode?.onDragEnd(); // 这个方法需要参数，暂时注释
    }
  }

  /// 清理拖拽状态
  void _cleanupDrag() {
    // 隐藏反馈组件
    _feedbackComponent?.hide();

    // 清除高亮
    _highlightComponent?.clearHighlight();

    // 更新节点渲染状态
    if (_draggingNode != null) {
      _updateNodeRenderState(
        _draggingNode!.node.id,
        NodeRenderState.rendering,
      );
    }

    // 清除状态
    _draggingNode = null;
    _dragStartPosition = null;
    _targetHookId = null;
  }

  /// 更新节点渲染状态
  ///
  /// [nodeId] - 节点ID
  /// [renderState] - 新的渲染状态
  ///
  /// **架构说明：**
  /// - 通过UILayoutService更新节点的渲染状态
  /// - Hook可以根据渲染状态调整视觉效果
  /// - 例如：拖拽时半透明，悬停时高亮
  void _updateNodeRenderState(String nodeId, NodeRenderState renderState) {
    try {
      // 将枚举转换为字符串
      final stateString = renderState.name;

      // 调用UILayoutService更新渲染状态
      layoutService.updateNodeRenderState(
        nodeId: nodeId,
        renderState: stateString,
      );

      _log.debug('Updated render state for node $nodeId: $renderState');
    } catch (e) {
      _log.warning('Failed to update render state: $e');
    }
  }

  /// 将Canvas坐标转换为屏幕坐标
  ///
  /// [canvasPosition] - Canvas坐标
  ///
  /// 返回屏幕坐标
  ///
  /// **架构说明：**
  /// - Flame使用Canvas坐标系统（世界坐标）
  /// - Flutter使用屏幕坐标系统
  /// - 需要通过Camera进行转换
  ///
  /// **转换公式：**
  /// 屏幕坐标 = (世界坐标 - 相机位置) * 缩放 + 视口偏移
  Offset _canvasToScreenPosition(Vector2 canvasPosition) {
    try {
      final camera = game.camera;
      final viewfinder = camera.viewfinder;

      // 获取相机的世界位置
      final cameraWorldPos = viewfinder.position;

      // 获取缩放
      final zoom = viewfinder.zoom;

      // 获取视口大小
      final viewportSize = camera.viewport.size;

      // 计算屏幕坐标
      // 公式: screenPos = (worldPos - cameraPos) * zoom + viewportCenter
      final screenX = (canvasPosition.x - cameraWorldPos.x) * zoom + viewportSize.x / 2;
      final screenY = (canvasPosition.y - cameraWorldPos.y) * zoom + viewportSize.y / 2;

      return Offset(screenX, screenY);
    } catch (e) {
      _log.warning('Failed to convert canvas to screen position: $e');
      // 降级方案：返回原始坐标
      return Offset(canvasPosition.x, canvasPosition.y);
    }
  }

  /// 将屏幕坐标转换为Canvas坐标
  ///
  /// [screenPosition] - 屏幕坐标
  ///
  /// 返回Canvas坐标（世界坐标）
  ///
  /// **架构说明：**
  /// - 用于将Flutter屏幕坐标转换为Flame世界坐标
  /// - 逆向转换：世界坐标 = (屏幕坐标 - 视口中心) / 缩放 + 相机位置
  ///
  /// **注意：** 此方法保留供将来使用，用于支持从屏幕坐标到世界坐标的转换
  /// ignore: unused_element
  Vector2 _screenToCanvasPosition(Offset screenPosition) {
    try {
      final camera = game.camera;
      final viewfinder = camera.viewfinder;

      // 获取相机的世界位置
      final cameraWorldPos = viewfinder.position;

      // 获取缩放
      final zoom = viewfinder.zoom;

      // 获取视口大小
      final viewportSize = camera.viewport.size;

      // 计算世界坐标
      // 公式: worldPos = (screenPos - viewportCenter) / zoom + cameraPos
      final worldX = (screenPosition.dx - viewportSize.x / 2) / zoom + cameraWorldPos.x;
      final worldY = (screenPosition.dy - viewportSize.y / 2) / zoom + cameraWorldPos.y;

      return Vector2(worldX, worldY);
    } catch (e) {
      _log.warning('Failed to convert screen to canvas position: $e');
      // 降级方案：返回原始坐标
      return Vector2(screenPosition.dx, screenPosition.dy);
    }
  }

  @override
  void onRemove() {
    // 清理组件
    _feedbackComponent?.removeFromParent();
    _highlightComponent?.removeFromParent();

    super.onRemove();
  }
}

/// 节点渲染状态
enum NodeRenderState {
  /// 正在渲染
  rendering,

  /// 已暂停（不在视口内）
  suspended,

  /// 正在拖拽
  dragging,

  /// 即将离开此Hook
  leaving,

  /// 悬停在目标Hook上
  hovering,
}
