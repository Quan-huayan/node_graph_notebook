import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';
import 'converters.dart';

part 'graph.g.dart';

/// 图视图配置
@JsonSerializable()
class GraphViewConfig {
  const GraphViewConfig({
    required this.camera,
    required this.autoLayoutEnabled,
    required this.layoutAlgorithm,
    required this.showConnectionLines,
    required this.backgroundStyle,
  });

  factory GraphViewConfig.fromJson(Map<String, dynamic> json) =>
      _$GraphViewConfigFromJson(json);

  /// 相机位置和缩放
  final Camera camera;

  /// 是否启用自动布局
  final bool autoLayoutEnabled;

  /// 布局算法
  final LayoutAlgorithm layoutAlgorithm;

  /// 是否显示连接线
  final bool showConnectionLines;

  /// 背景样式
  final BackgroundStyle backgroundStyle;

  /// 默认配置
  static const defaultConfig = GraphViewConfig(
    camera: Camera(),
    autoLayoutEnabled: false,
    layoutAlgorithm: LayoutAlgorithm.forceDirected,
    showConnectionLines: true,
    backgroundStyle: BackgroundStyle.grid,
  );

  Map<String, dynamic> toJson() => _$GraphViewConfigToJson(this)
    ..['camera'] = camera.toJson();

  GraphViewConfig copyWith({
    Camera? camera,
    bool? autoLayoutEnabled,
    LayoutAlgorithm? layoutAlgorithm,
    bool? showConnectionLines,
    BackgroundStyle? backgroundStyle,
  }) {
    return GraphViewConfig(
      camera: camera ?? this.camera,
      autoLayoutEnabled: autoLayoutEnabled ?? this.autoLayoutEnabled,
      layoutAlgorithm: layoutAlgorithm ?? this.layoutAlgorithm,
      showConnectionLines: showConnectionLines ?? this.showConnectionLines,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GraphViewConfig &&
          runtimeType == other.runtimeType &&
          camera == other.camera;

  @override
  int get hashCode => camera.hashCode;
}

/// 相机配置
@JsonSerializable()
class Camera {
  const Camera({
    this.x = 0,
    this.y = 0,
    this.zoom = 1.0,
    this.centerWidth = 4096,
    this.centerHeight = 2160,
  });

  factory Camera.fromJson(Map<String, dynamic> json) {
    // 兼容旧格式：如果缺少 centerWidth/centerHeight，使用默认值
    return Camera(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      zoom: (json['zoom'] as num?)?.toDouble() ?? 1.0,
      centerWidth: (json['centerWidth'] as num?)?.toDouble() ?? 4096,
      centerHeight: (json['centerHeight'] as num?)?.toDouble() ?? 2160,
    );
  }

  /// X 坐标
  final double x;

  /// Y 坐标
  final double y;

  /// 缩放级别
  final double zoom;

  /// 虚拟分辨率宽度（用于计算中心位置）
  final double centerWidth;

  /// 虚拟分辨率高度（用于计算中心位置）
  final double centerHeight;

  /// 获取中心位置坐标
  Offset get centerPosition => Offset(centerWidth / 2, centerHeight / 2);

  Map<String, dynamic> toJson() => _$CameraToJson(this);

  Camera copyWith({
    double? x,
    double? y,
    double? zoom,
    double? centerWidth,
    double? centerHeight,
  }) {
    return Camera(
      x: x ?? this.x,
      y: y ?? this.y,
      zoom: zoom ?? this.zoom,
      centerWidth: centerWidth ?? this.centerWidth,
      centerHeight: centerHeight ?? this.centerHeight,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Camera &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          zoom == other.zoom &&
          centerWidth == other.centerWidth &&
          centerHeight == other.centerHeight;

  @override
  int get hashCode => Object.hash(x, y, zoom, centerWidth, centerHeight);
}

/// 图结构模型
@JsonSerializable()
class Graph {
  const Graph({
    required this.id,
    required this.name,
    required this.nodeIds,
    required this.nodePositions,
    required this.viewConfig,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Graph.fromJson(Map<String, dynamic> json) => _$GraphFromJson(json);
  
  /// 创建一个空的图实例
  factory Graph.empty(String id) {
    final now = DateTime.now();
    return Graph(
      id: id,
      name: '',
      nodeIds: const [],
      nodePositions: const {},
      viewConfig: GraphViewConfig.defaultConfig,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 图ID
  final String id;

  /// 图名称
  final String name;

  /// 节点ID列表
  final List<String> nodeIds;

  /// 节点位置映射（节点ID -> 位置）
  @OffsetConverter()
  final Map<String, Offset> nodePositions;

  /// 视图配置
  final GraphViewConfig viewConfig;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$GraphToJson(this)
    ..['viewConfig'] = viewConfig.toJson();

  /// 复制并更新部分字段
  Graph copyWith({
    String? id,
    String? name,
    List<String>? nodeIds,
    Map<String, Offset>? nodePositions,
    GraphViewConfig? viewConfig,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Graph(
      id: id ?? this.id,
      name: name ?? this.name,
      nodeIds: nodeIds ?? this.nodeIds,
      nodePositions: nodePositions ?? this.nodePositions,
      viewConfig: viewConfig ?? this.viewConfig,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 添加节点
  Graph addNode(String nodeId, {Offset? position}) {
    final newNodeIds = List<String>.from(nodeIds);
    final newNodePositions = Map<String, Offset>.from(nodePositions);

    if (!newNodeIds.contains(nodeId)) {
      newNodeIds.add(nodeId);
    }

    // 如果提供了位置，设置它
    if (position != null) {
      newNodePositions[nodeId] = position;
    }

    return copyWith(
      nodeIds: newNodeIds,
      nodePositions: newNodePositions,
    );
  }

  /// 移除节点
  Graph removeNode(String nodeId) {
    final newNodeIds = List<String>.from(nodeIds)..remove(nodeId);
    final newNodePositions = Map<String, Offset>.from(nodePositions)..remove(nodeId);
    return copyWith(
      nodeIds: newNodeIds,
      nodePositions: newNodePositions,
    );
  }

  /// 更新节点位置
  Graph updateNodePosition(String nodeId, Offset position) {
    final newNodePositions = Map<String, Offset>.from(nodePositions);
    newNodePositions[nodeId] = position;
    return copyWith(nodePositions: newNodePositions);
  }

  /// 获取节点位置
  Offset? getNodePosition(String nodeId) {
    return nodePositions[nodeId];
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
          id == other.id &&
          name == other.name &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          _listEquals(nodeIds, other.nodeIds) &&
          _mapEquals(nodePositions, other.nodePositions) &&
          viewConfig == other.viewConfig;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        createdAt,
        updatedAt,
        nodeIds.length,
        nodePositions.length,
        viewConfig,
      );

  /// 辅助方法：比较两个列表是否相等
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 辅助方法：比较两个 Map 是否相等
  bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  @override
  String toString() => 'Graph(id: $id, name: $name, nodes: ${nodeIds.length})';
}
