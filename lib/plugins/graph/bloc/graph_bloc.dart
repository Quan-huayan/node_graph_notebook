import 'dart:async';
import 'dart:io';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/models.dart';
import '../../../../core/repositories/graph_repository.dart';
import '../../../../core/repositories/node_repository.dart';
import '../../../core/cqrs/commands/command_bus.dart';
import '../../../core/cqrs/commands/events/app_events.dart';
import '../../../core/cqrs/commands/events/event_subscription_manager.dart';
import '../../../core/cqrs/commands/models/command.dart';
import '../../layout/command/layout_commands.dart';
import '../command/graph_commands.dart';
import '../service/graph_service.dart';
import 'graph_event.dart';
import 'graph_state.dart';

/// Graph BLoC - 图状态管理核心
class GraphBloc extends Bloc<GraphEvent, GraphState> {
  ///
  /// [commandBus] - 命令总线，用于执行写操作和订阅事件流
  /// [graphRepository] - 图数据仓库，用于读操作
  /// [nodeRepository] - 节点数据仓库，用于读操作
  ///
  /// 架构变更：
  /// - 移除了 eventBus 参数，改用 commandBus.eventStream
  /// - CommandBus 现在是统一的通信中心（命令 + 事件）
  GraphBloc({
    required CommandBus commandBus,
    required GraphRepository graphRepository,
    required NodeRepository nodeRepository,
  })  : _commandBus = commandBus,
        _graphRepository = graphRepository,
        _nodeRepository = nodeRepository,
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
  final GraphRepository _graphRepository;
  final NodeRepository _nodeRepository;

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
      // 读操作：直接使用 Repository
      final graph = await _graphRepository.getCurrent();
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
      // 读操作：直接使用 Repository
      final graph = await _graphRepository.load(event.graphId);
      if (graph == null) {
        throw GraphNotFoundException(event.graphId);
      }

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
      // 读操作：直接使用 Repository
      final graph = await _graphRepository.load(event.graphId);
      if (graph == null) {
        throw GraphNotFoundException(event.graphId);
      }

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
      // 先更新节点位置（如果提供了）
      if (event.position != null) {
        final updatedPositions = Map<String, Offset>.from(
          state.graph.nodePositions,
        );
        updatedPositions[event.nodeId] = event.position!;

        final updatedGraph = state.graph.copyWith(
          nodePositions: updatedPositions,
        );
        emit(state.copyWith(graph: updatedGraph));
      }

      // 写操作：通过 CommandBus
      final command = AddNodeToGraphCommand(
        graphId: state.graph.id,
        nodeId: event.nodeId,
        position: event.position,
      );
      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        // 重新加载图数据
        final graph = await _graphRepository.load(state.graph.id);
        if (graph != null) {
          await _loadGraphData(graph, emit);
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

    // 乐观更新 - 立即更新状态
    final updatedPositions = Map<String, Offset>.from(
      state.graph.nodePositions,
    );
    updatedPositions[event.nodeId] = event.newPosition;

    final updatedGraph = state.graph.copyWith(nodePositions: updatedPositions);

    emit(state.copyWith(graph: updatedGraph));

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

    // 乐观更新 - 立即更新所有节点位置
    final updatedPositions = Map<String, Offset>.from(
      currentState.graph.nodePositions,
    )
    ..addAll(event.movements);

    final updatedGraph = currentState.graph.copyWith(
      nodePositions: updatedPositions,
    );

    emit(currentState.copyWith(graph: updatedGraph));

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
        // 重新加载图数据
        final graph = await _graphRepository.load(state.graph.id);
        if (graph != null) {
          await _loadGraphData(graph, emit);
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
  /// - 然后异步持久化到 GraphRepository
  /// - 持久化失败不影响用户体验
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

    // 异步持久化到 GraphRepository（不阻塞 UI）
    final updatedConfig = state.graph.viewConfig.copyWith(
      camera: Camera(
        x: newPosition.dx,
        y: newPosition.dy,
        zoom: event.zoomLevel,
        centerWidth: state.graph.viewConfig.camera.centerWidth,
        centerHeight: state.graph.viewConfig.camera.centerHeight,
      ),
    );

    _commandBus
        .dispatch(UpdateGraphCommand(
      graphId: state.graph.id,
      viewConfig: updatedConfig,
    ))
        .then((result) {
      // 持久化成功，更新 graph 对象
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
  /// - 然后异步持久化到 GraphRepository
  /// - 持久化失败不影响用户体验
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

    // 异步持久化到 GraphRepository（不阻塞 UI）
    final updatedConfig = state.graph.viewConfig.copyWith(
      camera: Camera(
        x: event.position.dx,
        y: event.position.dy,
        zoom: state.viewState.camera.zoom,
      ),
    );

    _commandBus
        .dispatch(UpdateGraphCommand(
      graphId: state.graph.id,
      viewConfig: updatedConfig,
    ))
        .then((result) {
      // 持久化成功，更新 graph 对象
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
  Future<void> _onBatch(BatchEvent event, Emitter<GraphState> emit) async {
    if (state.graph.id.isEmpty) return;

    try {
      // 收集所有要添加和移出的节点ID
      final nodeIdsToAdd = <String>[];
      final nodeIdsToMoveOut = <String>[];

      // 遍历所有事件，提取节点ID
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

      // 一次性更新图的节点ID列表
      final currentNodeIds = List<String>.from(state.graph.nodeIds);

      // 移除节点
      nodeIdsToMoveOut.forEach(currentNodeIds.remove);

      // 添加节点（去重）
      for (final nodeId in nodeIdsToAdd) {
        if (!currentNodeIds.contains(nodeId)) {
          currentNodeIds.add(nodeId);
        }
      }

      // 保存到文件 - 通过 CommandBus
      final command = UpdateGraphCommand(
        graphId: state.graph.id,
        nodeIds: currentNodeIds,
      );
      final result = await _commandBus.dispatch(command);

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
    // 当前：重新加载图数据作为临时方案
    if (state.graph.id.isNotEmpty) {
      final graph = await _graphRepository.load(state.graph.id);
      if (graph != null) {
        await _loadGraphData(graph, emit);
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
    // 当前：重新加载图数据作为临时方案
    if (state.graph.id.isNotEmpty) {
      final graph = await _graphRepository.load(state.graph.id);
      if (graph != null) {
        await _loadGraphData(graph, emit);
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
      // 读操作：通过 Repository 加载节点
      final nodeIds = graph.nodeIds;
      final nodes = await _nodeRepository.loadAll(nodeIds);
      final connections = Connection.calculateConnections(nodes);

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
      // 这里我们假设需要基于节点的位置来计算相机位置
      // 具体实现取决于 Flame 引擎的坐标系统
      final nodePosition =
          state.graph.nodePositions[event.nodeId] ?? targetNode.position;

      // 更新相机位置到节点位置
      final updatedConfig = state.graph.viewConfig.copyWith(
        camera: Camera(
          x: nodePosition.dx,
          y: nodePosition.dy,
          zoom: state.viewState.camera.zoom,
        ),
      );

      // 写操作：通过 CommandBus
      final command = UpdateGraphCommand(
        graphId: state.graph.id,
        viewConfig: updatedConfig,
      );
      final result = await _commandBus.dispatch(command);

      if (!result.isSuccess) {
        throw Exception(result.error);
      }

      final updatedGraph = result.data!;

      emit(
        state.copyWith(
          graph: updatedGraph,
          viewState: state.viewState.copyWith(
            camera: state.viewState.camera.copyWith(position: nodePosition),
          ),
        ),
      );
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
  /// - 只处理 UI 状态更新，不包含业务逻辑
  void _handleNodeDataChanged(NodeDataChangedEvent event) {
    if (state.graph.id.isEmpty) return;

    final graphNodeIds = state.graph.nodeIds.toSet();
    List<Node> updatedNodes;
    List<Connection> updatedConnections;

    switch (event.action) {
      case DataChangeAction.delete:
        // 从图中移除已删除的节点
        final deletedNodeIds = event.changedNodes.map((n) => n.id).toSet();
        updatedNodes = state.nodes.where((n) => !deletedNodeIds.contains(n.id)).toList();
        updatedConnections = Connection.calculateConnections(updatedNodes);
        break;

      case DataChangeAction.update:
      case DataChangeAction.create:
        // 更新当前图中的节点数据
        final affectedNodes = event.changedNodes
            .where((n) => graphNodeIds.contains(n.id))
            .toList();

        if (affectedNodes.isEmpty) return;

        // 替换逻辑：移除旧版本，添加新版本
        final affectedNodeIds = affectedNodes.map((n) => n.id).toSet();
        updatedNodes = [
          ...state.nodes.where((n) => !affectedNodeIds.contains(n.id)),
          ...affectedNodes,
        ];
        updatedConnections = Connection.calculateConnections(updatedNodes);
        break;
    }

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
