import 'dart:ui';
import 'dart:math';
import '../../utils/types.dart';
import '../../core/models/models.dart';

/// 布局服务
abstract class LayoutService {
  /// 应用布局，返回节点ID到新位置的映射
  Future<Map<String, Offset>> applyLayout({
    required List<Node> nodes,
    required LayoutAlgorithm algorithm,
    LayoutOptions? options,
  });

  /// 力导向布局
  Future<void> forceDirectedLayout({
    required List<Node> nodes,
    ForceDirectedOptions? options,
  });

  /// 层级布局
  Future<void> hierarchicalLayout({
    required List<Node> nodes,
    HierarchicalOptions? options,
  });

  /// 环形布局
  Future<void> circularLayout({
    required List<Node> nodes,
    CircularOptions? options,
  });

  /// 概念地图布局
  Future<void> conceptMapLayout({
    required List<Node> nodes,
    ConceptMapOptions? options,
  });
}

/// 布局选项
class LayoutOptions {
  const LayoutOptions({
    this.nodeSpacing = 100.0,
    this.levelSpacing = 150.0,
    this.alignToGrid = false,
  });

  final double nodeSpacing;
  final double levelSpacing;
  final bool alignToGrid;
}

/// 力导向布局选项
class ForceDirectedOptions extends LayoutOptions {
  const ForceDirectedOptions({
    super.nodeSpacing = 100.0,
    super.levelSpacing = 150.0,
    super.alignToGrid = false,
    this.repulsion = 1000.0,
    this.attraction = 0.1,
    this.iterations = 100,
    this.damping = 0.9,
  });

  final double repulsion;
  final double attraction;
  final int iterations;
  final double damping;
}

/// 层级布局选项
class HierarchicalOptions extends LayoutOptions {
  const HierarchicalOptions({
    super.nodeSpacing = 100.0,
    super.levelSpacing = 150.0,
    super.alignToGrid = false,
    this.nodeWidth = 300.0,
    this.nodeHeight = 200.0,
  });

  final double nodeWidth;
  final double nodeHeight;
}

/// 环形布局选项
class CircularOptions extends LayoutOptions {
  const CircularOptions({
    super.nodeSpacing = 100.0,
    super.levelSpacing = 150.0,
    super.alignToGrid = false,
    this.radius = 300.0,
  });

  final double radius;
}

/// 概念地图布局选项
class ConceptMapOptions extends LayoutOptions {
  const ConceptMapOptions({
    super.nodeSpacing = 100.0,
    super.levelSpacing = 150.0,
    super.alignToGrid = false,
    this.groupConcepts = true,
    this.emphasizeConnections = true,
  });

  final bool groupConcepts;
  final bool emphasizeConnections;
}

/// 布局服务实现
class LayoutServiceImpl implements LayoutService {
  final Map<String, Offset> _lastLayoutPositions = {};

  /// 获取最后一次布局的位置
  Map<String, Offset> get lastLayoutPositions => Map.unmodifiable(_lastLayoutPositions);

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
      case LayoutAlgorithm.conceptMap:
        await conceptMapLayout(
          nodes: nodes,
          options: options is ConceptMapOptions ? options : null,
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

    // 计算力导向布局
    for (int i = 0; i < opts.iterations; i++) {
      final velocities = <String, Vector2>{};

      for (final node in nodes) {
        final pos = positions[node.id]!;
        var force = Vector2.zero;

        // 计算排斥力（所有节点之间）
        for (final other in nodes) {
          if (node.id == other.id) continue;

          final otherPos = positions[other.id]!;
          final diff = pos - otherPos;
          final distance = diff.length;

          if (distance > 0) {
            final repulsion = diff.normalized() * (opts.repulsion / (distance * distance));
            force += repulsion;
          }
        }

        // 计算吸引力（连接的节点之间）
        for (final entry in node.references.entries) {
          final otherId = entry.key;
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
        positions[node.id] = positions[node.id]! + velocity * opts.damping;

        // 边界约束
        positions[node.id] = Vector2(
          positions[node.id]!.x.clamp(50.0, 1200.0),
          positions[node.id]!.y.clamp(50.0, 800.0),
        );
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
    final referencedIds = nodes
        .expand((n) => n.references.keys)
        .toSet();
    final rootNodes = nodes.where((n) => !referencedIds.contains(n.id)).toList();

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
      maxWidths[level] = nodesInLevel.length * (opts.nodeWidth + opts.nodeSpacing);
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
    final center = const Vector2(640.0, 400.0); // 画布中心
    final positions = <String, Vector2>{};

    for (int i = 0; i < nodes.length; i++) {
      final angle = (2 * pi * i) / nodes.length;
      final x = center.x + opts.radius * cos(angle);
      final y = center.y + opts.radius * sin(angle);
      positions[nodes[i].id] = Vector2(x, y);
    }

    _updateNodePositions(nodes, positions);
  }

  @override
  Future<void> conceptMapLayout({
    required List<Node> nodes,
    ConceptMapOptions? options,
  }) async {
    if (nodes.isEmpty) return;

    final positions = <String, Vector2>{};

    // 首先布局所有概念节点（有引用的节点）
    final conceptNodes = nodes.where((n) => n.references.isNotEmpty).toList();

    // 使用力导向布局先布局概念节点
    if (conceptNodes.isNotEmpty) {
      final radius = 300.0;
      final center = const Vector2(640.0, 400.0);

      for (int i = 0; i < conceptNodes.length; i++) {
        final angle = (2 * pi * i) / conceptNodes.length;
        final x = center.x + radius * cos(angle);
        final y = center.y + radius * sin(angle);
        positions[conceptNodes[i].id] = Vector2(x, y);
      }
    }

    // 布局内容节点（围绕其所属的概念节点）
    for (final contentNode in nodes) {
      // 跳过已布局的概念节点
      if (positions.containsKey(contentNode.id)) continue;

      // 找到包含此内容节点的概念节点
      final parentConcepts = conceptNodes.where((concept) {
        return concept.references.containsKey(contentNode.id) &&
            concept.references[contentNode.id]!.type == ReferenceType.contains;
      }).toList();

      if (parentConcepts.isNotEmpty) {
        // 使用第一个包含它的概念节点作为中心
        final parentPos = positions[parentConcepts.first.id]!;
        final angle = Random().nextDouble() * 2 * pi;
        final distance = 100.0 + Random().nextDouble() * 50;

        positions[contentNode.id] = Vector2(
          parentPos.x + distance * cos(angle),
          parentPos.y + distance * sin(angle),
        );
      } else {
        // 未被包含的内容节点，随机布局
        positions[contentNode.id] = Vector2(
          Random().nextDouble() * 800 + 200,
          Random().nextDouble() * 600 + 100,
        );
      }
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
