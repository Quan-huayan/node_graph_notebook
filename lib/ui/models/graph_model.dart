import 'dart:io';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';

/// 图状态管理
class GraphModel extends ChangeNotifier {
  GraphModel(this._service);

  final GraphService _service;

  Graph? _currentGraph;
  List<Node> _graphNodes = [];
  List<Connection> _connections = [];
  bool _isLoading = false;
  String? _error;

  Graph? get currentGraph => _currentGraph;
  List<Node> get graphNodes => _graphNodes;
  List<Connection> get connections => _connections;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasGraph => _currentGraph != null;
  bool get hasError => _error != null;

  /// 初始化 - 加载当前图
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentGraph = await _service.getCurrentGraph();
      if (_currentGraph != null) {
        await _loadGraphData(_currentGraph!);
      }
      _error = null;
    } on FileSystemException catch (e) {
      _error = 'Data folder not found or inaccessible. Please restart the application to recover.';
    } catch (e) {
      _error = 'Failed to load graph: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 创建图
  Future<Graph> createGraph(String name) async {
    try {
      final graph = await _service.createGraph(name: name);
      _currentGraph = graph;
      await _loadGraphData(graph);
      notifyListeners();
      return graph;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 切换图
  Future<void> switchGraph(String graphId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final graph = await _service.getGraph(graphId);
      if (graph == null) {
        throw GraphNotFoundException(graphId);
      }

      _currentGraph = graph;
      await _loadGraphData(graph);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新图配置
  Future<void> updateViewConfig(GraphViewConfig config) async {
    if (_currentGraph == null) return;

    try {
      _currentGraph = await _service.updateGraph(
        _currentGraph!.id,
        viewConfig: config,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 添加节点到图
  Future<void> addNode(String nodeId, {Offset? position}) async {
    if (_currentGraph == null) return;

    try {
      // 先更新图中的节点位置（如果提供了位置）
      if (position != null) {
        _currentGraph = await _service.updateGraph(
          _currentGraph!.id,
          nodePositions: {..._currentGraph!.nodePositions, nodeId: position},
        );
      }

      // 然后添加节点到图
      await _service.addNodeToGraph(_currentGraph!.id, nodeId);
      _currentGraph = await _service.getGraph(_currentGraph!.id);

      final node = await _service.getGraphNodes(_currentGraph!.id);
      _graphNodes = node;
      _connections = Connection.calculateConnections(_graphNodes);
      _error = null;
      notifyListeners();
    } on FileSystemException catch (e) {
      _error = 'Cannot save changes: Data folder is missing or inaccessible.';
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Failed to add node: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// 从图移除节点
  Future<void> removeNode(String nodeId) async {
    if (_currentGraph == null) return;

    try {
      await _service.removeNodeFromGraph(_currentGraph!.id, nodeId);
      _graphNodes.removeWhere((n) => n.id == nodeId);
      _connections = Connection.calculateConnections(_graphNodes);
      _error = null;
      notifyListeners();
    } on FileSystemException catch (e) {
      _error = 'Cannot save changes: Data folder is missing or inaccessible.';
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Failed to remove node: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// 更新节点位置（不重新加载所有数据）
  Future<void> updateNodePositions(Map<String, Offset> positions) async {
    if (_currentGraph == null) return;

    try {
      final updatedPositions = Map<String, Offset>.from(_currentGraph!.nodePositions);
      updatedPositions.addAll(positions);

      _currentGraph = await _service.updateGraph(
        _currentGraph!.id,
        nodePositions: updatedPositions,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 应用布局
  Future<void> applyLayout(LayoutAlgorithm algorithm) async {
    if (_currentGraph == null) return;

    try {
      await _service.applyLayout(_currentGraph!.id, algorithm);
      final graph = await _service.getGraph(_currentGraph!.id);
      if (graph != null) {
        _currentGraph = graph;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 刷新图数据
  Future<void> refresh() async {
    if (_currentGraph == null) return;
    await _loadGraphData(_currentGraph!);
  }

  Future<void> _loadGraphData(Graph graph) async {
    try {
      _graphNodes = await _service.getGraphNodes(graph.id);
      _connections = Connection.calculateConnections(_graphNodes);
      _error = null;
    } on FileSystemException catch (e) {
      _error = 'Data files not found. Some nodes may be missing.';
      _graphNodes = [];
      _connections = [];
    } catch (e) {
      _error = 'Failed to load graph data: ${e.toString()}';
      _graphNodes = [];
      _connections = [];
    }
    notifyListeners();
  }

  /// 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
