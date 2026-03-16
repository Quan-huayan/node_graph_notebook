import 'dart:ui';

import '../../../../core/models/models.dart';
import '../../../../core/repositories/repositories.dart';
import '../../layout/service/layout_service.dart';
import 'node_service.dart';

/// 图服务接口
abstract class GraphService {
  /// 创建图
  Future<Graph> createGraph({required String name, List<String>? nodeIds});

  /// 获取图
  Future<Graph?> getGraph(String graphId);

  /// 获取当前图
  Future<Graph?> getCurrentGraph();

  /// 更新图
  Future<Graph> updateGraph(
    String graphId, {
    String? name,
    List<String>? nodeIds,
    GraphViewConfig? viewConfig,
    Map<String, Offset>? nodePositions,
  });

  /// 删除图
  Future<void> deleteGraph(String graphId);

  /// 添加节点到图
  Future<void> addNodeToGraph(String graphId, String nodeId);

  /// 从图移除节点
  Future<void> removeNodeFromGraph(String graphId, String nodeId);

  /// 获取图的所有节点
  Future<List<Node>> getGraphNodes(String graphId);

  /// 获取图的连接
  Future<List<Connection>> getGraphConnections(String graphId);

  /// 应用布局算法
  Future<void> applyLayout(String graphId, LayoutAlgorithm algorithm);

  /// 导出图
  Future<String> exportGraph(String graphId);
}

/// 图服务实现
class GraphServiceImpl implements GraphService {
  /// 构造函数
  ///
  /// [_repository] - 图形仓库
  /// [_nodeRepository] - 节点仓库
  /// [layoutService] - 布局服务，可选
  GraphServiceImpl(
    this._repository,
    this._nodeRepository, [
    LayoutService? layoutService,
  ]) : _layoutService = layoutService ?? LayoutServiceImpl();

  final GraphRepository _repository;
  final NodeRepository _nodeRepository;
  final LayoutService _layoutService;

  @override
  Future<Graph> createGraph({
    required String name,
    List<String>? nodeIds,
  }) async {
    final graphNodes = nodeIds != null
        ? await _nodeRepository.loadAll(nodeIds)
        : [];

    final graph = Graph(
      id: __generateId(),
      name: name,
      nodeIds: nodeIds ?? [],
      viewConfig: GraphViewConfig.defaultConfig,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      nodePositions: {for (Node node in graphNodes) node.id: node.position},
    );

    await _repository.save(graph);
    return graph;
  }

  @override
  Future<Graph?> getGraph(String graphId) async => _repository.load(graphId);

  @override
  Future<Graph?> getCurrentGraph() async => _repository.getCurrent();

  @override
  Future<Graph> updateGraph(
    String graphId, {
    String? name,
    List<String>? nodeIds,
    GraphViewConfig? viewConfig,
    Map<String, Offset>? nodePositions,
  }) async {
    final graph = await _repository.load(graphId);
    if (graph == null) {
      throw GraphNotFoundException(graphId);
    }

    // 合并位置信息
    final mergedPositions = Map<String, Offset>.from(graph.nodePositions);
    if (nodePositions != null) {
      mergedPositions.addAll(nodePositions);
    }

    final updatedGraph = graph.copyWith(
      name: name ?? graph.name,
      nodeIds: nodeIds ?? graph.nodeIds,
      viewConfig: viewConfig ?? graph.viewConfig,
      nodePositions: mergedPositions,
      updatedAt: DateTime.now(),
    );

    await _repository.save(updatedGraph);
    return updatedGraph;
  }

  @override
  Future<void> deleteGraph(String graphId) async {
    final graph = await _repository.load(graphId);
    if (graph == null) {
      throw GraphNotFoundException(graphId);
    }

    await _repository.delete(graphId);
  }

  @override
  Future<void> addNodeToGraph(String graphId, String nodeId) async {
    final graph = await _repository.load(graphId);
    if (graph == null) {
      throw GraphNotFoundException(graphId);
    }

    // 验证节点存在
    final node = await _nodeRepository.load(nodeId);
    if (node == null) {
      throw NodeNotFoundException(nodeId);
    }

    final updatedGraph = graph.addNode(nodeId);
    await _repository.save(updatedGraph);
  }

  @override
  Future<void> removeNodeFromGraph(String graphId, String nodeId) async {
    final graph = await _repository.load(graphId);
    if (graph == null) {
      throw GraphNotFoundException(graphId);
    }

    final updatedGraph = graph.removeNode(nodeId);
    await _repository.save(updatedGraph);
  }

  @override
  Future<List<Node>> getGraphNodes(String graphId) async {
    final graph = await _repository.load(graphId);
    if (graph == null) {
      throw GraphNotFoundException(graphId);
    }

    if (graph.nodeIds.isEmpty) {
      return [];
    }

    return _nodeRepository.loadAll(graph.nodeIds);
  }

  @override
  Future<List<Connection>> getGraphConnections(String graphId) async {
    final nodes = await getGraphNodes(graphId);
    return Connection.calculateConnections(nodes);
  }

  @override
  Future<void> applyLayout(String graphId, LayoutAlgorithm algorithm) async {
    final graph = await _repository.load(graphId);
    if (graph == null) {
      throw GraphNotFoundException(graphId);
    }

    final nodes = await getGraphNodes(graphId);

    // 应用布局算法
    final newPositions = await _layoutService.applyLayout(
      nodes: nodes,
      algorithm: algorithm,
    );

    // 同时更新节点文件和图的位置映射
    final updatedNodePositions = Map<String, Offset>.from(graph.nodePositions);

    // 更新节点位置
    for (final node in nodes) {
      final newPos = newPositions[node.id];
      if (newPos != null) {
        // 更新节点文件
        final updatedNode = node.copyWith(position: newPos);
        await _nodeRepository.save(updatedNode);

        // 更新图的位置映射
        updatedNodePositions[node.id] = newPos;
      }
    }

    // 更新图的布局算法配置和位置映射
    final updatedConfig = graph.viewConfig.copyWith(layoutAlgorithm: algorithm);
    final updatedGraph = graph.copyWith(
      viewConfig: updatedConfig,
      nodePositions: updatedNodePositions,
    );
    await _repository.save(updatedGraph);
  }

  @override
  Future<String> exportGraph(String graphId) async {
    final graph = await _repository.load(graphId);
    if (graph == null) {
      throw GraphNotFoundException(graphId);
    }

    // 导出到临时文件
    final exportPath = 'data/exports/$graphId.json';
    await _repository.export(graphId, exportPath);

    return exportPath;
  }

  String __generateId() {
    // TODO: 应该使用 uuid 包
    return 'graph_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// 图未找到异常
class GraphNotFoundException implements Exception {
  /// 构造函数
  ///
  /// [graphId] - 未找到的图的 ID
  const GraphNotFoundException(this.graphId);

  /// 未找到的图的 ID
  final String graphId;

  @override
  String toString() => 'Graph not found: $graphId';
}
