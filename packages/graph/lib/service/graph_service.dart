import 'package:core/models/models.dart';
import 'package:core/plugin/hook/coordinate_system.dart';
import 'package:core/plugin/hook/ui_layout_service.dart';
import 'package:core/repositories/repositories.dart';
import 'package:flutter/material.dart';
import 'package:node_layout/layout.dart';

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
  /// [_repository] - 图仓库
  /// [_nodeRepository] - 节点仓库
  /// [_layoutService] - 布局算法服务
  /// [_uiLayoutService] - UI 布局服务，管理节点位置
  GraphServiceImpl(
    this._repository,
    this._nodeRepository, [
    this._layoutService,
    this._uiLayoutService,
  ]);

  final GraphRepository _repository;
  final NodeRepository _nodeRepository;
  final LayoutService? _layoutService;
  final UILayoutService? _uiLayoutService;

  @override
  Future<Graph> createGraph({
    required String name,
    List<String>? nodeIds,
  }) async {
    final graph = Graph(
      id: __generateId(),
      name: name,
      nodeIds: nodeIds ?? [],
      viewConfig: GraphViewConfig.defaultConfig,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
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
  }) async {
    final graph = await _repository.load(graphId);
    if (graph == null) {
      throw GraphNotFoundException(graphId);
    }

    final updatedGraph = graph.copyWith(
      name: name ?? graph.name,
      nodeIds: nodeIds ?? graph.nodeIds,
      viewConfig: viewConfig ?? graph.viewConfig,
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
    if (_layoutService == null || _uiLayoutService == null) {
      throw StateError('LayoutService and UILayoutService are required for layout operations');
    }

    final graph = await _repository.load(graphId);
    if (graph == null) {
      throw GraphNotFoundException(graphId);
    }

    final nodes = await getGraphNodes(graphId);

    final currentPositions = <String, Offset>{};
    for (final node in nodes) {
      final attachment = _uiLayoutService.getNodeAttachment(node.id);
      if (attachment != null) {
        currentPositions[node.id] = Offset(
          attachment.localPosition.x,
          attachment.localPosition.y,
        );
      }
    }

    final newPositions = await _layoutService.applyLayout(
      nodes: nodes,
      currentPositions: currentPositions,
      algorithm: algorithm,
    );

    for (final entry in newPositions.entries) {
      await _uiLayoutService.updateNodePosition(
        nodeId: entry.key,
        newPosition: LocalPosition.absolute(entry.value.dx, entry.value.dy),
      );
    }

    // 更新图的布局算法配置
    final updatedConfig = graph.viewConfig.copyWith(layoutAlgorithm: algorithm);
    final updatedGraph = graph.copyWith(
      viewConfig: updatedConfig,
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

  String __generateId() => 'graph_${DateTime.now().millisecondsSinceEpoch}';
}

/// 图未找到异常
class GraphNotFoundException implements Exception {
  /// 构造函数
  ///
  /// [graphId] - 未找到的图的ID
  const GraphNotFoundException(this.graphId);

  /// 未找到的图的ID
  final String graphId;

  @override
  String toString() => '未找到图: $graphId';
}
