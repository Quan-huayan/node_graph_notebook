import 'package:json_annotation/json_annotation.dart';
import '../models/enums.dart';

part 'metadata_index.g.dart';

/// 位置信息（可序列化）
@JsonSerializable()
class PositionInfo {
  const PositionInfo({required this.dx, required this.dy});

  factory PositionInfo.fromJson(Map<String, dynamic> json) =>
      _$PositionInfoFromJson(json);

  final double dx;
  final double dy;

  Map<String, dynamic> toJson() => _$PositionInfoToJson(this);
}

/// 尺寸信息（可序列化）
@JsonSerializable()
class SizeInfo {
  const SizeInfo({required this.width, required this.height});

  factory SizeInfo.fromJson(Map<String, dynamic> json) =>
      _$SizeInfoFromJson(json);

  final double width;
  final double height;

  Map<String, dynamic> toJson() => _$SizeInfoToJson(this);
}

/// 节点元数据
@JsonSerializable()
class NodeMetadata {
  const NodeMetadata({
    required this.id,
    required this.type,
    required this.title,
    required this.position,
    required this.size,
    required this.filePath,
    required this.referencedNodeIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NodeMetadata.fromJson(Map<String, dynamic> json) =>
      _$NodeMetadataFromJson(json);

  final String id;
  final NodeType type;
  final String title;
  final PositionInfo position;
  final SizeInfo size;
  final String filePath;
  final List<String> referencedNodeIds;
  final DateTime createdAt;
  final DateTime updatedAt;

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
@JsonSerializable()
class MetadataIndex {
  const MetadataIndex({
    required this.nodes,
    required this.lastUpdated,
  });

  factory MetadataIndex.fromJson(Map<String, dynamic> json) =>
      _$MetadataIndexFromJson(json);

  final List<NodeMetadata> nodes;
  final DateTime lastUpdated;

  Map<String, dynamic> toJson() => _$MetadataIndexToJson(this);
}
