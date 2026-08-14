import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:core/cqrs/commands/command_bus.dart';
import 'package:core/cqrs/commands/events/app_events.dart';
import 'package:core/cqrs/commands/events/event_subscription_manager.dart';
import 'package:core/cqrs/commands/models/command.dart';
import 'package:core/cqrs/queries/get_current_graph_query.dart';
import 'package:core/cqrs/queries/load_graph_query.dart';
import 'package:core/cqrs/queries/load_nodes_by_ids_query.dart';
import 'package:core/cqrs/query/query_bus.dart';
import 'package:core/plugin/hook/coordinate_system.dart';
import 'package:core/plugin/hook/ui_layout_service.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:node_layout/layout.dart';

import '../command/graph_commands.dart';
import '../service/graph_service.dart';
import '../utils/node_data_sync_helper.dart';
import 'graph_event.dart';
import 'graph_state.dart';

/// Graph BLoC - 图状态管理核心
class GraphBloc extends Bloc<GraphEvent, GraphState> {
  ///
  /// [commandBus] - 命令总线，用于执行写操作和订阅事件流
  /// [queryBus] - 查询总线，用于执行读操作
  ///
  /// 架构变更：
  /// - 移除了 Repository 参数，改用 QueryBus
  /// - CQRS 总线成为数据访问的唯一通道
  GraphBloc({
    required CommandBus commandBus,
    required QueryBus queryBus,
    UILayoutService? layoutService,
  })  : _commandBus = commandBus,
        _queryBus = queryBus,
        _layoutService = layoutService,
        super(GraphState.initial()) {
    // 初始化事件订阅管理器
    _subscriptionManager = EventSubscriptionManager('GraphBloc');

    // 注册事件处理器
    on<GraphInitializeEvent>(_onInitialize);
    on<GraphLoadEvent>(_onLoadGraph);
    on<GraphCreateEvent>(_onCreateGraph);
    on<GraphSwitchEvent>(_onSwitchGraph);
    on<GraphRenameEvent>(_onRenameGraph);
    on<GraphUpdateConfigEvent>(_onUpdateConfig);
    on<NodeAddEvent>(_onNodeAdd);
    on<NodeMoveEvent>(_onNodeMove);
    on<NodeMultiMoveEvent>(_onNodeMultiMove);
    on<NodeMoveOutEvent>(_onNodeMoveOut);
    on<NodeSelectEvent>(_onNodeSelect);
    on<SelectionClearEvent>(_onSelectionClear);
    on<NodeMultiSelectEvent>(_onNodeMultiSelect);
    on<ViewZoomEvent>(_onViewZoom);
    on<ViewMoveEvent>(_onViewMove);
    on<ViewToggleConnectionsEvent>(_onToggleConnections);
    on<ViewToggleGridEvent>(_onToggleGrid);
    on<LayoutApplyEvent>(_onApplyLayout);
    on<BatchEvent>(_onBatch);
    on<UndoEvent>(_onUndo);
    on<RedoEvent>(_onRedo);
    on<ErrorClearEvent>(_onErrorClear);
    on<RetryEvent>(_onRetry);
    on<FocusNodeEvent>(_onFocusNode);
    on<_NodeSyncedEvent>(_onNodeSynced);

    // 订阅命令总线的事件流，响应节点数据变化
    // CommandBus 现在是统一的通信中心
    _subscribeToEvents();
  }

  final CommandBus _commandBus;
  final QueryBus _queryBus;
  final UILayoutService? _layoutService;

  /// 事件订阅管理器
  ///
  /// 自动管理所有事件订阅的生命周期，防止内存泄漏。
  /// 在 close() 时自动取消所有订阅。
  late final EventSubscriptionManager _subscriptionManager;

  /// 初始化
  Future<void> _onInitialize(
    GraphInitializeEvent event,
    Emitter<GraphState> emit,
  ) async {
    emit(state.copyWith(loadingState: LoadingState.loading, error: null));

    try {
      // 读操作：通过 QueryBus
      final graphResult = await _queryBus.dispatch<Graph, GetCurrentGraphQuery>(
        const GetCurrentGraphQuery(),
      );
      final graph = graphResult.isSuccess ? graphResult.data : null;
      if (graph != null) {
        await _loadGraphData(graph, emit);
      } else {
        // 如果没有当前图，自动创建一个新图
        final command = CreateGraphCommand(graphName: 'Default Graph');
        final result = await _commandBus.dispatch(command);

        if (result.isSuccess) {
          await _loadGraphData(result.data!, emit);
        } else {
          emit(
            state.copyWith(
              loadingState: LoadingState.error,
              error: 'Failed to create default graph: ${result.error}',
            ),
          );
        }
      }
    } on FileSystemException catch (_) {
      emit(
        state.copyWith(
          loadingState: LoadingState.error,
          error:
              'Data folder not found or inaccessible. Please restart the application to recover.',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loadingState: LoadingState.error,
          error: 'Failed to load graph: ${e.toString()}',
        ),
      );
    }
  }

  /// 加载图
  Future<void> _onLoadGraph(
    GraphLoadEvent event,
    Emitter<GraphState> emit,
  ) async {
    emit(state.copyWith(loadingState: LoadingState.loading, error: null));

    try {
      // 读操作：通过 QueryBus
      final graphResult = await _queryBus.dispatch<Graph, LoadGraphQuery>(
        LoadGraphQuery(graphId: event.graphId),
      );
      if (!graphResult.isSuccess || graphResult.data == null) {
        throw GraphNotFoundException(event.graphId);
      }
      final graph = graphResult.data!;

      await _loadGraphData(graph, emit);
    } catch (e) {
      emit(
        state.copyWith(
          loadingState: LoadingState.error,
          error: 'Failed to load graph: ${e.toString()}',
        ),
      );
    }
  }

  /// 创建图
  Future<void> _onCreateGraph(
    GraphCreateEvent event,
    Emitter<GraphState> emit,
  ) async {
    emit(state.copyWith(loadingState: LoadingState.loading, error: null));

    try {
      // 写操作：通过 CommandBus
      final command = CreateGraphCommand(graphName: event.name);
      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        await _loadGraphData(result.data!, emit);
      } else {
        emit(
          state.copyWith(loadingState: LoadingState.error, error: result.error),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          loadingState: LoadingState.error,
          error: 'Failed to create graph: ${e.toString()}',
        ),
      );
    }
  }

  /// 切换图
  Future<void> _onSwitchGraph(
    GraphSwitchEvent event,
    Emitter<GraphState> emit,
  ) async {
    emit(state.copyWith(loadingState: LoadingState.loading, error: null));

    try {
      // 读操作：通过 QueryBus
      final graphResult = await _queryBus.dispatch<Graph, LoadGraphQuery>(
        LoadGraphQuery(graphId: event.graphId),
      );
      if (!graphResult.isSuccess || graphResult.data == null) {
        throw GraphNotFoundException(event.graphId);
      }
      final graph = graphResult.data!;

      await _loadGraphData(graph, emit);
    } catch (e) {
      emit(
        state.copyWith(
          loadingState: LoadingState.error,
          error: 'Failed to switch graph: ${e.toString()}',
        ),
      );
    }
  }

  /// 更新图配置
  Future<void> _onUpdateConfig(
    GraphUpdateConfigEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (state.graph.id.isEmpty) return;

    try {
      // 写操作：通过 CommandBus
      final command = UpdateGraphCommand(
        graphId: state.graph.id,
        viewConfig: event.config,
      );
      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        emit(state.copyWith(graph: result.data));
      } else {
        emit(state.copyWith(error: result.error));
      }
    } catch (e) {
      emit(state.copyWith(error: 'Failed to update config: ${e.toString()}'));
    }
  }

  /// 添加节点
  Future<void> _onNodeAdd(NodeAddEvent event, Emitter<GraphState> emit) async {
    if (state.graph.id.isEmpty) return;

    try {
      // 写操作：通过 CommandBus
      final command = AddNodeToGraphCommand(
        graphId: state.graph.id,
        nodeId: event.nodeId,
        position: event.position,
      );
      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        // 将节点附着到 UILayoutService 的 graph hook
        // 这是确保节点在图视图中正确显示的关键步骤
        final layoutService = _layoutService;
        if (layoutService != null) {
          try {
            // 检查节点是否已附着到 graph hook
            final existingHookId = layoutService.getNodeHookId(event.nodeId);
            if (existingHookId == null) {
              // 节点未附着，需要附着到 graph hook
              final position = event.position ?? const Offset(2048, 1080); // 默认中心位置
              await layoutService.attachNode(
                nodeId: event.nodeId,
                hookId: 'graph',
                position: LocalPosition.absolute(position.dx, position.dy),
              );
              debugPrint('Node ${event.nodeId} attached to graph hook at $position');
            }
          } catch (layoutError) {
            // 附着失败不阻塞主流程，但记录错误
            debugPrint('Warning: Failed to attach node to graph hook: $layoutError');
          }
        }

        // 通过 QueryBus 重新加载图数据
        final graphResult = await _queryBus.dispatch<Graph, LoadGraphQuery>(
          LoadGraphQuery(graphId: state.graph.id),
        );
        if (graphResult.isSuccess && graphResult.data != null) {
          await _loadGraphData(graphResult.data!, emit);
        }
      } else {
        emit(state.copyWith(error: result.error));
      }
    } on FileSystemException catch (_) {
      emit(
        state.copyWith(
          error: 'Cannot save changes: Data folder is missing or inaccessible.',
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: 'Failed to add node: ${e.toString()}'));
    }
  }

  /// 移动节点（乐观更新）
  Future<void> _onNodeMove(
    NodeMoveEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (state.graph.id.isEmpty) return;

    // 注意：位置现在由 UILayoutService 管理
    // 乐观更新由 UILayoutService 处理，这里只负责触发命令

    // 持久化位置（不阻塞 UI）
    // 直接通过 CommandBus 异步持久化
    _commandBus
        .dispatch(UpdateNodePositionCommand(
      graphId: state.graph.id,
      nodeId: event.nodeId,
      newPosition: event.newPosition,
    ))
        .catchError((e) async {
      // 静默失败，不影响用户体验
      debugPrint('Failed to persist node position: $e');
      return CommandResult<void>.failure(e.toString());
    });
  }

  /// 移动多个节点（批量乐观更新）
  Future<void> _onNodeMultiMove(
    NodeMultiMoveEvent event,
    Emitter<GraphState> emit,
  ) async {
    final currentState = state;
    if (currentState.graph.id.isEmpty) return;

    // 注意：位置现在由 UILayoutService 管理
    // 乐观更新由 UILayoutService 处理，这里只负责触发命令

    // 持久化位置（不阻塞 UI）
    // 批量更新节点位置
    for (final entry in event.movements.entries) {
      _commandBus
          .dispatch(UpdateNodePositionCommand(
        graphId: currentState.graph.id,
        nodeId: entry.key,
        newPosition: entry.value,
      ))
          .catchError((e) {
        // 静默失败，不影响用户体验
        debugPrint('Failed to persist node position: $e');
        return CommandResult<void>.failure(e.toString());
      });
    }
  }

  /// 移出节点（从图中移除，但保留节点数据）
  ///
  /// 将指定节点从当前图中移除，但节点数据文件仍然保留。
  /// 这与删除节点不同：移出只是改变节点的图归属，而删除会移除节点数据。
  Future<void> _onNodeMoveOut(
    NodeMoveOutEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (state.graph.id.isEmpty) return;

    try {
      // 写操作：通过 CommandBus
      final command = RemoveNodeFromGraphCommand(
        graphId: state.graph.id,
        nodeId: event.nodeId,
      );
      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        // 通过 QueryBus 重新加载图数据
        final graphResult = await _queryBus.dispatch<Graph, LoadGraphQuery>(
          LoadGraphQuery(graphId: state.graph.id),
        );
        if (graphResult.isSuccess && graphResult.data != null) {
          await _loadGraphData(graphResult.data!, emit);
        }
      } else {
        emit(state.copyWith(error: result.error));
      }
    } on FileSystemException catch (_) {
      emit(
        state.copyWith(
          error: 'Cannot save changes: Data folder is missing or inaccessible.',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          error: 'Failed to remove node from graph: ${e.toString()}',
        ),
      );
    }
  }

  /// 选择节点
  void _onNodeSelect(NodeSelectEvent event, Emitter<GraphState> emit) {
    if (event.addToSelection) {
      // 添加到选择
      final newSelectedIds = Set<String>.from(state.selectedNodeIds)
      ..add(event.nodeId);

      emit(
        state.copyWith(
          selectionState: state.selectionState.copyWith(
            selectedNodeIds: newSelectedIds,
            lastSelectedId: event.nodeId,
            selectionMode: SelectionMode.multi,
          ),
        ),
      );
    } else {
      // 单选
      emit(
        state.copyWith(
          selectionState: state.selectionState.copyWith(
            selectedNodeIds: {event.nodeId},
            lastSelectedId: event.nodeId,
            selectionMode: SelectionMode.single,
          ),
        ),
      );
    }
  }

  /// 清除选择
  void _onSelectionClear(SelectionClearEvent event, Emitter<GraphState> emit) {
    emit(state.copyWith(selectionState: const SelectionState()));
  }

  /// 多选节点
  void _onNodeMultiSelect(
    NodeMultiSelectEvent event,
    Emitter<GraphState> emit,
  ) {
    emit(
      state.copyWith(
        selectionState: state.selectionState.copyWith(
          selectedNodeIds: event.nodeIds.toSet(),
          lastSelectedId: event.nodeIds.isNotEmpty ? event.nodeIds.last : null,
          selectionMode: SelectionMode.multi,
        ),
      ),
    );
  }

  /// 缩放视图
  ///
  /// 架构说明：
  /// - BLoC 先更新 UI 状态（乐观更新）
  /// - 然后异步持久化到 CommandHandler
  /// - 持久化失败不影响用户体验
  /// - 业务逻辑（Camera 和 GraphViewConfig 构造）已迁移到 UpdateViewCameraHandler
  Future<void> _onViewZoom(
    ViewZoomEvent event,
    Emitter<GraphState> emit,
  ) async {
    // 使用事件中提供的位置，或者使用当前位置
    final newPosition = event.position ?? state.viewState.camera.position;

    // 乐观更新 - 立即更新 UI 状态
    emit(
      state.copyWith(
        viewState: state.viewState.copyWith(
          zoomLevel: event.zoomLevel,
          camera: state.viewState.camera.copyWith(
            position: newPosition,
            zoom: event.zoomLevel,
          ),
        ),
      ),
    );

    // 如果没有加载 graph，只更新内存状态
    if (state.graph.id.isEmpty) return;

    // 异步持久化（不阻塞 UI）
    // 业务逻辑已迁移到 UpdateViewCameraHandler
    _commandBus
        .dispatch(UpdateViewCameraCommand(
      graphId: state.graph.id,
      position: newPosition,
      zoomLevel: event.zoomLevel,
    ))
        .then((result) {
      // 持久化成功，graph 对象会通过事件总线自动同步
      if (result.isSuccess && result.data != null) {
        // 注意：这里不能直接 emit，因为可能在另一个事件处理中
        // 实际的 graph 更新会通过事件总线同步
      }
    }).catchError((e) {
      // 持久化失败，不影响用户体验
      debugPrint('Failed to persist camera zoom: $e');
    });
  }

  /// 移动相机位置
  ///
  /// 架构说明：
  /// - BLoC 先更新 UI 状态（乐观更新）
  /// - 然后异步持久化到 CommandHandler
  /// - 持久化失败不影响用户体验
  /// - 业务逻辑（Camera 和 GraphViewConfig 构造）已迁移到 UpdateViewCameraHandler
  Future<void> _onViewMove(
    ViewMoveEvent event,
    Emitter<GraphState> emit,
  ) async {
    // 乐观更新 - 立即更新 UI 状态
    emit(
      state.copyWith(
        viewState: state.viewState.copyWith(
          camera: state.viewState.camera.copyWith(position: event.position),
        ),
      ),
    );

    // 如果没有加载 graph，只更新内存状态
    if (state.graph.id.isEmpty) return;

    // 异步持久化（不阻塞 UI）
    // 业务逻辑已迁移到 UpdateViewCameraHandler
    _commandBus
        .dispatch(UpdateViewCameraCommand(
      graphId: state.graph.id,
      position: event.position,
    ))
        .then((result) {
      // 持久化成功，graph 对象会通过事件总线自动同步
      if (result.isSuccess && result.data != null) {
        // 注意：这里不能直接 emit，因为可能在另一个事件处理中
        // 实际的 graph 更新会通过事件总线同步
      }
    }).catchError((e) {
      // 持久化失败，不影响用户体验
      debugPrint('Failed to persist camera position: $e');
    });
  }

  /// 切换连接线显示
  void _onToggleConnections(
    ViewToggleConnectionsEvent event,
    Emitter<GraphState> emit,
  ) {
    emit(
      state.copyWith(
        viewState: state.viewState.copyWith(
          showConnections: !state.viewState.showConnections,
        ),
      ),
    );
  }

  /// 切换网格显示
  void _onToggleGrid(ViewToggleGridEvent event, Emitter<GraphState> emit) {
    emit(
      state.copyWith(
        viewState: state.viewState.copyWith(
          gridVisible: !state.viewState.gridVisible,
        ),
      ),
    );
  }

  /// 应用布局
  ///
  /// 架构说明：
  /// - 布局业务逻辑已迁移到 ApplyLayoutCommandHandler
  /// - BLoC 只负责管理 UI 状态和触发命令
  /// - 节点位置更新会通过事件总线自动同步
  Future<void> _onApplyLayout(
    LayoutApplyEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (state.graph.id.isEmpty) return;

    try {
      // 更新 UI 状态：正在应用布局
      emit(state.copyWith(loadingState: LoadingState.loading));

      // 通过 CommandBus 执行布局操作
      // 业务逻辑在 ApplyLayoutHandler 中处理
      final result = await _commandBus.dispatch(
        ApplyLayoutCommand(
          // 将 LayoutAlgorithm 枚举转换为字符串
          layoutType: event.algorithm.name,
          graphId: state.graph.id,
        ),
      );

      if (result.isSuccess) {
        // 布局应用成功，更新 UI 状态
        emit(state.copyWith(loadingState: LoadingState.loaded));

        // 节点位置会通过事件总线自动更新
        // 不需要手动重新加载图数据
      } else {
        // 布局应用失败，显示错误
        emit(state.copyWith(
          loadingState: LoadingState.error,
          error: result.error ?? 'Failed to apply layout',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        loadingState: LoadingState.error,
        error: 'Failed to apply layout: ${e.toString()}',
      ));
    }
  }

  /// 批量事件
  ///
  /// 架构说明：
  /// - 业务逻辑（节点 ID 收集、去重、列表合并）已迁移到 BatchNodeOperationsHandler
  /// - BLoC 只负责 UI 状态管理和触发命令
  Future<void> _onBatch(BatchEvent event, Emitter<GraphState> emit) async {
    if (state.graph.id.isEmpty) return;

    try {
      // 收集所有要添加和移出的节点 ID
      final nodeIdsToAdd = <String>[];
      final nodeIdsToMoveOut = <String>[];

      // 遍历所有事件，提取节点 ID
      for (final graphEvent in event.events) {
        if (graphEvent is NodeAddEvent) {
          nodeIdsToAdd.add(graphEvent.nodeId);
        } else if (graphEvent is NodeMoveOutEvent) {
          nodeIdsToMoveOut.add(graphEvent.nodeId);
        }
      }

      // 如果没有操作，直接返回
      if (nodeIdsToAdd.isEmpty && nodeIdsToMoveOut.isEmpty) {
        return;
      }

      // 写操作：通过 CommandBus
      // 业务逻辑已迁移到 BatchNodeOperationsHandler
      final result = await _commandBus.dispatch(BatchNodeOperationsCommand(
        graphId: state.graph.id,
        nodeIdsToAdd: nodeIdsToAdd,
        nodeIdsToMoveOut: nodeIdsToMoveOut,
      ));

      if (!result.isSuccess) {
        throw Exception(result.error);
      }

      final savedGraph = result.data!;

      // 重新加载图数据（包括节点和连接）
      await _loadGraphData(savedGraph, emit);
    } catch (e) {
      debugPrint('Error in _onBatch: $e');
      emit(
        state.copyWith(
          error: 'Failed to process batch operations: ${e.toString()}',
        ),
      );
    }
  }

  /// 撤销
  Future<void> _onUndo(UndoEvent event, Emitter<GraphState> emit) async {
    // 撤销功能实现说明：
    // 需要 UndoManager 服务来维护命令历史栈
    // 实现步骤：
    // 1. 创建 UndoManager 服务管理命令栈
    // 2. 在 CommandBus 中注册 UndoMiddleware
    // 3. 成功执行的命令推入 undo 栈
    // 4. 撤销时从 undo 栈弹出并执行 undo()
    // 5. 撤销的命令推入 redo 栈
    // 6. 更新 UI 状态反映撤销结果
    //
    // 当前：通过 QueryBus 重新加载图数据作为临时方案
    if (state.graph.id.isNotEmpty) {
      final graphResult = await _queryBus.dispatch<Graph, LoadGraphQuery>(
        LoadGraphQuery(graphId: state.graph.id),
      );
      if (graphResult.isSuccess && graphResult.data != null) {
        await _loadGraphData(graphResult.data!, emit);
      }
    }
  }

  /// 重做
  Future<void> _onRedo(RedoEvent event, Emitter<GraphState> emit) async {
    // 重做功能实现说明：
    // 需要 UndoManager 服务来维护 redo 栈
    // 实现步骤：
    // 1. 从 redo 栈弹出命令
    // 2. 重新执行命令
    // 3. 推入 undo 栈
    // 4. 更新 UI 状态反映重做结果
    //
    // 当前：通过 QueryBus 重新加载图数据作为临时方案
    if (state.graph.id.isNotEmpty) {
      final graphResult = await _queryBus.dispatch<Graph, LoadGraphQuery>(
        LoadGraphQuery(graphId: state.graph.id),
      );
      if (graphResult.isSuccess && graphResult.data != null) {
        await _loadGraphData(graphResult.data!, emit);
      }
    }
  }

  /// 清除错误
  void _onErrorClear(ErrorClearEvent event, Emitter<GraphState> emit) {
    emit(state.copyWith(error: null));
  }

  /// 重试
  Future<void> _onRetry(RetryEvent event, Emitter<GraphState> emit) async {
    add(const GraphInitializeEvent());
  }

  /// 加载图数据
  Future<void> _loadGraphData(Graph graph, Emitter<GraphState> emit) async {
    try {
      // 读操作：通过 QueryBus 加载节点
      final nodeIds = graph.nodeIds;
      final nodesResult = await _queryBus.dispatch<List<Node>, LoadNodesByIdsQuery>(
        LoadNodesByIdsQuery(nodeIds: nodeIds),
      );
      final nodes = nodesResult.isSuccess ? nodesResult.data ?? [] : <Node>[];
      final connections = Connection.calculateConnections(nodes);

      // 确保所有节点都附着到 UILayoutService 的 graph hook
      // 这是修复节点不显示问题的关键步骤
      await _ensureNodesAttachedToGraphHook(nodes);

      // 从 graph.viewConfig 中读取相机配置并更新 viewState
      final cameraState = CameraState(
        position: Offset(graph.viewConfig.camera.x, graph.viewConfig.camera.y),
        zoom: graph.viewConfig.camera.zoom,
      );

      emit(
        state.copyWith(
          graph: graph,
          nodes: nodes,
          connections: connections,
          viewState: state.viewState.copyWith(
            camera: cameraState,
            zoomLevel: graph.viewConfig.camera.zoom,
          ),
          loadingState: LoadingState.loaded,
          error: null,
        ),
      );
    } on FileSystemException catch (_) {
      emit(
        state.copyWith(
          loadingState: LoadingState.error,
          error: 'Data files not found. Some nodes may be missing.',
          nodes: const [],
          connections: const [],
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loadingState: LoadingState.error,
          error: 'Failed to load graph data: ${e.toString()}',
          nodes: const [],
          connections: const [],
        ),
      );
    }
  }

  /// 确保所有节点都附着到 UILayoutService 的 graph hook
  ///
  /// 这是修复节点不显示问题的关键方法。
  /// 当加载图数据时，检查每个节点是否已附着到 graph hook，
  /// 如果未附着，则自动附着到默认位置。
  Future<void> _ensureNodesAttachedToGraphHook(List<Node> nodes) async {
    final layoutService = _layoutService;
    if (layoutService == null) {
      debugPrint('Warning: UILayoutService not available, cannot attach nodes');
      return;
    }

    // 检查 graph hook 是否存在
    final graphHook = layoutService.getHook('graph');
    if (graphHook == null) {
      debugPrint('Warning: graph hook not found in UILayoutService');
      return;
    }

    var attachedCount = 0;
    for (final node in nodes) {
      final existingHookId = layoutService.getNodeHookId(node.id);
      if (existingHookId == null) {
        // 节点未附着到任何 hook，需要附着到 graph hook
        try {
          // 尝试从节点元数据中获取位置
          final posX = (node.metadata['positionX'] as num?)?.toDouble();
          final posY = (node.metadata['positionY'] as num?)?.toDouble();

          // 使用节点元数据中的位置，或生成随机位置避免重叠
          final position = posX != null && posY != null
              ? Offset(posX, posY)
              : _generateDefaultPosition(attachedCount);

          await layoutService.attachNode(
            nodeId: node.id,
            hookId: 'graph',
            position: LocalPosition.absolute(position.dx, position.dy),
          );
          attachedCount++;
        } catch (e) {
          debugPrint('Warning: Failed to attach node ${node.id} to graph hook: $e');
        }
      }
    }

    if (attachedCount > 0) {
      debugPrint('Attached $attachedCount nodes to graph hook');
    }
  }

  /// 生成默认位置，避免所有节点重叠在同一位置
  ///
  /// 使用螺旋布局算法，让节点均匀分布在中心周围
  Offset _generateDefaultPosition(int index) {
    const centerX = 2048.0; // 世界中心 X
    const centerY = 1080.0; // 世界中心 Y
    const spacing = 150.0;  // 节点间距

    if (index == 0) {
      return const Offset(centerX, centerY);
    }

    // 螺旋布局
    final angle = index * 0.5; // 每个节点旋转角度
    final radius = spacing * (1 + index * 0.2); // 随索引增加半径

    return Offset(
      centerX + radius * cos(angle),
      centerY + radius * sin(angle),
    );
  }

  /// 重命名图
  Future<void> _onRenameGraph(
    GraphRenameEvent event,
    Emitter<GraphState> emit,
  ) async {
    final currentState = state;
    if (currentState.graph.id.isEmpty) return;

    try {
      // 写操作：通过 CommandBus
      final command = RenameGraphCommand(
        graphId: currentState.graph.id,
        updatedName: event.name,
      );
      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        emit(currentState.copyWith(graph: result.data));
      } else {
        emit(currentState.copyWith(error: result.error));
      }
    } catch (e) {
      emit(
        currentState.copyWith(error: 'Failed to rename graph: ${e.toString()}'),
      );
    }
  }

  /// 处理 NodeBloc 同步完成事件
  void _onNodeSynced(_NodeSyncedEvent event, Emitter<GraphState> emit) {
    emit(state.copyWith(nodes: event.nodes, connections: event.connections));
  }

  /// 聚焦节点
  ///
  /// 架构说明：
  /// - 业务逻辑（节点查找、相机位置计算、ViewConfig 构造）已迁移到 UpdateViewCameraHandler
  /// - BLoC 只负责 UI 状态管理和触发命令
  Future<void> _onFocusNode(
    FocusNodeEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (state.graph.id.isEmpty) return;
    if (state.nodes.isEmpty) return;

    try {
      // 查找目标节点
      final targetNode = state.nodes.firstWhere(
        (n) => n.id == event.nodeId,
        orElse: () => state.nodes.first,
      );

      // 计算新的相机位置（将节点居中）
      // 注意：节点位置现在从 UILayoutService 获取
      // 这里使用节点元数据中的位置（如果有）或使用默认值
      final nodePosition = Offset(
        (targetNode.metadata['positionX'] as num?)?.toDouble() ?? 0,
        (targetNode.metadata['positionY'] as num?)?.toDouble() ?? 0,
      );

      // 更新 UI 状态
      emit(
        state.copyWith(
          viewState: state.viewState.copyWith(
            camera: state.viewState.camera.copyWith(position: nodePosition),
          ),
        ),
      );

      // 写操作：通过 CommandBus
      // 业务逻辑已迁移到 UpdateViewCameraHandler
      final result = await _commandBus.dispatch(UpdateViewCameraCommand(
        graphId: state.graph.id,
        position: nodePosition,
      ));

      if (!result.isSuccess) {
        throw Exception(result.error);
      }
    } catch (e) {
      emit(state.copyWith(error: 'Failed to focus node: ${e.toString()}'));
    }
  }

  /// 订阅命令总线的事件流，响应节点数据变化
  ///
  /// 通过 CommandBus.eventStream 监听节点变化事件，
  /// 实现图视图与节点数据的同步。
  ///
  /// 架构变更：
  /// - CommandBus 现在是统一的通信中心
  /// - 命令执行后自动发布事件到 eventStream
  ///
  /// 使用 EventSubscriptionManager 自动管理订阅生命周期，
  /// 防止内存泄漏。
  void _subscribeToEvents() {
    _subscriptionManager.track(
      'NodeDataChanged',
      _commandBus.eventStream.listen((event) {
        if (event is NodeDataChangedEvent) {
          _handleNodeDataChanged(event);
        }
      }),
    );
  }

  /// 处理节点数据变化事件
  ///
  /// 架构说明：
  /// - BLoC 订阅 CommandBus 的事件流
  /// - 当节点数据变化时更新 UI 状态
  /// - 业务逻辑已提取到 NodeDataSyncHelper 工具类
  void _handleNodeDataChanged(NodeDataChangedEvent event) {
    if (state.graph.id.isEmpty) return;

    // 业务逻辑已提取到 NodeDataSyncHelper
    final result = NodeDataSyncHelper.calculateUpdatedData(
      currentNodes: state.nodes,
      graphNodeIds: state.graph.nodeIds.toSet(),
      event: event,
    );

    // 如果结果中没有节点，返回
    final updatedNodes = result['nodes'] as List<Node>;
    if (updatedNodes.isEmpty && event.action != DataChangeAction.delete) return;

    final updatedConnections = result['connections'] as List<Connection>;

    // 使用 add 而不是 emit，因为我们在 stream 回调中
    add(_NodeSyncedEvent(
      nodes: updatedNodes,
      connections: updatedConnections,
    ));
  }

  @override
  Future<void> close() {
    // 事件订阅管理器会自动取消所有订阅
    _subscriptionManager.dispose();
    return super.close();
  }
}

/// 内部事件：NodeBloc 同步完成
class _NodeSyncedEvent extends GraphEvent {
  const _NodeSyncedEvent({required this.nodes, required this.connections});

  final List<Node> nodes;
  final List<Connection> connections;

  @override
  List<Object?> get props => [nodes, connections];
}
