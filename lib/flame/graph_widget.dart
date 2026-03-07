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
  Vector2? _positionBeforeDrag;
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

    // 设置相机初始位置到配置的中心
    final centerPos = cameraConfig.centerPosition;
    camera.viewport.position = Vector2(centerPos.dx.toDouble(), centerPos.dy.toDouble());

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

    // 只在非拖拽状态下同步位置，避免覆盖用户正在拖拽的位置
    if (!_isDragging && _pendingPosition == null) {
      // 应用相机位置
      final newPosition = Vector2(cameraState.position.dx, cameraState.position.dy);
      if (camera.viewport.position != newPosition) {
        camera.viewport.position = newPosition;
      }
    }

    // 应用相机缩放级别
    final newZoom = cameraState.zoom;
    if (camera.viewfinder.zoom != newZoom) {
      camera.viewfinder.zoom = newZoom;
    }
  }

  /// 设置拖拽状态（由 BackgroundComponent 调用）
  void setDraggingState(bool isDragging) {
    if (isDragging) {
      _isDragging = true;
      _positionBeforeDrag = camera.viewport.position.clone();
      _pendingPosition = null;
    } else {
      // 拖拽结束时，记录当前位置为待处理位置
      _pendingPosition = camera.viewport.position.clone();
      // 不要立即设置 _isDragging = false，等待状态同步
    }
  }

  /// 处理滚轮缩放
  void handleZoom(double delta, Offset? localPosition) {
    if (_graphWorld == null) return;

    // 缩放系数
    // 使用较小的系数以获得更平滑的缩放体验
    // 滚轮每次滚动产生的 delta 约为 100-200，乘以 0.001 后每次滚动变化约 10-20%
    const zoomFactor = 0.001;
    final zoomChange = delta * zoomFactor;

    // 计算新的缩放级别
    final currentZoom = bloc.state.viewState.zoomLevel;
    var newZoom = currentZoom * (1 + zoomChange);

    // 限制缩放范围
    newZoom = newZoom.clamp(0.1, 5.0);

    // 如果提供了鼠标位置，以鼠标位置为中心进行缩放
    if (localPosition != null) {
      // 计算鼠标在游戏世界中的位置
      final worldPosition = camera.localToGlobal(
        Vector2(localPosition.dx, localPosition.dy));

      // 计算缩放前后的差异
      final zoomRatio = newZoom / currentZoom;

      // 调整相机位置，使鼠标位置保持在屏幕上的同一位置
      final cameraPosition = camera.viewport.position;
      final newCameraPosition = Vector2(
        worldPosition.x - (worldPosition.x - cameraPosition.x) * zoomRatio,
        worldPosition.y - (worldPosition.y - cameraPosition.y) * zoomRatio,
      );

      // 更新相机位置
      camera.viewport.position = newCameraPosition;
    }

    // 分发缩放事件到 BLoC
    bloc.add(ViewZoomEvent(newZoom));

    // 通知外部缩放变化
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
