import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/models/models.dart';

/// 节点状态 - 整个节点管理的不可变快照
@immutable
class NodeState extends Equatable {
  /// 创建节点状态
  const NodeState({
    required this.nodes,
    required this.isLoading,
    this.error,
    this.selectedNode,
    this.selectedNodeIds = const {},
  });

  /// 初始状态
  factory NodeState.initial() => const NodeState(
      nodes: [],
      isLoading: false,
      error: null,
      selectedNode: null,
      selectedNodeIds: {},
    );

  // 核心数据
  /// 节点列表
  final List<Node> nodes;
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

  /// 获取节点
  Node? getNode(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

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
    isLoading,
    error,
    selectedNode,
    selectedNodeIds,
  ];
}
