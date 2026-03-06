import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../core/models/models.dart';

/// 节点状态 - 整个节点管理的不可变快照
@immutable
class NodeState extends Equatable {
  const NodeState({
    required this.nodes,
    required this.isLoading,
    this.error,
    this.selectedNode,
    this.selectedNodeIds = const {},
  });

  /// 初始状态
  factory NodeState.initial() {
    return const NodeState(
      nodes: [],
      isLoading: false,
      error: null,
      selectedNode: null,
      selectedNodeIds: {},
    );
  }

  // 核心数据
  final List<Node> nodes;
  final bool isLoading;
  final String? error;
  final Node? selectedNode;
  final Set<String> selectedNodeIds;

  /// 便捷方法
  bool get hasError => error != null;
  int get nodeCount => nodes.length;
  bool get hasSelection => selectedNodeIds.isNotEmpty;
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
  }) {
    return NodeState(
      nodes: nodes ?? this.nodes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedNode: selectedNode ?? this.selectedNode,
      selectedNodeIds: selectedNodeIds ?? this.selectedNodeIds,
    );
  }

  @override
  List<Object?> get props => [
        nodes,
        isLoading,
        error,
        selectedNode,
        selectedNodeIds,
      ];
}
