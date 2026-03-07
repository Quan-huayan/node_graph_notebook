import 'dart:ui';
import 'package:node_graph_notebook/core/models/models.dart';

/// 测试辅助工具
///
/// 此文件仅用于测试，提供简化的模型构造方法。
/// **警告：不得在生产代码中使用此文件！**

/// Node 测试辅助扩展
///
/// 提供简化的 Node 构造方法，用于快速创建测试数据。
/// 使用合理的默认值，减少测试代码的重复。
extension NodeTestHelpers on Node {
  /// 创建一个测试用的 Node 实例
  ///
  /// 提供了常用的默认值，只覆盖必要的参数。
  /// 所有可选参数都有合理的默认值，适合大多数测试场景。
  static Node test({
    required String id,
    required String title,
    String? content,
    Map<String, NodeReference> references = const {},
    Offset position = const Offset(100, 100),
    Size size = const Size(200, 250),
    NodeViewMode viewMode = NodeViewMode.titleWithPreview,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic> metadata = const {},
  }) {
    final now = DateTime.now();
    return Node(
      id: id,
      title: title,
      content: content,
      references: references,
      position: position,
      size: size,
      viewMode: viewMode,
      color: color,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      metadata: metadata,
    );
  }

  /// 创建一个最小化的测试 Node（仅含必需字段）
  ///
  /// 适用于不需要自定义任何参数的快速测试场景。
  ///
  /// 示例：
  /// ```dart
  /// final node = Node.testMinimal('node-1');
  /// ```
  static Node testMinimal(
    String id, [
    String title = 'Test Node',
  ]) {
    final now = DateTime.now();
    return Node(
      id: id,
      title: title,
      references: const {},
      position: const Offset(100, 100),
      size: const Size(200, 250),
      viewMode: NodeViewMode.titleWithPreview,
      createdAt: now,
      updatedAt: now,
      metadata: const {},
    );
  }

  /// 创建一个文件夹类型的测试 Node
  ///
  /// 预设了元数据 `isFolder: true`，适用于测试文件夹节点。
  ///
  /// 示例：
  /// ```dart
  /// final folder = Node.testFolder('folder-1', 'My Folder');
  /// ```
  static Node testFolder(
    String id,
    String title, {
    Map<String, NodeReference> references = const {},
    Offset position = const Offset(100, 100),
  }) {
    final now = DateTime.now();
    return Node(
      id: id,
      title: title,
      references: references,
      position: position,
      size: const Size(200, 250),
      viewMode: NodeViewMode.titleOnly,
      createdAt: now,
      updatedAt: now,
      metadata: const {'isFolder': true},
    );
  }
}
