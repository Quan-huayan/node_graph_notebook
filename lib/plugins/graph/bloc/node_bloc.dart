import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/commands/command_bus.dart';
import '../../../../core/cqrs/queries/search_nodes_query.dart';
import '../../../../core/cqrs/query/query_bus.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/events/event_subscription_manager.dart';
import '../../../../core/models/node.dart';
import '../../../../core/repositories/repositories.dart';
import '../command/node_commands.dart';
import 'node_event.dart';
import 'node_state.dart';

/// 节点 BLoC - 节点数据管理核心
///
/// 职责：
/// - 管理UI状态（isLoading, error）
/// - 分发Event到CommandBus（写操作）
/// - 直接查询Repository（读操作）
/// - 订阅CommandBus事件流更新状态
///
/// 架构说明：
/// - 写操作通过 CommandBus（业务逻辑层）
/// - 读操作直接通过 Repository（数据访问层）
/// - 订阅 CommandBus.eventStream 接收数据变化通知（替代 AppEventBus）
/// - BLoC 只负责 UI 状态管理，不包含业务逻辑
class NodeBloc extends Bloc<NodeEvent, NodeState> {
  /// 创建 Node BLoC
  ///
  /// [commandBus] - 命令总线，用于执行写操作和订阅事件流
  /// [queryBus] - 查询总线，用于复杂查询操作
  /// [nodeRepository] - 节点数据仓库，用于简单读操作
  ///
  /// 架构变更：
  /// - 移除了 eventBus 参数，改用 commandBus.eventStream
  /// - CommandBus 现在是统一的通信中心（命令 + 事件）
  /// - 复杂查询（如搜索）通过 QueryBus，简单查询直接通过 Repository
  NodeBloc({
    required CommandBus commandBus,
    required QueryBus queryBus,
    required NodeRepository nodeRepository,
  })  : _commandBus = commandBus,
       _queryBus = queryBus,
       _nodeRepository = nodeRepository,
       super(NodeState.initial()) {
    // 初始化事件订阅管理器
    _subscriptionManager = EventSubscriptionManager('NodeBloc');

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
    on<NodeDataChangedInternalEvent>(_onDataChangedInternal);

    // 订阅 CommandBus 的事件流以响应其他组件的更改
    // 使用 EventSubscriptionManager 自动管理订阅生命周期
    _subscriptionManager.track(
      'NodeDataChanged',
      _commandBus.eventStream.listen((event) {
        if (event is NodeDataChangedEvent) {
          add(
            NodeDataChangedInternalEvent(
              changedNodes: event.changedNodes,
              action: event.action,
            ),
          );
        }
      }),
    );
  }

  final CommandBus _commandBus;
  final QueryBus _queryBus;
  final NodeRepository _nodeRepository;

  /// 事件订阅管理器
  ///
  /// 自动管理所有事件订阅的生命周期，防止内存泄漏。
  /// 在 close() 时自动取消所有订阅。
  late final EventSubscriptionManager _subscriptionManager;

  /// 加载节点列表
  Future<void> _onLoadNodes(
    NodeLoadEvent event,
    Emitter<NodeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // 直接查询Repository（读操作）
      // 使用 queryAll() 获取所有节点
      final nodes = await _nodeRepository.queryAll();
      emit(state.copyWith(nodes: nodes, isLoading: false, error: null));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
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
      // 通过 QueryBus 执行复杂查询（读操作）
      final result = await _queryBus.dispatch<List<Node>, SearchNodesQuery>(
        SearchNodesQuery(keyword: event.query),
      );

      if (result.isSuccess) {
        emit(state.copyWith(nodes: result.data ?? [], isLoading: false, error: null));
      } else {
        emit(state.copyWith(isLoading: false, error: result.error));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// 创建节点
  Future<void> _onCreateNode(
    NodeCreateEvent event,
    Emitter<NodeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // 通过CommandBus执行写操作
      final command = CreateNodeCommand(
        title: event.title,
        content: event.content,
        position: event.position,
        tags: event.metadata?['tags'] as List<String>?,
      );

      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        // 事件已经由Handler发布，这里只需要更新状态
        // result.data 可能是 null，需要检查
        final newNode = result.data;
        if (newNode != null) {
          final newNodes = [...state.nodes, newNode];
          emit(state.copyWith(nodes: newNodes, isLoading: false, error: null));
        } else {
          emit(state.copyWith(isLoading: false));
        }
      } else {
        emit(state.copyWith(isLoading: false, error: result.error));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// 创建内容节点
  Future<void> _onCreateContentNode(
    NodeCreateContentEvent event,
    Emitter<NodeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // 通过CommandBus执行写操作
      final command = CreateNodeCommand(
        title: event.title,
        content: event.content,
        tags: event.metadata?['tags'] as List<String>?,
      );

      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        // result.data 可能是 null，需要检查
        final newNode = result.data;
        if (newNode != null) {
          final newNodes = [...state.nodes, newNode];
          emit(state.copyWith(nodes: newNodes, isLoading: false, error: null));
        } else {
          emit(state.copyWith(isLoading: false));
        }
      } else {
        emit(state.copyWith(isLoading: false, error: result.error));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// 更新节点
  Future<void> _onUpdateNode(
    NodeUpdateEvent event,
    Emitter<NodeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // 查找旧节点（使用 O(1) 查找）
      final oldNode = state.getNode(event.nodeId);
      if (oldNode == null) {
        emit(state.copyWith(isLoading: false, error: '节点不存在: ${event.nodeId}'));
        return;
      }

      // 通过CommandBus执行写操作
      final command = UpdateNodeCommand(
        oldNode: oldNode,
        newNode: oldNode.copyWith(
          title: event.title,
          content: event.content,
          position: event.position,
          viewMode: event.viewMode,
          metadata: event.metadata,
        ),
      );

      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        // 事件已经由Handler发布，这里只需要更新状态
        // result.data 可能是 null，需要检查
        final updatedNode = result.data;
        if (updatedNode != null) {
          final newNodes = state.nodes.map((n) => n.id == event.nodeId ? updatedNode : n).toList();
          emit(state.copyWith(nodes: newNodes, isLoading: false, error: null));
        } else {
          emit(state.copyWith(isLoading: false));
        }
      } else {
        emit(state.copyWith(isLoading: false, error: result.error));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// 替换节点
  Future<void> _onReplaceNode(
    NodeReplaceEvent event,
    Emitter<NodeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // 查找旧节点（使用 O(1) 查找）
      final oldNode = state.getNode(event.node.id);
      if (oldNode == null) {
        emit(state.copyWith(isLoading: false, error: '节点不存在: ${event.node.id}'));
        return;
      }

      // 通过CommandBus执行写操作
      final command = UpdateNodeCommand(oldNode: oldNode, newNode: event.node);

      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        // 事件已经由Handler发布，这里只需要更新状态
        // result.data 可能是 null，需要检查
        final updatedNode = result.data;
        if (updatedNode != null) {
          final newNodes = state.nodes.map((n) => n.id == event.node.id ? updatedNode : n).toList();
          emit(state.copyWith(nodes: newNodes, isLoading: false, error: null));
        } else {
          emit(state.copyWith(isLoading: false));
        }
      } else {
        emit(state.copyWith(isLoading: false, error: result.error));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// 删除节点
  Future<void> _onDeleteNode(
    NodeDeleteEvent event,
    Emitter<NodeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // 获取要删除的节点（使用 O(1) 查找）
      final node = state.getNode(event.nodeId);
      if (node == null) {
        emit(state.copyWith(isLoading: false, error: '节点不存在: ${event.nodeId}'));
        return;
      }

      // 通过CommandBus执行写操作
      final command = DeleteNodeCommand(node: node);

      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        // 事件已经由Handler发布，这里只需要更新状态
        final newNodes = state.nodes
            .where((n) => n.id != event.nodeId)
            .toList();
        final updatedSelectedIds = state.selectedNodeIds
            .where((id) => id != event.nodeId)
            .toSet();
        final updatedSelectedNode = state.selectedNode?.id == event.nodeId
            ? null
            : state.selectedNode;

        emit(
          state.copyWith(
            nodes: newNodes,
            selectedNodeIds: updatedSelectedIds,
            selectedNode: updatedSelectedNode,
            isLoading: false,
            error: null,
          ),
        );
      } else {
        emit(state.copyWith(isLoading: false, error: result.error));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// 连接节点
  Future<void> _onConnectNodes(
    NodeConnectEvent event,
    Emitter<NodeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // 通过CommandBus执行写操作
      final command = ConnectNodesCommand(
        sourceId: event.fromNodeId,
        targetId: event.toNodeId,
        properties: event.properties,
      );

      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        // 重新加载节点以获取更新后的引用列表
        final fromNode = await _nodeRepository.load(event.fromNodeId);
        if (fromNode != null) {
          final updatedNodes = state.nodes.map((n) => n.id == event.fromNodeId ? fromNode : n).toList();

          emit(
            state.copyWith(nodes: updatedNodes, isLoading: false, error: null),
          );
        } else {
          emit(state.copyWith(isLoading: false));
        }
      } else {
        emit(state.copyWith(isLoading: false, error: result.error));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// 断开节点连接
  Future<void> _onDisconnectNodes(
    NodeDisconnectEvent event,
    Emitter<NodeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // 通过CommandBus执行写操作
      final command = DisconnectNodesCommand(
        sourceId: event.fromNodeId,
        targetId: event.toNodeId,
      );

      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        // 重新加载节点以获取更新后的引用列表
        final fromNode = await _nodeRepository.load(event.fromNodeId);
        if (fromNode != null) {
          final updatedNodes = state.nodes.map((n) => n.id == event.fromNodeId ? fromNode : n).toList();

          emit(
            state.copyWith(nodes: updatedNodes, isLoading: false, error: null),
          );
        } else {
          emit(state.copyWith(isLoading: false));
        }
      } else {
        emit(state.copyWith(isLoading: false, error: result.error));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// 清除错误
  void _onClearError(NodeClearErrorEvent event, Emitter<NodeState> emit) {
    emit(state.copyWith(error: null));
  }

  /// 处理节点数据变化内部事件
  ///
  /// 当其他BLoC或组件通过CommandBus修改节点数据时，EventBus会发布事件
  /// 这里通过内部事件更新UI状态
  void _onDataChangedInternal(
    NodeDataChangedInternalEvent event,
    Emitter<NodeState> emit,
  ) {
    switch (event.action) {
      case DataChangeAction.create:
        // 添加新节点到状态
        final newNodes = [...state.nodes];
        for (final changedNode in event.changedNodes) {
          if (!state.nodes.any((n) => n.id == changedNode.id)) {
            newNodes.add(changedNode);
          }
        }
        emit(state.copyWith(nodes: newNodes));
        break;

      case DataChangeAction.update:
        // 更新现有节点
        final updatedNodes = state.nodes.map((n) {
          final updated = event.changedNodes.firstWhere(
            (u) => u.id == n.id,
            orElse: () => n,
          );
          return updated.id == n.id ? updated : n;
        }).toList();
        emit(state.copyWith(nodes: updatedNodes));
        break;

      case DataChangeAction.delete:
        // 移除已删除的节点
        final remainingNodes = state.nodes.where((n) => !event.changedNodes.any((d) => d.id == n.id)).toList();
        emit(state.copyWith(nodes: remainingNodes));
        break;
    }
  }

  @override
  Future<void> close() {
    // 事件订阅管理器会自动取消所有订阅
    _subscriptionManager.dispose();
    return super.close();
  }
}
