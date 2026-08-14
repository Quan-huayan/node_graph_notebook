// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'graph.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GraphViewConfig _$GraphViewConfigFromJson(Map<String, dynamic> json) =>
    GraphViewConfig(
      camera: Camera.fromJson(json['camera'] as Map<String, dynamic>),
      autoLayoutEnabled: json['autoLayoutEnabled'] as bool,
      layoutAlgorithm: $enumDecode(
        _$LayoutAlgorithmEnumMap,
        json['layoutAlgorithm'],
      ),
      showConnectionLines: json['showConnectionLines'] as bool,
      backgroundStyle: $enumDecode(
        _$BackgroundStyleEnumMap,
        json['backgroundStyle'],
      ),
    );

Map<String, dynamic> _$GraphViewConfigToJson(GraphViewConfig instance) =>
    <String, dynamic>{
      'camera': instance.camera,
      'autoLayoutEnabled': instance.autoLayoutEnabled,
      'layoutAlgorithm': _$LayoutAlgorithmEnumMap[instance.layoutAlgorithm]!,
      'showConnectionLines': instance.showConnectionLines,
      'backgroundStyle': _$BackgroundStyleEnumMap[instance.backgroundStyle]!,
    };

const _$LayoutAlgorithmEnumMap = {
  LayoutAlgorithm.forceDirected: 'forceDirected',
  LayoutAlgorithm.hierarchical: 'hierarchical',
  LayoutAlgorithm.circular: 'circular',
  LayoutAlgorithm.free: 'free',
};

const _$BackgroundStyleEnumMap = {
  BackgroundStyle.grid: 'grid',
  BackgroundStyle.dots: 'dots',
  BackgroundStyle.none: 'none',
};

Camera _$CameraFromJson(Map<String, dynamic> json) => Camera(
  x: (json['x'] as num?)?.toDouble() ?? 0,
  y: (json['y'] as num?)?.toDouble() ?? 0,
  zoom: (json['zoom'] as num?)?.toDouble() ?? 1.0,
  centerWidth: (json['centerWidth'] as num?)?.toDouble() ?? 4096,
  centerHeight: (json['centerHeight'] as num?)?.toDouble() ?? 2160,
);

Map<String, dynamic> _$CameraToJson(Camera instance) => <String, dynamic>{
  'x': instance.x,
  'y': instance.y,
  'zoom': instance.zoom,
  'centerWidth': instance.centerWidth,
  'centerHeight': instance.centerHeight,
};

Graph _$GraphFromJson(Map<String, dynamic> json) => Graph(
  id: json['id'] as String,
  name: json['name'] as String,
  nodeIds: (json['nodeIds'] as List<dynamic>).map((e) => e as String).toList(),
  viewConfig: GraphViewConfig.fromJson(
    json['viewConfig'] as Map<String, dynamic>,
  ),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$GraphToJson(Graph instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'nodeIds': instance.nodeIds,
  'viewConfig': instance.viewConfig,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
