import 'package:json_annotation/json_annotation.dart';
part 'metadata_index.g.dart';

/// 位置信息（可序列化）
///
/// 用于存储节点的位置坐标
@JsonSerializable()
class PositionInfo {
  /// 创建位置信息
  ///
  /// [dx]: X坐标
  /// [dy]: Y坐标
  const PositionInfo({required this.dx, required this.dy});

  /// 从JSON创建位置信息
  factory PositionInfo.fromJson(Map<String, dynamic> json) =>
      _$PositionInfoFromJson(json);

  /// X坐标
  final double dx;
  
  /// Y坐标
  final double dy;

  /// 转换为JSON
  Map<String, dynamic> toJson() => _$PositionInfoToJson(this);
}

/// 尺寸信息（可序列化）
///
/// 用于存储节点的尺寸信息
@JsonSerializable()
class SizeInfo {
  /// 创建尺寸信息
  ///
  /// [width]: 宽度
  /// [height]: 高度
  const SizeInfo({required this.width, required this.height});

  /// 从JSON创建尺寸信息
  factory SizeInfo.fromJson(Map<String, dynamic> json) =>
      _$SizeInfoFromJson(json);

  /// 宽度
  final double width;
  
  /// 高度
  final double height;

  /// 转换为JSON
  Map<String, dynamic> toJson() => _$SizeInfoToJson(this);
}

/// 节点元数据
///
/// 存储节点的元数据信息，用于索引和快速查询
@JsonSerializable()
class NodeMetadata {
  /// 创建节点元数据
  ///
  /// [id]: 节点ID
  /// [title]: 节点标题
  /// [position]: 节点位置
  /// [size]: 节点尺寸
  /// [filePath]: 节点文件路径
  /// [referencedNodeIds]: 引用的节点ID列表
  /// [createdAt]: 创建时间
  /// [updatedAt]: 更新时间
  const NodeMetadata({
    required this.id,
    required this.title,
    required this.position,
    required this.size,
    required this.filePath,
    required this.referencedNodeIds,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从JSON创建节点元数据
  factory NodeMetadata.fromJson(Map<String, dynamic> json) =>
      _$NodeMetadataFromJson(json);

  /// 节点ID
  final String id;
  
  /// 节点标题
  final String title;
  
  /// 节点位置
  final PositionInfo position;
  
  /// 节点尺寸
  final SizeInfo size;
  
  /// 节点文件路径
  final String filePath;
  
  /// 引用的节点ID列表
  final List<String> referencedNodeIds;
  
  /// 创建时间
  final DateTime createdAt;
  
  /// 更新时间
  final DateTime updatedAt;

  /// 转换为JSON
  Map<String, dynamic> toJson() => _$NodeMetadataToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeMetadata &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 元数据索引
///
/// 存储所有节点的元数据，用于快速查询和索引
@JsonSerializable()
class MetadataIndex {
  /// 创建元数据索引
  ///
  /// [nodes]: 节点元数据列表
  /// [lastUpdated]: 最后更新时间
  const MetadataIndex({required this.nodes, required this.lastUpdated});

  /// 从JSON创建元数据索引
  factory MetadataIndex.fromJson(Map<String, dynamic> json) =>
      _$MetadataIndexFromJson(json);

  /// 节点元数据列表
  final List<NodeMetadata> nodes;
  
  /// 最后更新时间
  final DateTime lastUpdated;

  /// 转换为JSON
  Map<String, dynamic> toJson() => _$MetadataIndexToJson(this);
}
