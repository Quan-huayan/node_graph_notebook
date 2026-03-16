import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/models/models.dart';

/// 图状态 - 整个图的不可变快照
@immutable
class GraphState extends Equatable {
  /// 创建图状态
  /// 
  /// [graph] - 当前图对象
  /// [nodes] - 图中的节点列表
  /// [connections] - 节点之间的连接关系
  /// [selectionState] - 选择状态
  /// [viewState] - 视图状态
  /// [loadingState] - 加载状态
  /// [error] - 错误信息
  const GraphState({
    required this.graph,
    required this.nodes,
    required this.connections,
    required this.selectionState,
    required this.viewState,
    required this.loadingState,
    this.error,
  });

  /// 初始状态
  factory GraphState.initial() {
    final now = DateTime.now();
    return GraphState(
      graph: Graph(
        id: '',
        name: '',
        nodeIds: const [],
        nodePositions: const {},
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: now,
        updatedAt: now,
      ),
      nodes: const [],
      connections: const [],
      selectionState: const SelectionState(),
      viewState: const ViewState(),
      loadingState: LoadingState.initial,
    );
  }

  /// 核心数据
  /// 当前图对象
  final Graph graph;
  
  /// 图中的节点列表
  final List<Node> nodes;
  
  /// 节点之间的连接关系
  final List<Connection> connections;

  /// 选择状态
  final SelectionState selectionState;

  /// 视图状态
  final ViewState viewState;

  /// 加载状态
  final LoadingState loadingState;

  /// 错误状态
  final String? error;

  /// 便捷方法
  /// 是否正在加载
  bool get isLoading => loadingState == LoadingState.loading;
  /// 是否已加载完成
  bool get isLoaded => loadingState == LoadingState.loaded;
  /// 是否有错误
  bool get hasError => error != null;
  /// 是否有图
  bool get hasGraph => graph.id.isNotEmpty;
  /// 选中的节点 ID 集合
  Set<String> get selectedNodeIds => selectionState.selectedNodeIds;

  /// 获取节点
  /// 
  /// [id] - 节点 ID
  /// 
  /// 返回对应的节点，如果不存在则返回 null
  Node? getNode(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  /// 获取节点位置
  /// 
  /// [id] - 节点 ID
  /// 
  /// 返回节点的位置，如果不存在则返回 null
  Offset? getNodePosition(String id) => graph.nodePositions[id];

  /// 复制并更新部分字段
  /// 
  /// [graph] - 当前图对象
  /// [nodes] - 图中的节点列表
  /// [connections] - 节点之间的连接关系
  /// [selectionState] - 选择状态
  /// [viewState] - 视图状态
  /// [loadingState] - 加载状态
  /// [error] - 错误信息
  GraphState copyWith({
    Graph? graph,
    List<Node>? nodes,
    List<Connection>? connections,
    SelectionState? selectionState,
    ViewState? viewState,
    LoadingState? loadingState,
    String? error,
  }) => GraphState(
      graph: graph ?? this.graph,
      nodes: nodes ?? this.nodes,
      connections: connections ?? this.connections,
      selectionState: selectionState ?? this.selectionState,
      viewState: viewState ?? this.viewState,
      loadingState: loadingState ?? this.loadingState,
      error: error,
    );

  @override
  List<Object?> get props => [
    graph,
    nodes,
    connections,
    selectionState,
    viewState,
    loadingState,
    error,
  ];
}

/// 选择状态
@immutable
class SelectionState extends Equatable {
  /// 创建选择状态
  /// 
  /// [selectedNodeIds] - 选中的节点 ID 集合
  /// [lastSelectedId] - 最后选中的节点 ID
  /// [selectionMode] - 选择模式
  const SelectionState({
    this.selectedNodeIds = const {},
    this.lastSelectedId,
    this.selectionMode = SelectionMode.single,
  });

  /// 选中的节点 ID 集合
  final Set<String> selectedNodeIds;
  /// 最后选中的节点 ID
  final String? lastSelectedId;
  /// 选择模式
  final SelectionMode selectionMode;

  /// 是否有选中的节点
  bool get hasSelection => selectedNodeIds.isNotEmpty;

  /// 选中的节点数量
  int get selectionCount => selectedNodeIds.length;

  /// 是否单选
  bool get isSingleSelection => selectionMode == SelectionMode.single;

  /// 是否多选
  bool get isMultiSelection => selectionMode == SelectionMode.multi;

  /// 复制并更新部分字段
  /// 
  /// [selectedNodeIds] - 选中的节点 ID 集合
  /// [lastSelectedId] - 最后选中的节点 ID
  /// [selectionMode] - 选择模式
  SelectionState copyWith({
    Set<String>? selectedNodeIds,
    String? lastSelectedId,
    SelectionMode? selectionMode,
  }) => SelectionState(
      selectedNodeIds: selectedNodeIds ?? this.selectedNodeIds,
      lastSelectedId: lastSelectedId ?? this.lastSelectedId,
      selectionMode: selectionMode ?? this.selectionMode,
    );

  @override
  List<Object?> get props => [selectedNodeIds, lastSelectedId, selectionMode];
}

/// 选择模式
enum SelectionMode {
  /// 单选模式
  single,
  /// 多选模式
  multi,
  /// 范围选择模式
  range
}

/// 视图状态
@immutable
class ViewState extends Equatable {
  /// 创建视图状态
  /// 
  /// [camera] - 相机状态
  /// [showConnections] - 是否显示连接线
  /// [gridVisible] - 是否显示网格
  /// [zoomLevel] - 缩放级别
  const ViewState({
    this.camera = const CameraState(),
    this.showConnections = true,
    this.gridVisible = true,
    this.zoomLevel = 1.0,
  });

  /// 相机状态
  final CameraState camera;
  /// 是否显示连接线
  final bool showConnections;
  /// 是否显示网格
  final bool gridVisible;
  /// 缩放级别
  final double zoomLevel;

  /// 复制并更新部分字段
  /// 
  /// [camera] - 相机状态
  /// [showConnections] - 是否显示连接线
  /// [gridVisible] - 是否显示网格
  /// [zoomLevel] - 缩放级别
  ViewState copyWith({
    CameraState? camera,
    bool? showConnections,
    bool? gridVisible,
    double? zoomLevel,
  }) => ViewState(
      camera: camera ?? this.camera,
      showConnections: showConnections ?? this.showConnections,
      gridVisible: gridVisible ?? this.gridVisible,
      zoomLevel: zoomLevel ?? this.zoomLevel,
    );

  @override
  List<Object?> get props => [camera, showConnections, gridVisible, zoomLevel];
}

/// 相机状态
@immutable
class CameraState extends Equatable {
  /// 创建相机状态
  /// 
  /// [position] - 相机位置
  /// [zoom] - 相机缩放级别
  const CameraState({this.position = Offset.zero, this.zoom = 1.0});

  /// 相机位置
  final Offset position;
  /// 相机缩放级别
  final double zoom;

  /// 复制并更新部分字段
  /// 
  /// [position] - 相机位置
  /// [zoom] - 相机缩放级别
  CameraState copyWith({Offset? position, double? zoom}) => CameraState(
      position: position ?? this.position,
      zoom: zoom ?? this.zoom,
    );

  @override
  List<Object?> get props => [position, zoom];
}

/// 加载状态
enum LoadingState {
  /// 初始状态
  initial,
  /// 加载中
  loading,
  /// 加载完成
  loaded,
  /// 加载错误
  error
}
