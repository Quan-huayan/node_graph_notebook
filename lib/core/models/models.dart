/// 核心数据模型导出
///
/// 统一节点模型设计：所有元素（内容、关系、概念）都是 Node
library;

export 'enums.dart';
export 'node.dart';
export 'node_reference.dart';
export 'graph.dart';
export 'connection.dart';

// Re-export types from metadata_index
export '../repositories/metadata_index.dart';
