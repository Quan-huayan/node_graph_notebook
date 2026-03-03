import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';

part 'graph.g.dart';

/// 图视图配置
@JsonSerializable()
class GraphViewConfig {
  const GraphViewConfig({
    required this.viewMode,
    required this.camera,
    required this.autoLayoutEnabled,
    required this.layoutAlgorithm,
    required this.showConceptNodes,
    required this.showConnectionLines,
    required this.backgroundStyle,
  });

  factory GraphViewConfig.fromJson(Map<String, dynamic> json) =>
      _$GraphViewConfigFromJson(json);

  /// 视图模式
  final ViewModeType viewMode;

  /// 相机位置和缩放
  final Camera camera;

  /// 是否启用自动布局
  final bool autoLayoutEnabled;

  /// 布局算法
  final LayoutAlgorithm layoutAlgorithm;

  /// 是否显示概念节点
  final bool showConceptNodes;

  /// 是否显示连接线
  final bool showConnectionLines;

  /// 背景样式
  final BackgroundStyle backgroundStyle;

  /// 默认配置
  static const defaultConfig = GraphViewConfig(
    viewMode: ViewModeType.normalGraph,
    camera: Camera(),
    autoLayoutEnabled: false,
    layoutAlgorithm: LayoutAlgorithm.forceDirected,
    showConceptNodes: true,
    showConnectionLines: true,
    backgroundStyle: BackgroundStyle.grid,
  );

  Map<String, dynamic> toJson() => _$GraphViewConfigToJson(this);

  GraphViewConfig copyWith({
    ViewModeType? viewMode,
    Camera? camera,
    bool? autoLayoutEnabled,
    LayoutAlgorithm? layoutAlgorithm,
    bool? showConceptNodes,
    bool? showConnectionLines,
    BackgroundStyle? backgroundStyle,
  }) {
    return GraphViewConfig(
      viewMode: viewMode ?? this.viewMode,
      camera: camera ?? this.camera,
      autoLayoutEnabled: autoLayoutEnabled ?? this.autoLayoutEnabled,
      layoutAlgorithm: layoutAlgorithm ?? this.layoutAlgorithm,
      showConceptNodes: showConceptNodes ?? this.showConceptNodes,
      showConnectionLines: showConnectionLines ?? this.showConnectionLines,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GraphViewConfig &&
          runtimeType == other.runtimeType &&
          viewMode == other.viewMode &&
          camera == other.camera;

  @override
  int get hashCode => viewMode.hashCode ^ camera.hashCode;
}

/// 相机配置
@JsonSerializable()
class Camera {
  const Camera({
    this.x = 0,
    this.y = 0,
    this.zoom = 1.0,
  });

  factory Camera.fromJson(Map<String, dynamic> json) =>
      _$CameraFromJson(json);

  /// X 坐标
  final double x;

  /// Y 坐标
  final double y;

  /// 缩放级别
  final double zoom;

  Map<String, dynamic> toJson() => _$CameraToJson(this);

  Camera copyWith({
    double? x,
    double? y,
    double? zoom,
  }) {
    return Camera(
      x: x ?? this.x,
      y: y ?? this.y,
      zoom: zoom ?? this.zoom,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Camera &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          zoom == other.zoom;

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ zoom.hashCode;
}

/// 图结构模型
@JsonSerializable()
class Graph {
  const Graph({
    required this.id,
    required this.name,
    required this.nodeIds,
    required this.viewConfig,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Graph.fromJson(Map<String, dynamic> json) => _$GraphFromJson(json);

  /// 图ID
  final String id;

  /// 图名称
  final String name;

  /// 节点ID列表
  final List<String> nodeIds;

  /// 视图配置
  final GraphViewConfig viewConfig;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$GraphToJson(this);

  /// 复制并更新部分字段
  Graph copyWith({
    String? id,
    String? name,
    List<String>? nodeIds,
    GraphViewConfig? viewConfig,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Graph(
      id: id ?? this.id,
      name: name ?? this.name,
      nodeIds: nodeIds ?? this.nodeIds,
      viewConfig: viewConfig ?? this.viewConfig,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 添加节点
  Graph addNode(String nodeId) {
    final newNodeIds = List<String>.from(nodeIds);
    if (!newNodeIds.contains(nodeId)) {
      newNodeIds.add(nodeId);
    }
    return copyWith(nodeIds: newNodeIds);
  }

  /// 移除节点
  Graph removeNode(String nodeId) {
    final newNodeIds = List<String>.from(nodeIds)..remove(nodeId);
    return copyWith(nodeIds: newNodeIds);
  }

  /// 更新时间戳
  Graph updateTimestamp() {
    return copyWith(updatedAt: DateTime.now());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Graph &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Graph(id: $id, name: $name, nodes: ${nodeIds.length})';
}
