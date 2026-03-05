import 'dart:async';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/models.dart';
import '../ui/blocs/blocs.dart';
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

  /// 获取 graph world
  GraphWorld? get graphWorld => _graphWorld;

  @override
  Color backgroundColor() => theme.backgrounds.canvas;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 如果已经初始化，不再重复添加
    if (_graphWorld != null) return;

    // 配置相机组件 - 使用更大的分辨率以容纳更多节点
    camera = CameraComponent.withFixedResolution(
      width: 4096,
      height: 2160,
    );

    // 设置相机位置到中心
    camera.viewport.position = Vector2(2048, 1080);

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
  }

  /// 处理滚轮缩放
  void handleZoom(double delta) {
    if (_graphWorld == null) return;

    // 缩放系数
    const zoomFactor = 0.001;
    final zoomChange = delta * zoomFactor;

    // 计算新的缩放级别
    final currentZoom = bloc.state.viewState.zoomLevel;
    var newZoom = currentZoom + zoomChange;

    // 限制缩放范围
    newZoom = newZoom.clamp(0.1, 5.0);

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
                child: GameWidget(
                  game: _game,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
