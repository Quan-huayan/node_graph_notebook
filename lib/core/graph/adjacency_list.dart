import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../models/node.dart';

/// 邻接表 - 图的邻接表表示
///
/// 维护节点之间的引用关系，提供O(1)复杂度的邻居查询
/// 相比遍历所有节点（O(n)），邻接表大幅提升图查询性能
///
/// 性能特性：
/// - 查询邻居: O(1)
/// - 添加关系: O(1)
/// - 删除关系: O(1)
/// - 内存开销: O(E) 其中E是边的数量
///
/// 使用场景：
/// - 快速获取节点的邻居
/// - 计算节点的度数（入度/出度）
/// - 图遍历和路径查找
/// - 图分析和统计
class AdjacencyList {
  /// 构造函数
  AdjacencyList({
    this.storageDir = 'data/graph',
  }) {
    _outgoingEdges = {};
    _incomingEdges = {};
  }

  /// 存储目录
  final String storageDir;

  /// 出边表：nodeId -> Set&lt;referencedNodeId&gt;
  ///
  /// 使用 late 而非 late final，因为加载失败时需要重新初始化
  late Map<String, Set<String>> _outgoingEdges;

  /// 入边表：nodeId -> Set&lt;referencingNodeId&gt;
  ///
  /// 使用 late 而非 late final，因为加载失败时需要重新初始化
  late Map<String, Set<String>> _incomingEdges;

  /// 文件路径
  String get _filePath => path.join(storageDir, 'adjacency_list.json');

  /// 是否已加载
  bool _isLoaded = false;

  /// 是否已加载
  bool get isLoaded => _isLoaded;

  /// 初始化并加载邻接表
  ///
  /// 从文件加载邻接表数据，如果文件不存在则创建空表
  Future<void> init() async {
    if (_isLoaded) return;

    final file = File(_filePath);
    if (file.existsSync()) {
      try {
        final json = await file.readAsString();
        final data = jsonDecode(json) as Map<String, dynamic>;

        _outgoingEdges = _parseEdgeMap(data['outgoing'] as Map<String, dynamic>?);
        _incomingEdges = _parseEdgeMap(data['incoming'] as Map<String, dynamic>?);
      } catch (error) {
        // 加载失败，创建空表
        _outgoingEdges = {};
        _incomingEdges = {};
      }
    }

    _isLoaded = true;
  }

  /// 从节点列表构建邻接表
  ///
  /// [nodes] 节点列表
  void buildFromNodes(List<Node> nodes) {
    clear();

    for (final node in nodes) {
      for (final referencedId in node.references.keys) {
        addEdge(node.id, referencedId);
      }
    }

    _isLoaded = true;
  }

  /// 添加一条边
  ///
  /// [fromId] 源节点ID
  /// [toId] 目标节点ID
  void addEdge(String fromId, String toId) {
    // 添加出边
    _outgoingEdges.putIfAbsent(fromId, () => <String>{});
    _outgoingEdges[fromId]!.add(toId);

    // 添加入边
    _incomingEdges.putIfAbsent(toId, () => <String>{});
    _incomingEdges[toId]!.add(fromId);
  }

  /// 删除一条边
  ///
  /// [fromId] 源节点ID
  /// [toId] 目标节点ID
  void removeEdge(String fromId, String toId) {
    _outgoingEdges[fromId]?.remove(toId);
    _incomingEdges[toId]?.remove(fromId);
  }

  /// 移除节点的所有边
  ///
  /// [nodeId] 节点ID
  void removeNode(String nodeId) {
    // 删除所有出边
    _outgoingEdges.remove(nodeId);

    // 删除所有入边
    _incomingEdges.remove(nodeId);

    // 从其他节点的出边中移除此节点
    for (final edges in _outgoingEdges.values) {
      edges.remove(nodeId);
    }

    // 从其他节点的入边中移除此节点
    for (final edges in _incomingEdges.values) {
      edges.remove(nodeId);
    }
  }

  /// 获取节点的出边邻居
  ///
  /// [nodeId] 节点ID
  /// 返回该节点引用的所有节点ID集合
  Set<String> getOutgoingNeighbors(String nodeId) => Set<String>.from(_outgoingEdges[nodeId] ?? const {});

  /// 获取节点的入边邻居
  ///
  /// [nodeId] 节点ID
  /// 返回所有引用该节点的节点ID集合
  Set<String> getIncomingNeighbors(String nodeId) => Set<String>.from(_incomingEdges[nodeId] ?? const {});

  /// 获取节点的所有邻居
  ///
  /// [nodeId] 节点ID
  /// 返回该节点的所有邻居（出边+入边）ID集合
  Set<String> getAllNeighbors(String nodeId) {
    final neighbors = <String>{};
    neighbors.addAll(_outgoingEdges[nodeId] ?? const {});
    neighbors.addAll(_incomingEdges[nodeId] ?? const {});
    return neighbors;
  }

  /// 获取节点的出度
  ///
  /// [nodeId] 节点ID
  /// 返回该节点的出度（引用了多少其他节点）
  int getOutDegree(String nodeId) => _outgoingEdges[nodeId]?.length ?? 0;

  /// 获取节点的入度
  ///
  /// [nodeId] 节点ID
  /// 返回该节点的入度（有多少节点引用了它）
  int getInDegree(String nodeId) => _incomingEdges[nodeId]?.length ?? 0;

  /// 检查是否存在边
  ///
  /// [fromId] 源节点ID
  /// [toId] 目标节点ID
  /// 返回是否存在从fromId到toId的边
  bool hasEdge(String fromId, String toId) => _outgoingEdges[fromId]?.contains(toId) ?? false;

  /// 获取所有边
  ///
  /// 返回所有边的列表，每条边表示为[fromId, toId]
  List<List<String>> getAllEdges() {
    final edges = <List<String>>[];
    for (final fromId in _outgoingEdges.keys) {
      for (final toId in _outgoingEdges[fromId]!) {
        edges.add([fromId, toId]);
      }
    }
    return edges;
  }

  /// 获取边总数
  int get edgeCount {
    var count = 0;
    for (final edges in _outgoingEdges.values) {
      count += edges.length;
    }
    return count;
  }

  /// 获取节点总数
  int get nodeCount {
    final nodes = <String>{};
    nodes.addAll(_outgoingEdges.keys);
    nodes.addAll(_incomingEdges.keys);
    return nodes.length;
  }

  /// 清空邻接表
  void clear() {
    _outgoingEdges.clear();
    _incomingEdges.clear();
  }

  /// 保存到文件
  ///
  /// 将邻接表持久化到磁盘
  Future<void> save() async {
    final dir = Directory(storageDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final data = {
      'outgoing': _serializeEdgeMap(_outgoingEdges),
      'incoming': _serializeEdgeMap(_incomingEdges),
    };

    final file = File(_filePath);
    await file.writeAsString(jsonEncode(data));
  }

  /// 解析边映射
  Map<String, Set<String>> _parseEdgeMap(Map<String, dynamic>? data) {
    if (data == null) return {};

    final result = <String, Set<String>>{};
    for (final entry in data.entries) {
      final neighbors = (entry.value as List)
          .map((e) => e.toString())
          .toSet();
      result[entry.key] = neighbors;
    }
    return result;
  }

  /// 序列化边映射
  Map<String, List<String>> _serializeEdgeMap(Map<String, Set<String>> edgeMap) {
    final result = <String, List<String>>{};
    for (final entry in edgeMap.entries) {
      result[entry.key] = entry.value.toList();
    }
    return result;
  }

  /// 获取统计信息
  AdjacencyListStats get stats {
    var totalOutDegree = 0;
    var maxOutDegree = 0;

    for (final edges in _outgoingEdges.values) {
      totalOutDegree += edges.length;
      if (edges.length > maxOutDegree) {
        maxOutDegree = edges.length;
      }
    }

    final avgOutDegree = nodeCount > 0 ? totalOutDegree / nodeCount : 0.0;

    return AdjacencyListStats(
      nodeCount: nodeCount,
      edgeCount: edgeCount,
      avgOutDegree: avgOutDegree,
      maxOutDegree: maxOutDegree,
    );
  }

  @override
  String toString() => 'AdjacencyList(nodes: $nodeCount, edges: $edgeCount)';
}

/// 邻接表统计信息
class AdjacencyListStats {
  /// 构造函数
  const AdjacencyListStats({
    required this.nodeCount,
    required this.edgeCount,
    required this.avgOutDegree,
    required this.maxOutDegree,
  });

  /// 节点总数
  final int nodeCount;

  /// 边总数
  final int edgeCount;

  /// 平均出度
  final double avgOutDegree;

  /// 最大出度
  final int maxOutDegree;

  @override
  String toString() => 'AdjacencyListStats('
        'nodes: $nodeCount, '
        'edges: $edgeCount, '
        'avgOutDegree: ${avgOutDegree.toStringAsFixed(2)}, '
        'maxOutDegree: $maxOutDegree)';
}
