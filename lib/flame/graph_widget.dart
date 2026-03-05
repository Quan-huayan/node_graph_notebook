import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../core/services/theme/app_theme.dart';
import '../../ui/models/node_model.dart';
import '../../ui/models/ui_model.dart';
import 'graph_world.dart';

/// Flame 游戏实例
class GraphGame extends FlameGame {
  GraphGame({
    required this.graph,
    required this.nodes,
    required this.connections,
    required this.viewConfig,
    required this.uiModel,
    required this.theme,
    this.onTap,
    this.onDragEnd,
    this.onSecondaryTap,
    this.onDoubleTap,
    this.onZoomChanged,
  });

  final Graph graph;
  final List<Node> nodes;
  final List<Connection> connections;
  final GraphViewConfig viewConfig;
  final UIModel uiModel;
  final AppThemeData theme;
  final Function(Node)? onTap;
  final Function(Node, Offset)? onDragEnd;
  final Function(Node, Offset)? onSecondaryTap;
  final Function(Node)? onDoubleTap;
  final Function(double)? onZoomChanged;

  GraphWorld? _graphWorld;

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
      graph: graph,
      nodes: nodes,
      connections: connections,
      viewConfig: viewConfig,
      uiModel: uiModel,
      theme: theme,
      onTap: onTap,
      onDragEndCallback: onDragEnd,
      onSecondaryTap: onSecondaryTap,
      onDoubleTap: onDoubleTap,
    );

    await world.add(_graphWorld!);
  }

  /// 处理滚轮缩放
  void handleZoom(double delta) {
    if (_graphWorld == null) return;

    // 缩放系数
    const zoomFactor = 0.001;
    final zoomChange = delta * zoomFactor;

    // 计算新的缩放级别 - 使用 camera viewport 的缩放
    final currentZoom = camera.viewport.position.length;
    var newZoom = currentZoom + zoomChange;

    // 限制缩放范围
    newZoom = newZoom.clamp(0.1, 5.0);

    // 通知外部缩放变化
    onZoomChanged?.call(newZoom);
  }

  /// 更新节点
  void updateGraphNode(Node node) {
    _graphWorld?.updateNode(node);
  }

  /// 添加节点
  void addGraphNode(Node node) {
    _graphWorld?.addNode(node);
  }

  /// 移除节点
  void removeGraphNode(String nodeId) {
    _graphWorld?.removeNode(nodeId);
  }

  /// 更新游戏中的所有节点
  void updateGameNodes(List<Node> newNodes, List<Connection> newConnections) {
    _graphWorld?.updateAllNodes(newNodes, newConnections);
  }

  /// 设置选中的节点
  void setSelectedNode(String? nodeId) {
    _graphWorld?.setSelectedNode(nodeId);
  }
}

/// Flame 图视图 Widget
class GraphFlameWidget extends StatefulWidget {
  const GraphFlameWidget({
    super.key,
    required this.graph,
    required this.nodes,
    required this.connections,
    required this.viewConfig,
    required this.uiModel,
    required this.theme,
    this.onTap,
    this.onDragEnd,
    this.onSecondaryTap,
    this.onDoubleTap,
    this.onZoomChanged,
    this.onNodeDropped,
  });

  final Graph graph;
  final List<Node> nodes;
  final List<Connection> connections;
  final GraphViewConfig viewConfig;
  final UIModel uiModel;
  final AppThemeData theme;
  final Function(Node)? onTap;
  final Function(Node, Offset)? onDragEnd;
  final Function(Node, Offset)? onSecondaryTap;
  final Function(Node)? onDoubleTap;
  final Function(double)? onZoomChanged;
  final Function(String nodeId, Offset position)? onNodeDropped;

  @override
  State<GraphFlameWidget> createState() => _GraphFlameWidgetState();
}

class _GraphFlameWidgetState extends State<GraphFlameWidget> {
  late GraphGame _game;
  String? _selectedNodeId;
  bool _gameLoaded = false;
  final GlobalKey _widgetKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _game = GraphGame(
      graph: widget.graph,
      nodes: widget.nodes,
      connections: widget.connections,
      viewConfig: widget.viewConfig,
      uiModel: widget.uiModel,
      theme: widget.theme,
      onTap: widget.onTap,
      onDragEnd: widget.onDragEnd,
      onSecondaryTap: widget.onSecondaryTap,
      onDoubleTap: widget.onDoubleTap,
      onZoomChanged: widget.onZoomChanged,
    );

    // 监听游戏加载完成
    _game.onLoad().then((_) {
      if (mounted) {
        setState(() {
          _gameLoaded = true;
        });
        _updateSelectedNode();
      }
    });
  }

  void _updateSelectedNode() {
    if (!_gameLoaded) return;

    final nodeModel = context.read<NodeModel>();
    final newSelectedId = nodeModel.selectedNode?.id;

    if (newSelectedId != _selectedNodeId) {
      _selectedNodeId = newSelectedId;
      _game.setSelectedNode(newSelectedId);
    }
  }

  @override
  void didUpdateWidget(GraphFlameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 更新选中的节点（仅在游戏加载完成后）
    if (_gameLoaded) {
      _updateSelectedNode();
    }

    // 总是更新游戏节点（用于 toggle 显示/隐藏等）
    // 因为 UIModel 的属性变化不会触发 widget 的重建
    if (_gameLoaded) {
      _game.updateGameNodes(widget.nodes, widget.connections);
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
              // 将屏幕坐标转换为Flame游戏世界坐标
              final screenSize = Size(
                constraints.maxWidth.isInfinite ? MediaQuery.of(context).size.width : constraints.maxWidth,
                constraints.maxHeight.isInfinite ? MediaQuery.of(context).size.height : constraints.maxHeight,
              );

              // Flame游戏配置的虚拟分辨率
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

              return Container(
                decoration: isDraggingOver
                    ? BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.5),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      )
                    : null,
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
