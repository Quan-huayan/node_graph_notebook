import 'dart:ui';

import '../../models/enums.dart';
import '../../models/node.dart';

/// Node 轻量级读模型
///
/// 设计说明：
/// NodeReadModel 是一个读优化的轻量级节点表示，用于：
/// 1. 减少内存占用 - 不包含完整的 content 和 metadata
/// 2. 提高查询速度 - 减少数据传输和序列化开销
/// 3. 优化缓存效率 - 更小的对象可以缓存更多条目
///
/// 与完整 Node 的区别：
/// - content: 完整Node有，NodeReadModel没有（最重的字段）
/// - references: 完整Node是Map，NodeReadModel简化为List&lt;String&gt;（只存ID）
/// - metadata: 完整Node有，NodeReadModel没有（减少复杂度）
///
/// 内存占用对比：
/// - 完整 Node: ~2-5KB（取决于content长度）
/// - NodeReadModel: ~200-400字节
/// - 节省: 80-95% 内存
///
/// 使用场景：
/// - 列表展示（节点列表、搜索结果）
/// - 图可视化（只需要位置和标题）
/// - 邻居查询（只需要节点ID和位置）
/// - 缓存层（QueryCache）
class NodeReadModel {
  /// 构造函数
  const NodeReadModel({
    required this.id,
    required this.title,
    required this.referencedNodeIds,
    required this.position,
    required this.size,
    required this.viewMode,
    this.color,
    required this.createdAt,
    required this.updatedAt,
    this.isFolder = false,
  });

  /// 从完整 Node 创建轻量级读模型
  factory NodeReadModel.fromNode(Node node) => NodeReadModel(
      id: node.id,
      title: node.title,
      referencedNodeIds: node.referencedNodeIds,
      position: node.position,
      size: node.size,
      viewMode: node.viewMode,
      color: node.color,
      createdAt: node.createdAt,
      updatedAt: node.updatedAt,
      isFolder: node.isFolder,
    );

  /// 从 JSON 创建
  factory NodeReadModel.fromJson(Map<String, dynamic> json) => NodeReadModel(
      id: json['id'] as String,
      title: json['title'] as String,
      referencedNodeIds: (json['referencedNodeIds'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      position: Offset(
        (json['position'] as Map<String, dynamic>)['dx'] as double,
        (json['position'] as Map<String, dynamic>)['dy'] as double,
      ),
      size: Size(
        (json['size'] as Map<String, dynamic>)['width'] as double,
        (json['size'] as Map<String, dynamic>)['height'] as double,
      ),
      viewMode: NodeViewMode.values.firstWhere(
        (e) => e.name == json['viewMode'],
        orElse: () => NodeViewMode.titleOnly,
      ),
      color: json['color'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isFolder: json['isFolder'] as bool? ?? false,
    );

  /// 唯一标识符
  final String id;

  /// 节点标题
  final String title;

  /// 引用的节点ID列表（简化版）
  final List<String> referencedNodeIds;

  /// 位置坐标
  final Offset position;

  /// 节点尺寸
  final Size size;

  /// 显示模式
  final NodeViewMode viewMode;

  /// 颜色
  final String? color;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 是否是文件夹
  final bool isFolder;

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
      'id': id,
      'title': title,
      'referencedNodeIds': referencedNodeIds,
      'position': {'dx': position.dx, 'dy': position.dy},
      'size': {'width': size.width, 'height': size.height},
      'viewMode': viewMode.name,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isFolder': isFolder,
    };

  /// 获取内容预览（标题的前50个字符）
  String get preview => title.length > 50 ? '${title.substring(0, 50)}...' : title;

  /// 计算内存占用（估算值，字节）
  int get estimatedMemoryBytes {
    var bytes = 0;
    bytes += id.length * 2; // String (UTF-16)
    bytes += title.length * 2;
    bytes += referencedNodeIds.length * (8 + 2); // 假设平均ID长度8
    bytes += 16; // Offset
    bytes += 16; // Size
    bytes += 4; // viewMode enum
    bytes += (color?.length ?? 0) * 2;
    bytes += 16; // createdAt
    bytes += 16; // updatedAt
    bytes += 1; // isFolder
    return bytes;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NodeReadModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'NodeReadModel(id: $id, title: $title, '
        'refs: ${referencedNodeIds.length}, '
        'position: $position, '
        'viewMode: $viewMode)';
}

/// NodeReadModel 列表扩展
///
/// 提供批量操作和转换方法
extension NodeReadModelListExtension on List<NodeReadModel> {
  /// 转换为 Node ID 集合
  Set<String> toIdSet() => map((m) => m.id).toSet();

  /// 按 ID 查找模型
  NodeReadModel? findById(String id) {
    for (final model in this) {
      if (model.id == id) return model;
    }
    return null;
  }

  /// 按标题过滤
  List<NodeReadModel> filterByTitle(String keyword) {
    final lowerKeyword = keyword.toLowerCase();
    return where((m) => m.title.toLowerCase().contains(lowerKeyword)).toList();
  }

  /// 按更新时间排序（最新的在前）
  List<NodeReadModel> sortByUpdatedAt() {
    final list = [...this];
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// 按创建时间排序（最新的在前）
  List<NodeReadModel> sortByCreatedAt() {
    final list = [...this];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// 计算总内存占用（估算值）
  int get totalMemoryBytes {
    var total = 0;
    for (final model in this) {
      total += model.estimatedMemoryBytes;
    }
    return total;
  }
}
