# BLoC 集成设计文档

## 1. 概述

### 1.1 职责
BLoC 集成层负责将现有的 BLoC 架构与新的 Command/Query 系统集成，实现：
- BLoC Event 到 Command 的转换
- Query 结果到 BLoC State 的映射
- BLoC 与新系统的双向通信
- 保持现有 BLoC API 不变

### 1.2 目标
- **兼容性**: 现有 BLoC 代码无需修改
- **渐进式**: 逐步迁移 BLoC 到新架构
- **类型安全**: 保持强类型检查
- **可测试性**: 易于单元测试
- **性能**: 最小化集成开销

### 1.3 关键挑战
- **Event 映射**: BLoC Event 到 Command 的正确映射
- **State 同步**: 新系统状态变化到 BLoC State 的同步
- **错误处理**: 新旧错误格式的转换
- **生命周期**: BLoC 与新系统的生命周期协调
- **测试隔离**: 测试时正确模拟新系统

## 2. 架构设计

### 2.1 组件结构

```
BlocIntegrationLayer
    │
    ├── CommandBlocAdapter (Command BLoC 适配器)
    │   ├── eventToCommand() (事件转命令)
    │   ├── commandToState() (命令转状态)
    │   └── handleEvent() (处理事件)
    │
    ├── QueryBlocAdapter (Query BLoC 适配器)
    │   ├── eventToQuery() (事件转查询)
    │   ├── queryToState() (查询转状态)
    │   └── handleEvent() (处理事件)
    │
    ├── BlocEventHandler (BLoC 事件处理器)
    │   ├── handleCommand() (处理命令事件)
    │   └── handleQuery() (处理查询事件)
    │
    └── StateMapper (状态映射器)
        ├── mapCommandResult() (映射命令结果)
        └── mapQueryResult() (映射查询结果)
```

### 2.2 接口定义

#### BLoC 适配器基类

```dart
/// BLoC 适配器基类
abstract class BlocAdapter<TEvent extends BlocEvent, TState extends BlocState> {
  /// Command Bus
  final ICommandBus commandBus;

  /// Query Bus
  final IQueryBus queryBus;

  /// 状态映射器
  final StateMapper stateMapper;

  BlocAdapter({
    required this.commandBus,
    required this.queryBus,
    required this.stateMapper,
  });

  /// 处理 BLoC Event
  Future<TState?> handleEvent(TEvent event, TState currentState);

  /// 将 Event 转换为 Command（可选）
  Command? eventToCommand(TEvent event, TState state) => null;

  /// 将 Event 转换为 Query（可选）
  Query? eventToQuery(TEvent event, TState state) => null;

  /// 映射 Command 结果到 State
  TState mapCommandResult(
    CommandResult result,
    TState state,
    TEvent event,
  );

  /// 映射 Query 结果到 State
  TState mapQueryResult(
    QueryResult result,
    TState state,
    TEvent event,
  );
}
```

#### NodeBloc 适配器

```dart
/// NodeBloc 适配器
class NodeBlocAdapter extends BlocAdapter<NodeEvent, NodeState> {
  NodeBlocAdapter({
    required super.commandBus,
    required super.queryBus,
    required super.stateMapper,
  });

  @override
  Future<NodeState?> handleEvent(
    NodeEvent event,
    NodeState state,
  ) async {
    // 尝试转换为 Command
    final command = eventToCommand(event, state);
    if (command != null) {
      final result = await commandBus.execute(command);
      return mapCommandResult(result, state, event);
    }

    // 尝试转换为 Query
    final query = eventToQuery(event, state);
    if (query != null) {
      final result = await queryBus.execute(query);
      return mapQueryResult(result, state, event);
    }

    // 无法处理，返回 null 让原 BLoC 处理
    return null;
  }

  @override
  Command? eventToCommand(NodeEvent event, NodeState state) {
    switch (event) {
      case CreateNodeEvent():
        return CreateNodeCommand(
          id: event.id,
          type: event.type,
          content: event.content,
          parentId: event.parentId,
        );

      case UpdateNodeEvent():
        return UpdateNodeCommand(
          id: event.id,
          content: event.content,
          position: event.position,
          size: event.size,
        );

      case DeleteNodeEvent():
        return DeleteNodeCommand(nodeId: event.id);

      default:
        return null;
    }
  }

  @override
  Query? eventToQuery(NodeEvent event, NodeState state) {
    switch (event) {
      case LoadNodeEvent():
        return GetNodeQuery(nodeId: event.id);

      case LoadNodesEvent():
        return GetNodesQuery(nodeIds: event.ids);

      case SearchNodesEvent():
        return SearchNodesQuery(
          keyword: event.keyword,
          nodeTypes: event.types,
          tags: event.tags,
          limit: event.limit,
        );

      default:
        return null;
    }
  }

  @override
  NodeState mapCommandResult(
    CommandResult result,
    NodeState state,
    NodeEvent event,
  ) {
    if (!result.isSuccess) {
      return state.copyWith(
        status: NodeStatus.error,
        error: result.error,
      );
    }

    switch (event) {
      case CreateNodeEvent():
        final node = result.data as Node;
        final updatedNodes = Map<String, Node>.from(state.nodes);
        updatedNodes[node.id] = node;
        return state.copyWith(
          nodes: updatedNodes,
          status: NodeStatus.loaded,
        );

      case UpdateNodeEvent():
        final node = result.data as Node;
        final updatedNodes = Map<String, Node>.from(state.nodes);
        updatedNodes[node.id] = node;
        return state.copyWith(
          nodes: updatedNodes,
          status: NodeStatus.loaded,
        );

      case DeleteNodeEvent():
        final updatedNodes = Map<String, Node>.from(state.nodes);
        updatedNodes.remove(event.id);
        return state.copyWith(
          nodes: updatedNodes,
          status: NodeStatus.loaded,
        );

      default:
        return state;
    }
  }

  @override
  NodeState mapQueryResult(
    QueryResult result,
    NodeState state,
    NodeEvent event,
  ) {
    if (!result.isSuccess) {
      return state.copyWith(
        status: NodeStatus.error,
        error: result.error,
      );
    }

    switch (event) {
      case LoadNodeEvent():
        final node = result.data as Node?;
        if (node != null) {
          final updatedNodes = Map<String, Node>.from(state.nodes);
          updatedNodes[node.id] = node;
          return state.copyWith(
            nodes: updatedNodes,
            status: NodeStatus.loaded,
          );
        }
        return state.copyWith(
          status: NodeStatus.error,
          error: '节点不存在',
        );

      case LoadNodesEvent():
        final nodes = result.data as List<Node>;
        final updatedNodes = Map<String, Node>.from(state.nodes);
        for (final node in nodes) {
          updatedNodes[node.id] = node;
        }
        return state.copyWith(
          nodes: updatedNodes,
          status: NodeStatus.loaded,
        );

      case SearchNodesEvent():
        final nodes = result.data as List<Node>;
        return state.copyWith(
          searchResults: nodes,
          status: NodeStatus.loaded,
        );

      default:
        return state;
    }
  }
}
```

#### GraphBloc 适配器

```dart
/// GraphBloc 适配器
class GraphBlocAdapter extends BlocAdapter<GraphEvent, GraphState> {
  GraphBlocAdapter({
    required super.commandBus,
    required super.queryBus,
    required super.stateMapper,
  });

  @override
  Future<GraphState?> handleEvent(
    GraphEvent event,
    GraphState state,
  ) async {
    final command = eventToCommand(event, state);
    if (command != null) {
      final result = await commandBus.execute(command);
      return mapCommandResult(result, state, event);
    }

    final query = eventToQuery(event, state);
    if (query != null) {
      final result = await queryBus.execute(query);
      return mapQueryResult(result, state, event);
    }

    return null;
  }

  @override
  Command? eventToCommand(GraphEvent event, GraphState state) {
    switch (event) {
      case AddNodeToGraphEvent():
        return AddNodeToGraphCommand(
          graphId: event.graphId,
          nodeId: event.nodeId,
        );

      case RemoveNodeFromGraphEvent():
        return RemoveNodeFromGraphCommand(
          graphId: event.graphId,
          nodeId: event.nodeId,
        );

      case CreateConnectionEvent():
        return CreateConnectionCommand(
          sourceId: event.sourceId,
          targetId: event.targetId,
          graphId: event.graphId,
          type: event.type,
        );

      case DeleteConnectionEvent():
        return DeleteConnectionCommand(connectionId: event.connectionId);

      default:
        return null;
    }
  }

  @override
  Query? eventToQuery(GraphEvent event, GraphState state) {
    switch (event) {
      case LoadGraphEvent():
        return GetGraphQuery(graphId: event.graphId);

      case LoadGraphNodesEvent():
        return GetGraphNodesQuery(graphId: event.graphId);

      default:
        return null;
    }
  }

  @override
  GraphState mapCommandResult(
    CommandResult result,
    GraphState state,
    GraphEvent event,
  ) {
    if (!result.isSuccess) {
      return state.copyWith(
        status: GraphStatus.error,
        error: result.error,
      );
    }

    switch (event) {
      case AddNodeToGraphEvent():
        final updatedNodes = List<String>.from(state.nodeIds);
        updatedNodes.add(event.nodeId);
        return state.copyWith(
          nodeIds: updatedNodes,
          status: GraphStatus.loaded,
        );

      case RemoveNodeFromGraphEvent():
        final updatedNodes = List<String>.from(state.nodeIds);
        updatedNodes.remove(event.nodeId);
        return state.copyWith(
          nodeIds: updatedNodes,
          status: GraphStatus.loaded,
        );

      case CreateConnectionEvent():
        final connection = result.data as Connection;
        final updatedConnections = Map<String, Connection>.from(
          state.connections,
        );
        updatedConnections[connection.id] = connection;
        return state.copyWith(
          connections: updatedConnections,
          status: GraphStatus.loaded,
        );

      case DeleteConnectionEvent():
        final updatedConnections = Map<String, Connection>.from(
          state.connections,
        );
        updatedConnections.remove(event.connectionId);
        return state.copyWith(
          connections: updatedConnections,
          status: GraphStatus.loaded,
        );

      default:
        return state;
    }
  }

  @override
  GraphState mapQueryResult(
    QueryResult result,
    GraphState state,
    GraphEvent event,
  ) {
    if (!result.isSuccess) {
      return state.copyWith(
        status: GraphStatus.error,
        error: result.error,
      );
    }

    switch (event) {
      case LoadGraphEvent():
        final graph = result.data as Graph;
        return state.copyWith(
          currentGraph: graph,
          status: GraphStatus.loaded,
        );

      case LoadGraphNodesEvent():
        final nodeIds = result.data as List<String>;
        return state.copyWith(
          nodeIds: nodeIds,
          status: GraphStatus.loaded,
        );

      default:
        return state;
    }
  }
}
```

### 2.3 BLoC 事件处理器

```dart
/// BLoC 事件处理器
class BlocEventHandler {
  final Map<Type, BlocAdapter> _adapters;

  BlocEventHandler({required List<BlocAdapter> adapters})
      : _adapters = {
          for (final adapter in adapters)
            adapter.runtimeType: adapter,
        };

  /// 处理 BLoC Event
  Future<TState?> handleEvent<TEvent extends BlocEvent, TState extends BlocState>(
    TEvent event,
    TState state,
    BlocBase<TState> bloc,
  ) async {
    // 查找对应的适配器
    final adapter = _adapters[bloc.runtimeType];
    if (adapter == null) {
      return null;
    }

    // 使用适配器处理事件
    return await adapter.handleEvent(event, state);
  }

  /// 注册适配器
  void registerAdapter<TBloc extends BlocBase>(
    BlocAdapter adapter,
  ) {
    _adapters[adapter.runtimeType] = adapter;
  }
}
```

### 2.4 增强的 BLoC 基类

```dart
/// 增强的 BLoC 基类，支持 Command/Query 集成
abstract class EnhancedBloc<TEvent extends BlocEvent, TState extends BlocState>
    extends Bloc<TEvent, TState> {
  /// Command Bus
  final ICommandBus commandBus;

  /// Query Bus
  final IQueryBus queryBus;

  /// BLoC 事件处理器
  final BlocEventHandler eventHandler;

  /// 是否启用 Command/Query 集成
  final bool enableCQRSIntegration;

  EnhancedBloc(
    TState initialState, {
    required this.commandBus,
    required this.queryBus,
    required this.eventHandler,
    this.enableCQRSIntegration = false,
  }) : super(initialState) {
    // 注册适配器
    _registerAdapters();
  }

  @override
  void onEvent(TEvent event) {
    if (enableCQRSIntegration) {
      // 尝试使用 Command/Query 处理
      eventHandler
          .handleEvent<TEvent, TState>(event, state, this)
          .then((newState) {
        if (newState != null) {
          emit(newState);
        } else {
          // 无法处理，使用原有逻辑
          handleEventFallback(event);
        }
      });
    } else {
      // 使用原有逻辑
      handleEventFallback(event);
    }
  }

  /// 注册适配器（子类实现）
  void _registerAdapters();

  /// 降级处理逻辑（原 BLoC 逻辑）
  void handleEventFallback(TEvent event) {
    // 子类实现
  }
}
```

## 3. 集成策略

### 3.1 渐进式集成

```dart
/// NodeBloc 实现
class NodeBloc extends EnhancedBloc<NodeEvent, NodeState> {
  NodeBloc({
    required ICommandBus commandBus,
    required IQueryBus queryBus,
    required BlocEventHandler eventHandler,
    NodeState? initialState,
  }) : super(
          initialState ?? NodeState.initial(),
          commandBus: commandBus,
          queryBus: queryBus,
          eventHandler: eventHandler,
        );

  @override
  void _registerAdapters() {
    // 注册 NodeBloc 适配器
    eventHandler.registerAdapter<NodeBloc>(
      NodeBlocAdapter(
        commandBus: commandBus,
        queryBus: queryBus,
        stateMapper: StateMapper(),
      ),
    );
  }

  @override
  void handleEventFallback(NodeEvent event) {
    // 原有 BLoC 逻辑
    switch (event) {
      case LoadNodeEvent():
        _handleLoadNode(event);
        break;
      // ... 其他事件
    }
  }

  void _handleLoadNode(LoadNodeEvent event) async {
    emit(state.copyWith(status: NodeStatus.loading));

    try {
      // 直接使用 Repository（原有方式）
      final node = await nodeRepository.getNode(event.id);

      if (node != null) {
        emit(state.copyWith(
          nodes: {...state.nodes, node.id: node},
          status: NodeStatus.loaded,
        ));
      } else {
        emit(state.copyWith(
          status: NodeStatus.error,
          error: '节点不存在',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: NodeStatus.error,
        error: e.toString(),
      ));
    }
  }
}
```

### 3.2 状态映射器

```dart
/// 状态映射器
class StateMapper {
  /// 映射 Command 结果
  TState mapCommandResult<TState extends BlocState>(
    CommandResult result,
    TState state,
    BlocEvent event,
  ) {
    if (result.isSuccess) {
      return _mapSuccessResult(result, state, event);
    } else {
      return _mapErrorResult(result, state);
    }
  }

  /// 映射 Query 结果
  TState mapQueryResult<TState extends BlocState>(
    QueryResult result,
    TState state,
    BlocEvent event,
  ) {
    if (result.isSuccess) {
      return _mapSuccessResult(result, state, event);
    } else {
      return _mapErrorResult(result, state);
    }
  }

  TState _mapSuccessResult<TState extends BlocState>(
    dynamic result,
    TState state,
    BlocEvent event,
  ) {
    // 子类实现具体映射逻辑
    return state;
  }

  TState _mapErrorResult<TState extends BlocState>(
    dynamic result,
    TState state,
  ) {
    // 通用错误映射
    if (state is NodeState) {
      return (state as NodeState).copyWith(
        status: NodeStatus.error,
        error: result.error ?? '未知错误',
      ) as TState;
    }

    if (state is GraphState) {
      return (state as GraphState).copyWith(
        status: GraphStatus.error,
        error: result.error ?? '未知错误',
      ) as TState;
    }

    return state;
  }
}
```

## 4. 性能考虑

### 4.1 概念性性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 事件处理延迟 | < 5ms | 从事件到状态更新的延迟 |
| 适配器开销 | < 0.5ms | 适配器层的处理开销 |
| 状态映射时间 | < 0.1ms | 结果映射到状态的时间 |

### 4.2 优化策略

1. **并行处理**:
   - 独立的 Command 可以并行执行
   - 使用 `Future.wait` 并行处理

2. **缓存映射结果**:
   - 缓存状态映射结果
   - 避免重复计算

3. **批量处理**:
   - 批量处理多个事件
   - 减少状态更新次数

## 5. 关键文件清单

```
lib/core/migration/bloc/
├── adapters/
│   ├── bloc_adapter.dart          # BLoC 适配器基类
│   ├── node_bloc_adapter.dart     # NodeBloc 适配器
│   ├── graph_bloc_adapter.dart    # GraphBloc 适配器
│   ├── search_bloc_adapter.dart   # SearchBloc 适配器
│   └── converter_bloc_adapter.dart # ConverterBloc 适配器
├── handlers/
│   ├── bloc_event_handler.dart    # BLoC 事件处理器
│   └── state_mapper.dart          # 状态映射器
└── base/
    └── enhanced_bloc.dart         # 增强的 BLoC 基类
```

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
