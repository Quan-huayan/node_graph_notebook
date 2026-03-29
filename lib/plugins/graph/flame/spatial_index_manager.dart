import 'package:flame/extensions.dart';

import '../../../core/graph/spatial/quad_tree.dart';
import 'components/node_component.dart';

/// 空间索引管理器
///
/// 管理节点的空间索引，提供高效的空间查询和视锥裁剪
/// 使用QuadTree数据结构实现O(log n)的查询性能
class SpatialIndexManager {
  /// 构造函数
  SpatialIndexManager({
    this.capacity = 16,
    this.maxDepth = 8,
  });

  /// QuadTree容量
  final int capacity;

  /// 最大深度
  final int maxDepth;

  /// QuadTree实例
  QuadTree? _quadTree;

  /// 节点组件映射
  final Map<String, NodeComponent> _nodeComponents = {};

  /// 是否已初始化
  bool get isInitialized => _quadTree != null;

  /// 初始化空间索引
  ///
  /// [bounds] 世界边界
  void init(Rect bounds) {
    _quadTree = QuadTree(
      bounds: bounds,
      capacity: capacity,
      maxDepth: maxDepth,
    );
  }

  /// 添加节点到空间索引
  ///
  /// [component] 节点组件
  void addNode(NodeComponent component) {
    if (_quadTree == null) return;

    final node = component.node;
    final position = Vector2(
      node.position.dx.toDouble(),
      node.position.dy.toDouble(),
    );

    final item = QuadTreeItem(
      id: node.id,
      position: position + component.size / 2, // 使用中心点
      data: component,
    );

    _quadTree!.insert(item);
    _nodeComponents[node.id] = component;
  }

  /// 批量添加节点
  ///
  /// [components] 节点组件列表
  void addNodes(List<NodeComponent> components) {
    components.forEach(addNode);
  }

  /// 更新节点位置
  ///
  /// [nodeId] 节点ID
  /// [newPosition] 新位置
  void updateNodePosition(String nodeId, Vector2 newPosition) {
    if (_quadTree == null) return;

    final component = _nodeComponents[nodeId];
    if (component == null) return;

    final centerPosition = newPosition + component.size / 2;

    // 查找并更新旧项目
    final items = _quadTree!.query(Rect.fromCircle(
      center: Offset(newPosition.x, newPosition.y),
      radius: component.size.x,
    ));

    for (final item in items) {
      if (item.id == nodeId) {
        _quadTree!.update(item, centerPosition);
        break;
      }
    }
  }

  /// 移除节点
  ///
  /// [nodeId] 节点ID
  void removeNode(String nodeId) {
    if (_quadTree == null) return;

    final component = _nodeComponents[nodeId];
    if (component == null) return;

    final position = Vector2(
      component.node.position.dx.toDouble(),
      component.node.position.dy.toDouble(),
    );

    final centerPosition = position + component.size / 2;

    final item = QuadTreeItem(
      id: nodeId,
      position: centerPosition,
      data: component,
    );

    _quadTree!.remove(item);
    _nodeComponents.remove(nodeId);
  }

  /// 查询可见区域的节点
  ///
  /// [visibleBounds] 可见边界
  /// 返回可见区域内的节点组件列表
  List<NodeComponent> queryVisible(Rect visibleBounds) {
    if (_quadTree == null) return [];

    final items = _quadTree!.query(visibleBounds);
    return items
        .map((item) => item.data as NodeComponent)
        .whereType<NodeComponent>()
        .toList();
  }

  /// 查询附近的节点
  ///
  /// [position] 中心位置
  /// [radius] 查询半径
  /// 返回半径内的节点组件列表
  List<NodeComponent> queryNearby(Vector2 position, double radius) {
    if (_quadTree == null) return [];

    final items = _quadTree!.queryNearby(position, radius);
    return items
        .map((item) => item.data as NodeComponent)
        .whereType<NodeComponent>()
        .toList();
  }

  /// 清空所有索引
  void clear() {
    _quadTree?.clear();
    _nodeComponents.clear();
  }

  /// 重建索引
  ///
  /// 从当前节点组件重建整个空间索引
  void rebuild() {
    if (_quadTree == null) return;

    final bounds = _quadTree!.bounds;
    clear();
    init(bounds);

    _nodeComponents.values.forEach(addNode);
  }

  /// 获取统计信息
  QuadTreeStats? get stats => _quadTree?.stats;

  /// 获取所有节点组件
  List<NodeComponent> get allNodes => _nodeComponents.values.toList();

  /// 节点数量
  int get nodeCount => _nodeComponents.length;
}
