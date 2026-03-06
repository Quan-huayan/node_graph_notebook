import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import '../../core/services/services.dart';
import 'node_event.dart';
import 'node_state.dart';

/// 节点 BLoC - 节点状态管理核心
class NodeBloc extends Bloc<NodeEvent, NodeState> {
  NodeBloc({
    required NodeService nodeService,
  })  : _nodeService = nodeService,
        super(NodeState.initial()) {
    // 注册事件处理器
    on<NodeLoadEvent>(_onLoadNodes);
    on<NodeSearchEvent>(_onSearchNodes);
    on<NodeCreateEvent>(_onCreateNode);
    on<NodeCreateContentEvent>(_onCreateContentNode);
    on<NodeUpdateEvent>(_onUpdateNode);
    on<NodeReplaceEvent>(_onReplaceNode);
    on<NodeDeleteEvent>(_onDeleteNode);
    on<NodeConnectEvent>(_onConnectNodes);
    on<NodeDisconnectEvent>(_onDisconnectNodes);
    on<NodeSelectEvent>(_onSelectNode);
    on<NodeToggleSelectionEvent>(_onToggleSelection);
    on<NodeMultiSelectEvent>(_onMultiSelect);
    on<NodeClearSelectionEvent>(_onClearSelection);
    on<SelectionClearEvent>(_onSelectionClear);
    on<NodeAddEvent>(_onNodeAdd);
    on<NodeMoveEvent>(_onNodeMove);
    on<NodeMultiMoveEvent>(_onNodeMultiMove);
    on<NodeClearErrorEvent>(_onClearError);
  }

  final NodeService _nodeService;

  /// 加载节点列表
  Future<void> _onLoadNodes(
    NodeLoadEvent event,
    Emitter<NodeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final nodes = await _nodeService.getAllNodes();
      emit(state.copyWith(
        nodes: nodes,
        isLoading: false,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  /// 搜索节点
  Future<void> _onSearchNodes(
    NodeSearchEvent event,
    Emitter<NodeState> emit,
  ) async {
    if (event.query.trim().isEmpty) {
      add(const NodeLoadEvent());
      return;
    }

    emit(state.copyWith(isLoading: true, error: null));

    try {
      final nodes = await _nodeService.searchNodes(event.query);
      emit(state.copyWith(
        nodes: nodes,
        isLoading: false,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  /// 创建节点
  Future<void> _onCreateNode(
    NodeCreateEvent event,
    Emitter<NodeState> emit,
  ) async {
    try {
      final node = await _nodeService.createNode(
        title: event.title,
        content: event.content,
        metadata: event.metadata,
      );

      final updatedNodes = [...state.nodes, node];
      emit(state.copyWith(
        nodes: updatedNodes,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      rethrow;
    }
  }

  /// 创建内容节点
  Future<void> _onCreateContentNode(
    NodeCreateContentEvent event,
    Emitter<NodeState> emit,
  ) async {
    try {
      final node = await _nodeService.createNode(
        title: event.title,
        content: event.content,
        metadata: event.metadata,
      );

      final updatedNodes = [...state.nodes, node];
      emit(state.copyWith(
        nodes: updatedNodes,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      rethrow;
    }
  }

  /// 更新节点
  Future<void> _onUpdateNode(
    NodeUpdateEvent event,
    Emitter<NodeState> emit,
  ) async {
    try {
      final updatedNode = await _nodeService.updateNode(
        event.nodeId,
        title: event.title,
        content: event.content,
        position: event.position,
        viewMode: event.viewMode,
      );

      final updatedNodes = state.nodes.map((n) {
        return n.id == event.nodeId ? updatedNode : n;
      }).toList();

      emit(state.copyWith(
        nodes: updatedNodes,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      rethrow;
    }
  }

  /// 替换节点
  Future<void> _onReplaceNode(
    NodeReplaceEvent event,
    Emitter<NodeState> emit,
  ) async {
    try {
      // 使用服务层更新，传递所有必要的参数
      final updatedNode = await _nodeService.updateNode(
        event.node.id,
        title: event.node.title,
        content: event.node.content,
        position: event.node.position,
        size: event.node.size,
        viewMode: event.node.viewMode,
        references: event.node.references,
        metadata: event.node.metadata,
      );

      final updatedNodes = state.nodes.map((n) {
        return n.id == event.node.id ? updatedNode : n;
      }).toList();

      emit(state.copyWith(
        nodes: updatedNodes,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      rethrow;
    }
  }

  /// 删除节点
  Future<void> _onDeleteNode(
    NodeDeleteEvent event,
    Emitter<NodeState> emit,
  ) async {
    try {
      await _nodeService.deleteNode(event.nodeId);

      final updatedNodes = state.nodes.where((n) => n.id != event.nodeId).toList();
      final updatedSelectedIds = state.selectedNodeIds.where((id) => id != event.nodeId).toSet();
      final updatedSelectedNode = state.selectedNode?.id == event.nodeId ? null : state.selectedNode;

      emit(state.copyWith(
        nodes: updatedNodes,
        selectedNodeIds: updatedSelectedIds,
        selectedNode: updatedSelectedNode,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      rethrow;
    }
  }

  /// 连接节点
  Future<void> _onConnectNodes(
    NodeConnectEvent event,
    Emitter<NodeState> emit,
  ) async {
    try {
      await _nodeService.connectNodes(
        fromNodeId: event.fromNodeId,
        toNodeId: event.toNodeId,
        type: event.type,
        role: event.role,
      );

      // 重新加载节点以获取更新
      final fromNode = await _nodeService.getNode(event.fromNodeId);
      if (fromNode != null) {
        final updatedNodes = state.nodes.map((n) {
          return n.id == event.fromNodeId ? fromNode : n;
        }).toList();

        emit(state.copyWith(
          nodes: updatedNodes,
          error: null,
        ));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      rethrow;
    }
  }

  /// 断开节点连接
  Future<void> _onDisconnectNodes(
    NodeDisconnectEvent event,
    Emitter<NodeState> emit,
  ) async {
    try {
      await _nodeService.disconnectNodes(
        fromNodeId: event.fromNodeId,
        toNodeId: event.toNodeId,
      );

      // 重新加载节点以获取更新
      final fromNode = await _nodeService.getNode(event.fromNodeId);
      if (fromNode != null) {
        final updatedNodes = state.nodes.map((n) {
          return n.id == event.fromNodeId ? fromNode : n;
        }).toList();

        emit(state.copyWith(
          nodes: updatedNodes,
          error: null,
        ));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      rethrow;
    }
  }

  /// 选择节点
  void _onSelectNode(
    NodeSelectEvent event,
    Emitter<NodeState> emit,
  ) {
    final selectedNode = state.getNode(event.nodeId);
    emit(state.copyWith(
      selectedNode: selectedNode,
    ));
  }

  /// 切换节点选择状态
  void _onToggleSelection(
    NodeToggleSelectionEvent event,
    Emitter<NodeState> emit,
  ) {
    final updatedSelectedIds = Set<String>.from(state.selectedNodeIds);
    if (updatedSelectedIds.contains(event.nodeId)) {
      updatedSelectedIds.remove(event.nodeId);
    } else {
      updatedSelectedIds.add(event.nodeId);
    }

    emit(state.copyWith(
      selectedNodeIds: updatedSelectedIds,
    ));
  }

  /// 选择多个节点
  void _onMultiSelect(
    NodeMultiSelectEvent event,
    Emitter<NodeState> emit,
  ) {
    emit(state.copyWith(
      selectedNodeIds: event.nodeIds,
    ));
  }

  /// 清空选择
  void _onClearSelection(
    NodeClearSelectionEvent event,
    Emitter<NodeState> emit,
  ) {
    emit(state.copyWith(
      selectedNodeIds: {},
      selectedNode: null,
    ));
  }

  /// 清除错误
  void _onClearError(
    NodeClearErrorEvent event,
    Emitter<NodeState> emit,
  ) {
    emit(state.copyWith(error: null));
  }

  /// 清除选择（用于GraphBloc）
  void _onSelectionClear(
    SelectionClearEvent event,
    Emitter<NodeState> emit,
  ) {
    emit(state.copyWith(
      selectedNodeIds: {},
      selectedNode: null,
    ));
  }

  /// 添加节点
  Future<void> _onNodeAdd(
    NodeAddEvent event,
    Emitter<NodeState> emit,
  ) async {
    // 节点添加逻辑已在GraphBloc中处理
    // 这里可以添加额外的节点状态更新逻辑
  }

  /// 移动节点（单个）
  Future<void> _onNodeMove(
    NodeMoveEvent event,
    Emitter<NodeState> emit,
  ) async {
    try {
      // 更新节点位置
      final updatedNode = await _nodeService.updateNode(
        event.nodeId,
        position: event.newPosition,
      );

      // 更新节点列表中的位置
      final updatedNodes = state.nodes.map((n) {
        if (n.id == event.nodeId) {
          return updatedNode;
        }
        return n;
      }).toList();

      emit(state.copyWith(
        nodes: updatedNodes,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// 移动节点（批量）
  Future<void> _onNodeMultiMove(
    NodeMultiMoveEvent event,
    Emitter<NodeState> emit,
  ) async {
    try {
      // 批量更新节点位置
      final updatedNodesList = <Node>[];
      for (final entry in event.movements.entries) {
        final updatedNode = await _nodeService.updateNode(
          entry.key,
          position: entry.value,
        );
        updatedNodesList.add(updatedNode);
      }

      // 更新节点列表中的位置
      final updatedNodes = state.nodes.map((n) {
        final updatedNode = updatedNodesList.firstWhere(
          (u) => u.id == n.id,
          orElse: () => n,
        );
        return updatedNode;
      }).toList();

      emit(state.copyWith(
        nodes: updatedNodes,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
