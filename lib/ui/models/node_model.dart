import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';

/// 节点状态管理
class NodeModel extends ChangeNotifier {
  NodeModel(this._service);

  final NodeService _service;

  List<Node> _nodes = [];
  bool _isLoading = false;
  String? _error;
  Node? _selectedNode;
  final Set<String> _selectedNodes = {};

  List<Node> get nodes => _nodes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  Node? get selectedNode => _selectedNode;
  Set<String> get selectedNodeIds => Set.unmodifiable(_selectedNodes);
  List<Node> get selectedNodes =>
      _nodes.where((n) => _selectedNodes.contains(n.id)).toList();

  int get nodeCount => _nodes.length;

  bool get hasSelection => _selectedNodes.isNotEmpty;

  /// 加载所有节点
  Future<void> loadNodes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _nodes = await _service.getAllNodes();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 创建节点
  Future<Node> createNode({
    required String title,
    String? content,
  }) async {
    try {
      final node = await _service.createNode(
        title: title,
        content: content,
      );

      _nodes.add(node);
      notifyListeners();

      return node;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 创建内容节点
  Future<Node> createContentNode({
    required String title,
    required String content,
  }) async {
    return createNode(
      title: title,
      content: content,
    );
  }

  /// 更新节点
  Future<void> updateNode(String nodeId, {
    String? title,
    String? content,
    Offset? position,
    NodeViewMode? viewMode,
  }) async {
    try {
      final updatedNode = await _service.updateNode(
        nodeId,
        title: title,
        content: content,
        position: position,
        viewMode: viewMode,
      );

      final index = _nodes.indexWhere((n) => n.id == nodeId);
      if (index != -1) {
        _nodes[index] = updatedNode;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 直接替换节点对象
  Future<void> replaceNode(Node newNode) async {
    try {
      // 使用服务层更新，传递所有必要的参数
      await _service.updateNode(
        newNode.id,
        title: newNode.title,
        content: newNode.content,
        position: newNode.position,
        size: newNode.size,
        viewMode: newNode.viewMode,
        references: newNode.references,
        metadata: newNode.metadata,
      );

      final index = _nodes.indexWhere((n) => n.id == newNode.id);
      if (index != -1) {
        _nodes[index] = newNode;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 删除节点
  Future<void> deleteNode(String nodeId) async {
    try {
      await _service.deleteNode(nodeId);
      _nodes.removeWhere((n) => n.id == nodeId);
      _selectedNodes.remove(nodeId);
      if (_selectedNode?.id == nodeId) {
        _selectedNode = null;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 搜索节点
  Future<void> searchNodes(String query) async {
    if (query.trim().isEmpty) {
      await loadNodes();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _nodes = await _service.searchNodes(query);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 连接节点
  Future<void> connectNodes({
    required String fromNodeId,
    required String toNodeId,
    required ReferenceType type,
    String? role,
  }) async {
    try {
      await _service.connectNodes(
        fromNodeId: fromNodeId,
        toNodeId: toNodeId,
        type: type,
        role: role,
      );

      // 重新加载节点以获取更新
      final fromNode = await _service.getNode(fromNodeId);
      if (fromNode != null) {
        final index = _nodes.indexWhere((n) => n.id == fromNodeId);
        if (index != -1) {
          _nodes[index] = fromNode;
          notifyListeners();
        }
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 断开节点连接
  Future<void> disconnectNodes({
    required String fromNodeId,
    required String toNodeId,
  }) async {
    try {
      await _service.disconnectNodes(
        fromNodeId: fromNodeId,
        toNodeId: toNodeId,
      );

      // 重新加载节点以获取更新
      final fromNode = await _service.getNode(fromNodeId);
      if (fromNode != null) {
        final index = _nodes.indexWhere((n) => n.id == fromNodeId);
        if (index != -1) {
          _nodes[index] = fromNode;
          notifyListeners();
        }
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 选择节点
  void selectNode(String nodeId) {
    _selectedNode = _nodes.firstWhere((n) => n.id == nodeId);
    notifyListeners();
  }

  /// 切换节点选择状态
  void toggleNodeSelection(String nodeId) {
    if (_selectedNodes.contains(nodeId)) {
      _selectedNodes.remove(nodeId);
    } else {
      _selectedNodes.add(nodeId);
    }
    notifyListeners();
  }

  /// 选择多个节点
  void selectNodes(Set<String> nodeIds) {
    _selectedNodes.clear();
    _selectedNodes.addAll(nodeIds);
    notifyListeners();
  }

  /// 清空选择
  void clearSelection() {
    _selectedNodes.clear();
    _selectedNode = null;
    notifyListeners();
  }

  /// 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
