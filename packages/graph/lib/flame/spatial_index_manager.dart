import 'package:appframe/graph/quad_tree.dart';
import 'package:flame/extensions.dart';

import 'components/node_component.dart';

/// 空间索引管理器
///
/// 管理节点的空间索引，提供高效的空间查询和视锥裁剪
/// 使用QuadTree数据结构实现O(log n)的查询性能
class SpatialIndexManager {
  /// 构造函数
  SpatialIndexManager({this.capacity = 16, this.maxDepth = 8});

  /// 四叉树每个节点的容量
  final int capacity;

  /// 四叉树的最大深度
  final int maxDepth;

  QuadTree? _quadTree;
  final Map<String, NodeComponent> _nodeComponents = {};

  /// 是否已初始化
  bool get isInitialized => _quadTree != null;

  /// 初始化空间索引管理器
  ///
  /// [bounds] 空间索引的边界范围
  void init(Rect bounds) {
    _quadTree = QuadTree(
      bounds: bounds,
      capacity: capacity,
      maxDepth: maxDepth,
    );
  }

  /// 添加单个节点到空间索引
  ///
  /// [component] 要添加的节点组件
  /// [position] 节点的位置（从 UILayoutService 获取）
  void addNode(NodeComponent component, {Offset? position}) {
    if (_quadTree == null) return;

    final node = component.node;
    final nodePosition = position ?? Offset.zero;
    final pos = Vector2(
      nodePosition.dx.toDouble(),
      nodePosition.dy.toDouble(),
    );
    final center = pos + component.size / 2;

    final item = QuadTreeItem(
      id: node.id,
      position: Offset(center.x, center.y),
      data: component,
    );

    _quadTree!.insert(item);
    _nodeComponents[node.id] = component;
  }

  /// 批量添加节点到空间索引
  ///
  /// [components] 要添加的节点组件列表
  /// [positions] 节点位置映射（nodeId -> position）
  void addNodes(List<NodeComponent> components, {Map<String, Offset>? positions}) {
    for (final component in components) {
      final position = positions?[component.node.id];
      addNode(component, position: position);
    }
  }

  /// 更新节点在空间索引中的位置
  ///
  /// [nodeId] 节点ID
  /// [newPosition] 节点的新位置
  void updateNodePosition(String nodeId, Vector2 newPosition) {
    if (_quadTree == null) return;

    final component = _nodeComponents[nodeId];
    if (component == null) return;

    final centerPosition = newPosition + component.size / 2;

    final items = _quadTree!.query(Rect.fromCircle(
      center: Offset(newPosition.x, newPosition.y),
      radius: component.size.x,
    ));

    for (final item in items) {
      if (item.id == nodeId) {
        _quadTree!.update(item, Offset(centerPosition.x, centerPosition.y));
        break;
      }
    }
  }

  /// 从空间索引中移除节点
  ///
  /// [nodeId] 要移除的节点ID
  /// [position] 节点的位置（从 UILayoutService 获取）
  void removeNode(String nodeId, {Offset? position}) {
    if (_quadTree == null) return;

    final component = _nodeComponents[nodeId];
    if (component == null) return;

    final nodePosition = position ?? Offset.zero;
    final pos = Vector2(
      nodePosition.dx.toDouble(),
      nodePosition.dy.toDouble(),
    );
    final centerPosition = pos + component.size / 2;

    final item = QuadTreeItem(
      id: nodeId,
      position: Offset(centerPosition.x, centerPosition.y),
      data: component,
    );

    _quadTree!.remove(item);
    _nodeComponents.remove(nodeId);
  }

  /// 查询可见区域内的所有节点
  ///
  /// [visibleBounds] 可见区域的边界
  /// 返回可见区域内的节点组件列表
  List<NodeComponent> queryVisible(Rect visibleBounds) {
    if (_quadTree == null) return [];
    final items = _quadTree!.query(visibleBounds);
    return items
        .map((item) => item.data as NodeComponent)
        .whereType<NodeComponent>()
        .toList();
  }

  /// 查询指定位置附近的节点
  ///
  /// [position] 查询中心位置
  /// [radius] 查询半径
  /// 返回半径范围内的节点组件列表
  List<NodeComponent> queryNearby(Vector2 position, double radius) {
    if (_quadTree == null) return [];
    final items = _quadTree!.queryNearby(Offset(position.x, position.y), radius);
    return items
        .map((item) => item.data as NodeComponent)
        .whereType<NodeComponent>()
        .toList();
  }

  /// 清空空间索引
  void clear() {
    _quadTree?.clear();
    _nodeComponents.clear();
  }

  /// 重建空间索引
  void rebuild() {
    if (_quadTree == null) return;
    final bounds = _quadTree!.bounds;
    clear();
    init(bounds);
    _nodeComponents.values.forEach(addNode);
  }

  /// 获取四叉树统计信息
  QuadTreeStats? get stats => _quadTree?.stats;

  /// 获取所有节点组件
  List<NodeComponent> get allNodes => _nodeComponents.values.toList();

  /// 获取节点数量
  int get nodeCount => _nodeComponents.length;
}
