import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/services.dart';
import '../../core/events/app_events.dart';
import 'node_event.dart';
import 'node_state.dart';

/// 节点 BLoC - 节点数据管理核心
///
/// 职责：
/// - 节点数据的 CRUD 操作（创建、读取、更新、删除）
/// - 节点连接管理
/// - 节点搜索和加载
/// - 发布数据变化事件到事件总线
///
/// 不再负责：
/// - 节点选择状态（由 GraphBloc 管理）
/// - 节点在视图中的位置（由 GraphBloc 管理）
class NodeBloc extends Bloc<NodeEvent, NodeState> {
  NodeBloc({
    required NodeService nodeService,
    required AppEventBus eventBus,
  })  : _nodeService = nodeService,
        _eventBus = eventBus,
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
    on<NodeClearErrorEvent>(_onClearError);
  }

  final NodeService _nodeService;
  final AppEventBus _eventBus;

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
        position: event.position,
        color: event.color,
        metadata: event.metadata,
      );

      final updatedNodes = [...state.nodes, node];
      emit(state.copyWith(
        nodes: updatedNodes,
        error: null,
      ));

      // 发布节点创建事件到总线
      _eventBus.publish(NodeDataChangedEvent(
        changedNodes: [node],
        action: DataChangeAction.create,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      // Do not rethrow - the error is already handled by emitting an error state
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

      // 发布节点创建事件到总线
      _eventBus.publish(NodeDataChangedEvent(
        changedNodes: [node],
        action: DataChangeAction.create,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      // Do not rethrow - the error is already handled by emitting an error state
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
        color: event.color,
        metadata: event.metadata,
      );

      final updatedNodes = state.nodes.map((n) {
        return n.id == event.nodeId ? updatedNode : n;
      }).toList();

      emit(state.copyWith(
        nodes: updatedNodes,
        error: null,
      ));

      // 发布节点更新事件到总线
      _eventBus.publish(NodeDataChangedEvent(
        changedNodes: [updatedNode],
        action: DataChangeAction.update,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      // Do not rethrow - the error is already handled by emitting an error state
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

      // 发布节点更新事件到总线
      _eventBus.publish(NodeDataChangedEvent(
        changedNodes: [updatedNode],
        action: DataChangeAction.update,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      // Do not rethrow - the error is already handled by emitting an error state
    }
  }

  /// 删除节点
  Future<void> _onDeleteNode(
    NodeDeleteEvent event,
    Emitter<NodeState> emit,
  ) async {
    try {
      // 获取要删除的节点，用于发布事件
      final deletedNode = state.getNode(event.nodeId);

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

      // 发布节点删除事件到总线
      if (deletedNode != null) {
        _eventBus.publish(NodeDataChangedEvent(
          changedNodes: [deletedNode],
          action: DataChangeAction.delete,
        ));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      // Do not rethrow - the error is already handled by emitting an error state
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

        // 发布节点更新事件到总线，通知 GraphBloc 更新连接
        _eventBus.publish(NodeDataChangedEvent(
          changedNodes: [fromNode],
          action: DataChangeAction.update,
        ));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      // Do not rethrow - the error is already handled by emitting an error state
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

        // 发布节点更新事件到总线，通知 GraphBloc 更新连接
        _eventBus.publish(NodeDataChangedEvent(
          changedNodes: [fromNode],
          action: DataChangeAction.update,
        ));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      // Do not rethrow - the error is already handled by emitting an error state
    }
  }

  /// 清除错误
  void _onClearError(
    NodeClearErrorEvent event,
    Emitter<NodeState> emit,
  ) {
    emit(state.copyWith(error: null));
  }
}
