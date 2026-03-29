import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/models/models.dart';

/// 节点状态 - 整个节点管理的不可变快照
@immutable
class NodeState extends Equatable {
  /// 创建节点状态
  NodeState({
    required this.nodes,
    required this.isLoading,
    this.error,
    this.selectedNode,
    this.selectedNodeIds = const {},
  }) : nodesMap = {for (var node in nodes) node.id: node};

  factory NodeState.initial() => _initialState;

  /// 初始状态 - 缓存以提高性能
  static final _emptyMap = <String, Node>{};
  static final _initialState = NodeState(
      nodes: const [],
      isLoading: false,
      error: null,
      selectedNode: null,
      selectedNodeIds: const {},
    );

  // 核心数据
  /// 节点列表
  final List<Node> nodes;

  /// 🔥 优化：节点ID到节点的映射，提供 O(1) 查找性能
  final Map<String, Node> nodesMap;

  /// 是否正在加载
  final bool isLoading;
  /// 错误信息
  final String? error;
  /// 当前选中的节点
  final Node? selectedNode;
  /// 选中的节点ID集合
  final Set<String> selectedNodeIds;

  /// 便捷方法
  /// 是否有错误
  bool get hasError => error != null;
  /// 节点数量
  int get nodeCount => nodes.length;
  /// 是否有选中的节点
  bool get hasSelection => selectedNodeIds.isNotEmpty;
  /// 选中的节点列表
  List<Node> get selectedNodes =>
      nodes.where((n) => selectedNodeIds.contains(n.id)).toList();

  /// 🔥 优化：获取节点 - O(1) 查找性能
  Node? getNode(String id) => nodesMap[id];

  /// 复制并更新部分字段
  NodeState copyWith({
    List<Node>? nodes,
    bool? isLoading,
    String? error,
    Node? selectedNode,
    Set<String>? selectedNodeIds,
  }) => NodeState(
      nodes: nodes ?? this.nodes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedNode: selectedNode ?? this.selectedNode,
      selectedNodeIds: selectedNodeIds ?? this.selectedNodeIds,
    );

  @override
  List<Object?> get props => [
    nodes,
    nodesMap,
    isLoading,
    error,
    selectedNode,
    selectedNodeIds,
  ];
}
