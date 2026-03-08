import 'dart:async';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/models.dart';
import '../bloc/blocs.dart';
import '../core/services/theme/app_theme.dart';
import 'graph_world.dart';

/// Flame 游戏实例 - BLoC 集成版本
class GraphGame extends FlameGame {
  GraphGame({
    required this.bloc,
    required this.uiState,
    required this.theme,
    required this.context,
    this.onZoomChanged,
  })  : graph = bloc.state.graph,
        nodes = bloc.state.nodes,
        connections = bloc.state.connections,
        viewConfig = bloc.state.graph.viewConfig;

  final GraphBloc bloc;
  final Graph graph;
  final List<Node> nodes;
  final List<Connection> connections;
  final GraphViewConfig viewConfig;
  final UIState uiState;
  final AppThemeData theme;
  final BuildContext context;
  final Function(double)? onZoomChanged;

  GraphWorld? _graphWorld;
  StreamSubscription? _blocSubscription;

  // 标识是否正在拖拽，避免状态同步覆盖当前位置
  bool _isDragging = false;
  Vector2? _pendingPosition; // 拖拽结束时的待处理位置

  /// 获取 graph world
  GraphWorld? get graphWorld => _graphWorld;

  @override
  Color backgroundColor() => theme.backgrounds.canvas;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 如果已经初始化，不再重复添加
    if (_graphWorld != null) return;

    // 从配置中读取相机中心位置
    final cameraConfig = viewConfig.camera;

    // 配置相机组件 - 使用配置的分辨率
    camera = CameraComponent.withFixedResolution(
      width: cameraConfig.centerWidth,
      height: cameraConfig.centerHeight,
    );

    // === 架构说明：相机初始化 ===
    // 必须从持久化的配置中恢复相机位置和缩放
    // viewConfig.camera 存储的是世界坐标系的位置

    // 初始化 viewfinder（世界坐标系）
    camera.viewfinder.position = Vector2(
      cameraConfig.x,  // ← 使用持久化的 x
      cameraConfig.y,  // ← 使用持久化的 y
    );
    camera.viewfinder.zoom = cameraConfig.zoom;  // ← 使用持久化的 zoom

    // 创建 GraphWorld 并添加到 FlameGame 的 world 中
    _graphWorld = GraphWorld(
      graphBloc: bloc,
      uiState: uiState,
      theme: theme,
      context: context,
    );

    await world.add(_graphWorld!);

    // 订阅 BLoC 状态变化以更新 Flame 组件
    _blocSubscription = bloc.stream.listen(_onStateChanged);
  }

  /// 处理 BLoC 状态变化
  void _onStateChanged(GraphState state) {
    // 注意：这里只做增量更新，不重新创建整个 world
    // 具体的更新逻辑在 GraphWorld 中通过订阅实现

    // === 相机状态同步 ===
    // 说明：由于 GraphWorld 无法访问 Flame 相机实例，相机相关的状态
    // 同步（缩放、位置等）需要在 GraphGame 层处理。

    final cameraState = state.viewState.camera;

    // 检查是否有待处理的位置（拖拽刚结束）
    if (_pendingPosition != null) {
      final pending = _pendingPosition!;
      final statePosition = Vector2(cameraState.position.dx, cameraState.position.dy);

      // 如果新状态位置与待处理位置一致，说明拖拽状态已同步
      if ((pending - statePosition).length < 1.0) {
        _pendingPosition = null;
        _isDragging = false;
      }
    }

    // === 架构说明：相机状态防抖同步 ===
    // 设计意图：避免状态循环导致的抖动
    // 实现方式：
    //   1. handleZoom/drag 先设置 camera.viewfinder（保证流畅）
    //   2. BLoC emit 状态
    //   3. 这里检查值是否真的变化再设置（避免循环）
    // 重要性：防止 handleZoom → ViewZoomEvent → emit → 这里设置 camera → 又触发...

    // 只在非拖拽状态下同步位置
    if (!_isDragging && _pendingPosition == null) {
      final newPosition = Vector2(cameraState.position.dx, cameraState.position.dy);
      // 使用距离检查避免浮点数精度问题
      if ((camera.viewfinder.position - newPosition).length > 0.1) {
        camera.viewfinder.position = newPosition;
      }
    }

    // 同步缩放级别（带防抖）
    final newZoom = cameraState.zoom;
    if ((camera.viewfinder.zoom - newZoom).abs() > 0.001) {
      camera.viewfinder.zoom = newZoom;
    }
  }

  /// 设置拖拽状态（由 BackgroundComponent 调用）
  void setDraggingState(bool isDragging) {
    if (isDragging) {
      _isDragging = true;
      _pendingPosition = null;
    } else {
      // 拖拽结束时，记录当前位置为待处理位置
      // 使用 viewfinder.position（世界坐标系）
      _pendingPosition = camera.viewfinder.position.clone();
      // 不要立即设置 _isDragging = false，等待状态同步
    }
  }

  /// 处理滚轮缩放
  void handleZoom(double delta, Offset? localPosition) {
    if (_graphWorld == null) return;

    // === 架构说明：Flame 坐标系统 ===
    //
    // **核心概念**：
    // 1. Viewport（视口）- 屏幕上的渲染区域
    //    - viewport.position: 视口左上角在屏幕上的位置
    //    - viewport.size: 视口的像素大小
    //
    // 2. Viewfinder（取景器）- 世界中的相机位置
    //    - viewfinder.position: 相机中心在世界坐标中的位置
    //    - viewfinder.zoom: 缩放级别
    //
    // **坐标转换**（在 CameraComponent.withFixedResolution 下）：
    // - 屏幕坐标需要转换为虚拟世界坐标
    // - 转换公式考虑了 viewfinder.position 和 zoom
    //
    // **关键理解**：
    // - event.localDelta 已经是处理过的增量，可以直接用于 viewfinder.position
    // - 但 localPosition 是屏幕坐标，需要转换为世界坐标
    //
    // **缩放逻辑**：
    // 为了让缩放以鼠标为中心，需要：
    // 1. 找到鼠标指向的世界坐标
    // 2. 缩放后，调整相机位置使该世界坐标仍在鼠标下

    const zoomFactor = 0.001;
    final zoomChange = -delta * zoomFactor;  // 反转符号：向上滚=放大

    final currentZoom = camera.viewfinder.zoom;
    final newZoom = (currentZoom * (1 + zoomChange)).clamp(0.1, 5.0);

    // 如果提供了鼠标位置，以鼠标位置为中心进行缩放
    if (localPosition != null) {
      final currentCameraPos = camera.viewfinder.position;

      // === 坐标转换：屏幕 → 世界 ===
      // 方法：利用 viewfinder.position 和 zoom
      //
      // 世界坐标 = 相机位置 + (屏幕坐标 - 视口中心) / zoom
      final viewportSize = camera.viewport.size;
      final viewportCenter = viewportSize / 2;

      // 鼠标相对于视口中心的偏移
      final offsetFromCenter = Vector2(
        localPosition.dx - viewportCenter.x,
        localPosition.dy - viewportCenter.y,
      );

      // 鼠标指向的世界坐标（缩放前）
      final mouseWorldPos = currentCameraPos + (offsetFromCenter / currentZoom);

      // === 缩放后调整相机位置 ===
      // 新的相机位置 = 鼠标世界坐标 - (屏幕偏移 / 新zoom)
      final offsetFromCenterNew = offsetFromCenter / newZoom;
      final newCameraPos = mouseWorldPos - offsetFromCenterNew;

      // 更新相机位置和缩放
      camera.viewfinder.position = newCameraPos;
      camera.viewfinder.zoom = newZoom;

      // 发送事件到 BLoC（包含位置信息）
      bloc.add(ViewZoomEvent(
        newZoom,
        position: Offset(newCameraPos.x, newCameraPos.y),
      ));
    } else {
      // 没有鼠标位置，只缩放不移动
      camera.viewfinder.zoom = newZoom;
      bloc.add(ViewZoomEvent(newZoom));
    }

    onZoomChanged?.call(newZoom);
  }

  @override
  void onRemove() {
    _blocSubscription?.cancel();
    super.onRemove();
  }
}

/// Flame 图视图 Widget - BLoC 集成版本
class GraphFlameWidget extends StatefulWidget {
  const GraphFlameWidget({
    super.key,
    required this.uiState,
    required this.theme,
    this.onZoomChanged,
    this.onNodeDropped,
  });

  final UIState uiState;
  final AppThemeData theme;
  final Function(double)? onZoomChanged;
  final Function(String nodeId, Offset position)? onNodeDropped;

  @override
  State<GraphFlameWidget> createState() => _GraphFlameWidgetState();
}

class _GraphFlameWidgetState extends State<GraphFlameWidget> {
  late GraphGame _game;
  final GlobalKey _widgetKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // 从 BLoC 获取 GraphBloc
    final bloc = context.read<GraphBloc>();

    _game = GraphGame(
      bloc: bloc,
      uiState: widget.uiState,
      theme: widget.theme,
      context: context,
      onZoomChanged: widget.onZoomChanged,
    );
  }

  @override
  void didUpdateWidget(GraphFlameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 更新主题或 UIState 变化
    if (oldWidget.theme != widget.theme || oldWidget.uiState != widget.uiState) {
      // 重新创建游戏（主题变化需要重建）
      // 实际应用中可能需要更细粒度的更新
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: _widgetKey,
      builder: (context, constraints) {
        // 确保占据整个可用空间
        return SizedBox(
          width: constraints.maxWidth.isInfinite
              ? double.infinity
              : constraints.maxWidth,
          height: constraints.maxHeight.isInfinite
              ? double.infinity
              : constraints.maxHeight,
          child: DragTarget<String>(
            onAcceptWithDetails: (details) {
              // 将屏幕坐标转换为 Flame 游戏世界坐标
              final screenSize = Size(
                constraints.maxWidth.isInfinite
                    ? MediaQuery.of(context).size.width
                    : constraints.maxWidth,
                constraints.maxHeight.isInfinite
                    ? MediaQuery.of(context).size.height
                    : constraints.maxHeight,
              );

              // Flame 游戏配置的虚拟分辨率
              const gameWidth = 4096.0;
              const gameHeight = 2160.0;

              // 相机中心位置
              const cameraX = 2048.0;
              const cameraY = 1080.0;

              // 坐标转换：屏幕坐标 → 游戏世界坐标
              final gamePosition = Offset(
                (details.offset.dx / screenSize.width) * gameWidth,
                (details.offset.dy / screenSize.height) * gameHeight,
              );

              // 调整相机偏移
              final worldPosition = Offset(
                gamePosition.dx + cameraX - gameWidth / 2,
                gamePosition.dy + cameraY - gameHeight / 2,
              );

              widget.onNodeDropped?.call(details.data, worldPosition);
            },
            builder: (context, candidateData, rejected) {
              // 检查是否正在拖拽节点
              final isDraggingOver = candidateData.isNotEmpty;

              return DecoratedBox(
                decoration: isDraggingOver
                    ? BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.5),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      )
                    : const BoxDecoration(), // TODO: 这可能是异常的。
                child: Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      // 处理鼠标滚轮事件
                      _game.handleZoom(
                        pointerSignal.scrollDelta.dy,
                        pointerSignal.localPosition,
                      );
                    }
                  },
                  child: GestureDetector(
                    onScaleUpdate: (details) {
                      // 处理触摸缩放
                      if (details.scale != 1.0) {
                        _game.handleZoom(
                          details.scale - 1.0,
                          details.localFocalPoint,
                        );
                      }
                    },
                    child: GameWidget(
                      game: _game,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
