import 'dart:async';

import '../utils/logger.dart';

/// Logger for EventSubscriptionManager
const _log = AppLogger('EventSubscriptionManager');

/// 事件订阅管理器
///
/// 自动跟踪和管理 StreamSubscription 的生命周期，防止内存泄漏。
/// 在 BLoC close() 时自动取消所有订阅，无需手动管理每个订阅。
///
/// ## 使用示例
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   late final EventSubscriptionManager _subscriptionManager;
///
///   MyBloc(...) : super(...) {
///     _subscriptionManager = EventSubscriptionManager('MyBloc');
///     _subscribeToEvents();
///   }
///
///   void _subscribeToEvents() {
///     _subscriptionManager.track(
///       'NodeDataChanged',
///       eventBus.stream.listen((event) { ... })
///     );
///   }
///
///   @override
///   Future<void> close() {
///     _subscriptionManager.dispose();
///     return super.close();
///   }
/// }
/// ```
class EventSubscriptionManager {
  /// 创建订阅管理器
  ///
  /// [ownerId] 所有者标识，用于调试和日志记录（通常是类名）
  EventSubscriptionManager(this.ownerId) : assert(ownerId.isNotEmpty);

  /// 所有者标识（用于调试）
  final String ownerId;

  /// 跟踪的订阅映射表
  ///
  /// Key: 订阅标识符，Value: StreamSubscription 对象
  final Map<String, StreamSubscription> _subscriptions = {};

  /// 跟踪并管理订阅
  ///
  /// 如果该 key 已存在订阅，会先取消旧订阅再添加新订阅（防止重复订阅）。
  ///
  /// [key] 订阅的唯一标识符（建议使用 'ClassName.eventType' 格式）
  /// [subscription] 要跟踪的 StreamSubscription 对象
  ///
  /// 返回传入的 subscription，方便链式调用
  StreamSubscription<T> track<T>(
    String key,
    StreamSubscription<T> subscription,
  ) {
    assert(key.isNotEmpty, 'Subscription key cannot be empty');

    // 如果该 key 已有订阅，先取消旧订阅
    _subscriptions[key]?.cancel();

    // 跟踪新订阅
    _subscriptions[key] = subscription as StreamSubscription;

    // 添加错误处理器，防止订阅错误导致内存泄漏
    subscription.onError((error, stackTrace) {
      _log.error(
        '[$ownerId] Subscription error on "$key": $error\n$stackTrace',
      );
    });

    return subscription;
  }

  /// 取消指定订阅
  ///
  /// 如果订阅不存在，静默处理。
  void cancel(String key) {
    final subscription = _subscriptions.remove(key);
    subscription?.cancel();
  }

  /// 检查是否存在指定订阅
  bool has(String key) => _subscriptions.containsKey(key);

  /// 获取当前跟踪的订阅数量
  int get count => _subscriptions.length;

  /// 获取所有订阅的 key 列表
  List<String> get keys => _subscriptions.keys.toList();

  /// 释放所有订阅
  ///
  /// 取消所有跟踪的订阅并清空映射表。
  /// 通常在 BLoC 的 close() 方法中调用。
  ///
  /// **重要**: dispose() 后不能再次使用此管理器。
  void dispose() {
    for (final entry in _subscriptions.entries) {
      try {
        entry.value.cancel();
      } catch (e, stackTrace) {
        // 记录但继续清理其他订阅
        _log.warning(
          '[$ownerId] Error canceling subscription "${entry.key}": $e\n$stackTrace',
        );
      }
    }
    _subscriptions.clear();
  }

  @override
  String toString() => 'EventSubscriptionManager(ownerId: $ownerId, subscriptions: ${_subscriptions.keys.join(", ")})';
}
