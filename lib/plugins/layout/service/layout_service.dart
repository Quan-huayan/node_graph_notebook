import 'dart:math';
import 'dart:ui';

import '../../../../core/models/models.dart';
import '../../../../utils/types.dart';

/// 布局服务
abstract class LayoutService {
  /// 应用布局，返回节点ID到新位置的映射
  /// 
  /// [nodes] - 要布局的节点列表
  /// [algorithm] - 布局算法
  /// [options] - 布局选项
  Future<Map<String, Offset>> applyLayout({
    required List<Node> nodes,
    required LayoutAlgorithm algorithm,
    LayoutOptions? options,
  });

  /// 力导向布局
  /// 
  /// [nodes] - 要布局的节点列表
  /// [options] - 力导向布局选项
  Future<void> forceDirectedLayout({
    required List<Node> nodes,
    ForceDirectedOptions? options,
  });

  /// 层级布局
  /// 
  /// [nodes] - 要布局的节点列表
  /// [options] - 层级布局选项
  Future<void> hierarchicalLayout({
    required List<Node> nodes,
    HierarchicalOptions? options,
  });

  /// 环形布局
  /// 
  /// [nodes] - 要布局的节点列表
  /// [options] - 环形布局选项
  Future<void> circularLayout({
    required List<Node> nodes,
    CircularOptions? options,
  });
}

/// 布局选项
class LayoutOptions {
  /// 创建布局选项
  /// 
  /// [nodeSpacing] - 节点间距
  /// [levelSpacing] - 层级间距
  /// [alignToGrid] - 是否对齐到网格
  const LayoutOptions({
    this.nodeSpacing = 100.0,
    this.levelSpacing = 150.0,
    this.alignToGrid = false,
  });

  /// 节点间距
  final double nodeSpacing;
  
  /// 层级间距
  final double levelSpacing;
  
  /// 是否对齐到网格
  final bool alignToGrid;
}

/// 力导向布局选项
class ForceDirectedOptions extends LayoutOptions {
  /// 创建力导向布局选项
  /// 
  /// [nodeSpacing] - 节点间距
  /// [levelSpacing] - 层级间距
  /// [alignToGrid] - 是否对齐到网格
  /// [repulsion] - 排斥力强度
  /// [attraction] - 吸引力强度
  /// [iterations] - 迭代次数
  /// [damping] - 阻尼系数
  const ForceDirectedOptions({
    super.nodeSpacing = 100.0,
    super.levelSpacing = 150.0,
    super.alignToGrid = false,
    this.repulsion = 1000.0,
    this.attraction = 0.1,
    this.iterations = 100,
    this.damping = 0.9,
  });

  /// 排斥力强度
  final double repulsion;
  
  /// 吸引力强度
  final double attraction;
  
  /// 迭代次数
  final int iterations;
  
  /// 阻尼系数
  final double damping;
}

/// 层级布局选项
class HierarchicalOptions extends LayoutOptions {
  /// 创建层级布局选项
  /// 
  /// [nodeSpacing] - 节点间距
  /// [levelSpacing] - 层级间距
  /// [alignToGrid] - 是否对齐到网格
  /// [nodeWidth] - 节点宽度
  /// [nodeHeight] - 节点高度
  const HierarchicalOptions({
    super.nodeSpacing = 100.0,
    super.levelSpacing = 150.0,
    super.alignToGrid = false,
    this.nodeWidth = 300.0,
    this.nodeHeight = 200.0,
  });

  /// 节点宽度
  final double nodeWidth;
  
  /// 节点高度
  final double nodeHeight;
}

/// 环形布局选项
class CircularOptions extends LayoutOptions {
  /// 创建环形布局选项
  /// 
  /// [nodeSpacing] - 节点间距
  /// [levelSpacing] - 层级间距
  /// [alignToGrid] - 是否对齐到网格
  /// [radius] - 环形半径
  const CircularOptions({
    super.nodeSpacing = 100.0,
    super.levelSpacing = 150.0,
    super.alignToGrid = false,
    this.radius = 300.0,
  });

  /// 环形半径
  final double radius;
}

/// 布局服务实现
class LayoutServiceImpl implements LayoutService {
  final Map<String, Offset> _lastLayoutPositions = {};

  /// 获取最后一次布局的位置
  Map<String, Offset> get lastLayoutPositions =>
      Map.unmodifiable(_lastLayoutPositions);

  @override
  Future<Map<String, Offset>> applyLayout({
    required List<Node> nodes,
    required LayoutAlgorithm algorithm,
    LayoutOptions? options,
  }) async {
    _lastLayoutPositions.clear();

    switch (algorithm) {
      case LayoutAlgorithm.forceDirected:
        await forceDirectedLayout(
          nodes: nodes,
          options: options is ForceDirectedOptions ? options : null,
        );
        break;
      case LayoutAlgorithm.hierarchical:
        await hierarchicalLayout(
          nodes: nodes,
          options: options is HierarchicalOptions ? options : null,
        );
        break;
      case LayoutAlgorithm.circular:
        await circularLayout(
          nodes: nodes,
          options: options is CircularOptions ? options : null,
        );
        break;
      case LayoutAlgorithm.free:
        // 自由布局，不做处理
        break;
    }

    return Map.unmodifiable(_lastLayoutPositions);
  }

  @override
  Future<void> forceDirectedLayout({
    required List<Node> nodes,
    ForceDirectedOptions? options,
  }) async {
    if (nodes.isEmpty) return;

    final opts = options ?? const ForceDirectedOptions();

    // 🔥 优化：早期终止，小数据集使用更少迭代
    final adjustedIterations = nodes.length < 20
        ? opts.iterations ~/ 2
        : opts.iterations;

    // 初始化位置（如果没有位置）
    final positions = <String, Vector2>{};
    for (final node in nodes) {
      if (node.position == Offset.zero) {
        positions[node.id] = Vector2(
          Random().nextDouble() * 800,
          Random().nextDouble() * 600,
        );
      } else {
        positions[node.id] = Vector2(
          node.position.dx.toDouble(),
          node.position.dy.toDouble(),
        );
      }
    }

    // 🔥 优化：提前构建连接关系图，避免重复查找
    final connections = <String, List<String>>{};
    for (final node in nodes) {
      connections[node.id] = node.references.keys.toList();
    }

    // 🔥 优化：early stopping 变量
    var maxMovement = 0.0;
    const earlyStoppingThreshold = 0.1;

    // 计算力导向布局
    for (var i = 0; i < adjustedIterations; i++) {
      final velocities = <String, Vector2>{};
      maxMovement = 0.0;

      // 🔥 优化：批量计算排斥力（使用距离阈值优化）
      for (final node in nodes) {
        final pos = positions[node.id]!;
        var force = Vector2.zero;

        // 🔥 优化：只计算距离较近的节点之间的排斥力
        // 对于距离很远的节点，排斥力可以忽略不计
        for (final other in nodes) {
          if (node.id == other.id) continue;

          final otherPos = positions[other.id]!;
          final diff = pos - otherPos;
          final distance = diff.length;

          // 🔥 优化：忽略距离超过阈值的节点，减少计算
          if (distance > 500) continue;

          if (distance > 0) {
            final repulsion =
                diff.normalized() * (opts.repulsion / (distance * distance));
            force += repulsion;
          }
        }

        // 计算吸引力（连接的节点之间）
        final connectedIds = connections[node.id] ?? [];
        for (final otherId in connectedIds) {
          final otherPos = positions[otherId];
          if (otherPos == null) continue;

          final diff = otherPos - pos;
          final distance = diff.length;

          if (distance > 0) {
            final attraction = diff.normalized() * (distance * opts.attraction);
            force += attraction;
          }
        }

        velocities[node.id] = force;
      }

      // 应用速度和阻尼
      for (final node in nodes) {
        final velocity = velocities[node.id]!;
        final oldPos = positions[node.id]!;
        final newPos = oldPos + velocity * opts.damping;

        // 计算移动距离用于early stopping
        final movement = (newPos - oldPos).length;
        if (movement > maxMovement) {
          maxMovement = movement;
        }

        // 边界约束
        positions[node.id] = Vector2(
          newPos.x.clamp(50.0, 1200.0),
          newPos.y.clamp(50.0, 800.0),
        );
      }

      // 🔥 优化：early stopping，当节点移动很小时提前终止
      if (maxMovement < earlyStoppingThreshold && i > 10) {
        break;
      }
    }

    // 更新节点位置
    _updateNodePositions(nodes, positions);
  }

  @override
  Future<void> hierarchicalLayout({
    required List<Node> nodes,
    HierarchicalOptions? options,
  }) async {
    if (nodes.isEmpty) return;

    final opts = options ?? const HierarchicalOptions();

    // 构建层级结构
    final levels = <int, List<Node>>{};
    final nodeLevel = <String, int>{};

    // 根节点（没有被引用的节点）
    final referencedIds = nodes.expand((n) => n.references.keys).toSet();
    final rootNodes = nodes
        .where((n) => !referencedIds.contains(n.id))
        .toList();

    // BFS 计算层级
    final queue = <(Node, int)>[];
    for (final root in rootNodes) {
      queue.add((root, 0));
      nodeLevel[root.id] = 0;
    }

    while (queue.isNotEmpty) {
      final (node, level) = queue.removeAt(0);
      levels.putIfAbsent(level, () => []).add(node);

      // 添加被引用的节点
      for (final refId in node.references.keys) {
        if (!nodeLevel.containsKey(refId)) {
          // 先检查节点是否存在
          final refNode = nodes.where((n) => n.id == refId).firstOrNull;
          if (refNode != null) {
            nodeLevel[refId] = level + 1;
            queue.add((refNode, level + 1));
          }
        }
      }
    }

    // 未访问的节点
    for (final node in nodes) {
      if (!nodeLevel.containsKey(node.id)) {
        nodeLevel[node.id] = 0;
        levels.putIfAbsent(0, () => []).add(node);
      }
    }

    // 计算位置
    final positions = <String, Vector2>{};
    final maxWidths = <int, double>{};

    // 计算每层的最大宽度
    for (final entry in levels.entries) {
      final level = entry.key;
      final nodesInLevel = entry.value;
      maxWidths[level] =
          nodesInLevel.length * (opts.nodeWidth + opts.nodeSpacing);
    }

    // 布局每层
    for (final entry in levels.entries) {
      final level = entry.key;
      final nodesInLevel = entry.value;
      final y = level.toDouble() * (opts.nodeHeight + opts.levelSpacing) + 50;

      var x = 50.0;
      for (final node in nodesInLevel) {
        positions[node.id] = Vector2(x, y);
        x += opts.nodeWidth + opts.nodeSpacing;
      }
    }

    _updateNodePositions(nodes, positions);
  }

  @override
  Future<void> circularLayout({
    required List<Node> nodes,
    CircularOptions? options,
  }) async {
    if (nodes.isEmpty) return;

    final opts = options ?? const CircularOptions();
    const center = Vector2(640, 400); // 画布中心
    final positions = <String, Vector2>{};

    for (var i = 0; i < nodes.length; i++) {
      final angle = (2 * pi * i) / nodes.length;
      final x = center.x + opts.radius * cos(angle);
      final y = center.y + opts.radius * sin(angle);
      positions[nodes[i].id] = Vector2(x, y);
    }

    _updateNodePositions(nodes, positions);
  }

  void _updateNodePositions(List<Node> nodes, Map<String, Vector2> positions) {
    for (final node in nodes) {
      final pos = positions[node.id];
      if (pos != null) {
        final newOffset = Offset(pos.x, pos.y);
        _lastLayoutPositions[node.id] = newOffset;
      }
    }
  }
}
