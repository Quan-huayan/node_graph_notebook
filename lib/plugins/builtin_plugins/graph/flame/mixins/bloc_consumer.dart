import 'dart:async';
import 'package:flame/components.dart' hide Timer;
import 'package:flutter/material.dart';
import '../../bloc/graph_bloc.dart';
import '../../bloc/graph_event.dart';
import '../../bloc/graph_state.dart';

/// Flame 组件的 BLoC 消费者混入
/// 允许 Flame 组件订阅和消费 BLoC 状态变化
mixin BlocConsumerMixin<T> on Component {
  /// 获取 BLoC 实例
  /// 子类必须实现此 getter
  GraphBloc get graphBloc;

  StreamSubscription<GraphState>? _stateSubscription;
  GraphState? _previousState;

  /// 订阅状态变化
  ///
  /// [onnewStateState] - 新状态回调
  /// [shouldUpdate] - 判断是否需要更新的条件函数
  /// [listenImmediately] - 是否立即订阅当前状态（默认 true）
  void subscribeToState({
    void Function(GraphState state)? onnewStateState,
    bool Function(GraphState oldState, GraphState newState)? shouldUpdate,
    bool listenImmediately = true,
  }) {
    // 取消之前的订阅
    _stateSubscription?.cancel();

    // 立即处理当前状态
    if (listenImmediately) {
      _previousState = graphBloc.state;
      onnewStateState?.call(graphBloc.state);
    }

    _stateSubscription = graphBloc.stream.listen((newStateState) {
      // 检查是否需要更新
      final needsUpdate = shouldUpdate?.call(_previousState!, newStateState) ?? true;

      if (needsUpdate && onnewStateState != null) {
        onnewStateState(newStateState);
      }
      _previousState = newStateState;
    });
  }

  /// 订阅特定节点的位置变化
  ///
  /// [nodeId] - 节点 ID
  /// [onPositionChanged] - 位置变化回调
  void subscribeToNodePosition(
    String nodeId, {
    void Function(Offset position)? onPositionChanged,
  }) {
    subscribeToState(
      onnewStateState: (state) {
        final position = state.getNodePosition(nodeId);
        if (position != null) {
          onPositionChanged?.call(position);
        }
      },
      shouldUpdate: (oldState, newState) {
        // 检查位置是否真的变化了
        final oldPosition = oldState.getNodePosition(nodeId);
        final newStatePosition = newState.getNodePosition(nodeId);

        if (oldPosition == null && newStatePosition == null) return false;
        if (oldPosition == null || newStatePosition == null) return true;

        return oldPosition != newStatePosition;
      },
    );
  }

  /// 订阅选择状态变化
  ///
  /// [onSelectionChanged] - 选择变化回调
  void subscribeToSelection({
    void Function(Set<String> selectedIds)? onSelectionChanged,
  }) {
    subscribeToState(
      onnewStateState: (state) {
        onSelectionChanged?.call(state.selectedNodeIds);
      },
      shouldUpdate: (oldState, newState) {
        return oldState.selectedNodeIds != newState.selectedNodeIds;
      },
    );
  }

  /// 订阅连接变化
  ///
  /// [onConnectionsChanged] - 连接变化回调
  void subscribeToConnections({
    void Function(List<dynamic> connections)? onConnectionsChanged,
  }) {
    subscribeToState(
      onnewStateState: (state) {
        onConnectionsChanged?.call(state.connections);
      },
      shouldUpdate: (oldState, newState) {
        // 简单比较：检查连接列表是否不同
        if (oldState.connections.length != newState.connections.length) {
          return true;
        }

        // 检查连接是否相同
        for (int i = 0; i < oldState.connections.length; i++) {
          if (oldState.connections[i] != newState.connections[i]) {
            return true;
          }
        }

        return false;
      },
    );
  }

  /// 订阅节点列表变化
  ///
  /// [onNodesChanged] - 节点变化回调
  void subscribeToNodes({
    void Function(List<dynamic> nodes)? onNodesChanged,
  }) {
    subscribeToState(
      onnewStateState: (state) {
        onNodesChanged?.call(state.nodes);
      },
      shouldUpdate: (oldState, newState) {
        // 简单比较：检查节点列表是否不同
        if (oldState.nodes.length != newState.nodes.length) {
          return true;
        }

        // 检查节点是否相同
        for (int i = 0; i < oldState.nodes.length; i++) {
          if (oldState.nodes[i].id != newState.nodes[i].id) {
            return true;
          }
        }

        return false;
      },
    );
  }

  /// 订阅视图状态变化
  ///
  /// [onViewStateChanged] - 视图状态变化回调
  void subscribeToViewState({
    void Function(double zoomLevel, bool showConnections)? onViewStateChanged,
  }) {
    subscribeToState(
      onnewStateState: (state) {
        onViewStateChanged?.call(
          state.viewState.zoomLevel,
          state.viewState.showConnections,
        );
      },
      shouldUpdate: (oldState, newState) {
        return oldState.viewState != newState.viewState;
      },
    );
  }

  /// 分发事件到 BLoC
  void dispatchEvent(GraphEvent event) {
    graphBloc.add(event);
  }

  /// 获取当前状态
  GraphState get currentState => graphBloc.state;

  /// 取消订阅
  void unsubscribe() {
    _stateSubscription?.cancel();
    _stateSubscription = null;
    _previousState = null;
  }

  @override
  void onRemove() {
    unsubscribe();
    super.onRemove();
  }
}

/// BLoC 事件防抖混入
/// 用于频繁触发的事件（如拖拽）
mixin BlocDebounceMixin {
  final Map<String, Timer> _timers = {};

  /// 防抖执行
  ///
  /// [key] - 防抖键（不同的操作使用不同的键）
  /// [duration] - 防抖延迟时间
  /// [callback] - 要执行的回调
  void debounce(
    String key,
    Duration duration,
    VoidCallback callback,
  ) {
    // 取消之前的定时器
    _timers[key]?.cancel();

    // 创建新的定时器
    _timers[key] = Timer(duration, callback);
  }

  /// 取消特定键的防抖
  void cancelDebounce(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
  }

  /// 取消所有防抖
  void cancelAllDebounces() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
