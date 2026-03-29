import 'dart:async';
import 'package:equatable/equatable.dart';

import '../models/models.dart';
import '../utils/logger.dart';

/// Logger for AppEventBus
const _log = AppLogger('AppEventBus');

/// 应用事件总线 - 用于跨 BLoC 通信
///
/// 采用单例模式，提供广播流机制实现发布-订阅模式。
/// 用于 NodeBloc 和 GraphBloc 之间的解耦通信。
///
/// ## 错误处理
///
/// 通过 [onError] 回调可以自定义错误处理逻辑。默认情况下，
/// 错误会通过 AppLogger 输出到控制台。
///
/// ## 使用示例
/// ```dart
/// // 发布事件
/// AppEventBus().publish(NodeDataChangedEvent(...));
///
/// // 订阅事件
/// AppEventBus().stream.listen((event) {
///   if (event is NodeDataChangedEvent) { ... }
/// });
///
/// // 自定义错误处理
/// AppEventBus().onError = (event, error, stackTrace) {
///   Sentry.captureException(error, stackTrace: stackTrace);
/// };
/// ```
class AppEventBus {

  /// 获取事件总线实例（单例）
  factory AppEventBus() => _instance;
  // 私有构造函数，实现单例模式
  AppEventBus._internal();

  /// 创建用于测试的新实例
  ///
  /// 注意：此方法仅用于测试，会创建新的事件总线实例而不是使用单例。
  /// 测试完成后需要调用 dispose() 释放资源。
  factory AppEventBus.createForTest() => AppEventBus._internal();

  /// 单例实例
  static final AppEventBus _instance = AppEventBus._internal();

  /// 广播流控制器，支持多个订阅者
  final _controller = StreamController<AppEvent>.broadcast();

  /// 事件流，供 BLoC 订阅
  Stream<AppEvent> get stream => _controller.stream;

  /// 自定义错误处理器
  ///
  /// 当事件发布或订阅过程中发生错误时调用。
  ///
  /// 参数：
  /// - `event` - 正在发布的事件（可能为 null，如果是流控制器错误）
  /// - `error` - 错误对象
  /// - `stackTrace` - 堆栈跟踪
  ///
  /// 如果为 null，使用默认处理器（通过 AppLogger 输出）
  void Function(AppEvent? event, Object error, StackTrace stackTrace)? onError;

  /// 发布事件到总线
  ///
  /// 所有订阅者都会收到此事件。
  ///
  /// 如果事件总线已关闭或发布失败，会调用 [onError] 回调（如果设置了）。
  /// 如果 [onError] 未设置，会通过 AppLogger 输出错误信息。
  ///
  /// [event] 要发布的事件
  void publish(AppEvent event) {
    try {
      if (_controller.isClosed) {
        final error = StateError('Cannot publish event: EventBus is closed');
        _handleError(event, error, StackTrace.current);
        return;
      }
      _controller.add(event);
    } catch (e, stackTrace) {
      _handleError(event, e, stackTrace);
    }
  }

  /// 处理错误
  void _handleError(AppEvent? event, Object error, StackTrace stackTrace) {
    if (onError != null) {
      onError!.call(event, error, stackTrace);
    } else {
      // 默认错误处理：输出到控制台
      _log.error(
        '[AppEventBus] Error publishing ${event?.runtimeType ?? "event"}: $error\n'
        'Stack trace:\n$stackTrace',
      );
    }
  }

  /// 释放资源
  ///
  /// 通常在应用关闭时调用。一旦关闭，不能再发布事件。
  void dispose() {
    _controller.close();
  }
}

/// 应用事件基类
///
/// 所有通过事件总线传递的事件都必须继承此类。
/// 使用 Equatable 实现值相等性比较，便于测试和状态比较。
abstract class AppEvent extends Equatable {
  /// 创建一个应用事件
  const AppEvent();

  @override
  List<Object?> get props => [];
}

/// 节点数据变化事件
///
/// 当节点的数据发生变化时（创建、更新、删除），NodeBloc 会发布此事件。
/// GraphBloc 订阅此事件以更新视图层的节点数据。
class NodeDataChangedEvent extends AppEvent {
  /// 创建一个节点数据变化事件
  ///
  /// [changedNodes] - 发生变化的节点列表
  /// [action] - 变化类型，默认为更新
  const NodeDataChangedEvent({
    required this.changedNodes,
    this.action = DataChangeAction.update,
  });

  /// 发生变化的节点列表
  final List<Node> changedNodes;

  /// 变化类型
  final DataChangeAction action;

  @override
  List<Object?> get props => [changedNodes, action];
}

/// 数据变化类型
///
/// 定义节点数据可能的变化类型，便于订阅者根据类型执行不同的处理逻辑。
enum DataChangeAction {
  /// 创建新节点
  create,

  /// 更新现有节点
  update,

  /// 删除节点
  delete,
}

/// 图节点关系变化事件
///
/// 当节点与图的关系发生变化时（添加到图、从图移除），GraphBloc 会发布此事件。
/// 其他 BLoC 或组件可以订阅此事件以响应图结构变化。
class GraphNodeRelationChangedEvent extends AppEvent {
  /// 创建一个图节点关系变化事件
  ///
  /// [graphId] - 发生变化的图 ID
  /// [nodeIds] - 涉及的节点 ID 列表
  /// [action] - 变化类型
  const GraphNodeRelationChangedEvent({
    required this.graphId,
    required this.nodeIds,
    required this.action,
  });

  /// 发生变化的图 ID
  final String graphId;

  /// 涉及的节点 ID 列表
  final List<String> nodeIds;

  /// 变化类型
  final RelationChangeAction action;

  @override
  List<Object?> get props => [graphId, nodeIds, action];
}

/// 图节点关系变化类型
enum RelationChangeAction {
  /// 节点被添加到图
  addedToGraph,

  /// 节点从图中移除
  removedFromGraph,
}
