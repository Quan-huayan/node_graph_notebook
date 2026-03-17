# 事件系统重构建议

## 一、当前事件系统架构概述

当前系统包含四个层次的事件机制：

### 1. 全局事件总线
- **文件位置**: [lib/core/events/app_events.dart](lib/core/events/app_events.dart)
- **特点**: 单例模式，使用广播流（broadcast stream）
- **用途**: 用于跨 BLoC 通信，实现 NodeBloc 和 GraphBloc 之间的解耦

### 2. BLoC 事件系统
- **GraphEvent**: [lib/plugins/graph/bloc/graph_event.dart](lib/plugins/graph/bloc/graph_event.dart)
  - 图操作事件（创建、加载、切换、重命名）
  - 节点视图操作事件（添加、移动、移出）
  - 选择事件（单选、多选、清除选择）
  - 视图操作事件（缩放、移动、切换显示）
  - 布局事件
  - 批量操作事件
  - 撤销/重做事件

- **NodeEvent**: [lib/plugins/graph/bloc/node_event.dart](lib/plugins/graph/bloc/node_event.dart)
  - 节点 CRUD 操作事件
  - 节点连接事件
  - 内部同步事件（NodeDataChangedInternalEvent）

- **UIEvent**: [lib/ui/bloc/ui_event.dart](lib/ui/bloc/ui_event.dart)
  - 节点显示模式事件
  - 连接线显示事件
  - 背景样式事件
  - 侧边栏事件
  - 标签页事件

### 3. 命令总线事件
- **文件位置**: [lib/core/commands/command_bus.dart](lib/core/commands/command_bus.dart)
- **事件类型**:
  - CommandStarted - 命令开始执行
  - CommandSucceeded - 命令执行成功
  - CommandFailed - 命令执行失败
  - CommandUndone - 命令撤销成功
  - CommandUndoFailed - 命令撤销失败

### 4. 插件通信系统
- **文件位置**: [lib/core/plugin/plugin_communication.dart](lib/core/plugin/plugin_communication.dart)
- **特点**: 提供插件间的消息传递机制
- **用途**: 支持插件间通信

## 二、识别出的主要问题

### 问题 1: 事件类型混乱，职责不清

**问题描述**:
- AppEvent、GraphEvent、NodeEvent 之间没有清晰的边界
- NodeDataChangedEvent 既是 AppEvent 又被 NodeBloc 内部使用
- 存在内部事件如 `_NodeSyncedEvent`，绕过了正常的事件系统

**影响**:
- 开发者难以理解何时使用哪种事件类型
- 容易造成事件滥用和混乱

**代码示例**:
```dart
// lib/plugins/graph/bloc/graph_bloc.dart:964
class _NodeSyncedEvent extends GraphEvent {
  const _NodeSyncedEvent({required this.nodes, required this.connections});
  final List<Node> nodes;
  final List<Connection> connections;
}
```

### 问题 2: 订阅管理混乱

**问题描述**:
- GraphBloc 和 NodeBloc 都直接订阅 EventBus
- 订阅逻辑分散在构造函数中，没有统一管理
- BlocConsumerMixin 需要手动取消订阅

**影响**:
- 容易忘记取消订阅，导致内存泄漏
- 难以追踪事件订阅关系

**代码示例**:
```dart
// lib/plugins/graph/bloc/graph_bloc.dart:885
void _subscribeToEvents() {
  _eventBusSubscription = _eventBus.stream.listen((event) {
    if (event is NodeDataChangedEvent) {
      _handleNodeDataChanged(event);
    }
  });
}

// lib/plugins/graph/bloc/node_bloc.dart:49
eventBus.stream.listen((event) {
  if (event is NodeDataChangedEvent) {
    add(NodeDataChangedInternalEvent(...));
  }
});
```

### 问题 3: 事件发布方式不统一

**问题描述**:
- 通过 CommandContext.publishNodeEvent()
- 直接通过 eventBus.publish()
- 通过 CommandBus.commandStream

**影响**:
- 代码风格不一致，难以维护
- 容易遗漏某些发布点

**代码示例**:
```dart
// 方式1：通过 CommandContext
context.publishNodeEvent(nodes, DataChangeAction.create);

// 方式2：直接发布
eventBus.publish(NodeDataChangedEvent(...));

// 方式3：通过 CommandBus
commandBus.commandStream.add(CommandStarted(...));
```

### 问题 4: 事件处理逻辑复杂

**问题描述**:
- GraphBloc._handleNodeDataChanged 方法包含复杂的 switch 逻辑
- 需要判断 action 类型并分别处理
- 使用 add() 而不是 emit() 在 stream 回调中

**影响**:
- 代码难以理解和维护
- 容易引入 bug

**代码示例**:
```dart
// lib/plugins/graph/bloc/graph_bloc.dart:897
void _handleNodeDataChanged(NodeDataChangedEvent event) {
  if (state.graph.id.isEmpty) return;

  final graphNodeIds = state.graph.nodeIds.toSet();

  switch (event.action) {
    case DataChangeAction.delete:
      // 删除逻辑
      break;
    case DataChangeAction.update:
    case DataChangeAction.create:
      // 更新逻辑
      break;
  }
}
```

### 问题 5: 缺乏事件优先级和过滤机制

**问题描述**:
- 所有事件都是平等的，没有优先级
- 无法过滤不需要的事件
- 所有订阅者都会收到所有事件

**影响**:
- 性能问题，不必要的处理
- 难以实现高级功能（如事件优先级、条件订阅）

### 问题 6: 错误处理不足

**问题描述**:
- AppEventBus.publish() 静默处理错误
- 没有错误回调机制
- 订阅者处理错误时可能影响其他订阅者

**影响**:
- 难以调试事件相关的问题
- 错误可能被忽略

**代码示例**:
```dart
// lib/core/events/app_events.dart:34
void publish(AppEvent event) {
  if (!_controller.isClosed) {
    _controller.add(event); // 静默处理错误
  }
}
```

### 问题 7: 测试困难

**问题描述**:
- AppEventBus 使用单例模式
- 需要使用 createForTest() 方法创建测试实例
- 难以模拟事件流

**影响**:
- 测试代码复杂
- 难以隔离测试

**代码示例**:
```dart
// lib/core/events/app_events.dart:20
factory AppEventBus.createForTest() => AppEventBus._internal();
```

### 问题 8: 内存泄漏风险

**问题描述**:
- StreamSubscription 可能没有正确取消
- BlocConsumerMixin 需要手动调用 unsubscribe()
- 没有自动清理机制

**影响**:
- 长期运行可能导致内存泄漏
- 性能下降

**代码示例**:
```dart
// lib/plugins/graph/bloc/graph_bloc.dart:957
@override
Future<void> close() {
  _eventBusSubscription?.cancel(); // 需要手动取消
  return super.close();
}
```

### 问题 9: 事件命名不一致

**问题描述**:
- 有些事件以 Event 结尾（NodeDataChangedEvent）
- 有些没有（LayoutAppliedEvent）
- 命名风格不统一

**影响**:
- 代码可读性差
- 容易混淆

**代码示例**:
```dart
// lib/plugins/layout/event/layout_events.dart:6
class LayoutAppliedEvent extends AppEvent { ... }

// lib/plugins/layout/event/layout_events.dart:35
class NodePositionsChangedEvent extends AppEvent { ... }
```

### 问题 10: 缺乏事件追踪和调试机制

**问题描述**:
- 无法追踪事件的传播路径
- 没有事件日志记录
- 难以调试事件相关的问题

**影响**:
- 开发和调试困难
- 难以优化性能

## 三、重构建议和改进方案

### 3.1 统一事件类型系统

**建议**: 建立清晰的事件类型层次结构

```dart
// 事件类型枚举
enum EventCategory {
  // 数据变更事件 - 跨 BLoC 通信
  dataChange,

  // UI 事件 - 视图层交互
  ui,

  // 业务事件 - 业务逻辑触发
  business,

  // 系统事件 - 系统级通知
  system,
}

// 事件优先级
enum EventPriority {
  low,
  normal,
  high,
  critical,
}

// 增强的事件基类
abstract class AppEvent extends Equatable {
  const AppEvent({
    this.category = EventCategory.dataChange,
    this.priority = EventPriority.normal,
    this.source,
  });

  final EventCategory category;
  final EventPriority priority;
  final String? source; // 事件来源，用于追踪

  @override
  List<Object?> get props => [category, priority, source];
}
```

**好处**:
- 清晰的事件分类
- 支持优先级
- 可追踪事件来源

### 3.2 改进订阅管理机制

**建议**: 引入订阅管理器

```dart
// 订阅管理器
class EventSubscriptionManager {
  final Map<String, List<StreamSubscription>> _subscriptions = {};

  // 订阅事件
  StreamSubscription<T> subscribe<T extends AppEvent>(
    Stream<T> stream,
    void Function(T) handler, {
    String? key,
    EventFilter? filter,
  }) {
    final subscription = stream.where((event) {
      return filter?.accept(event) ?? true;
    }).listen(handler);

    final subscriptionKey = key ?? T.toString();
    _subscriptions.putIfAbsent(subscriptionKey, () => []).add(subscription);

    return subscription;
  }

  // 取消特定订阅
  void unsubscribe(String key) {
    _subscriptions[key]?.forEach((s) => s.cancel());
    _subscriptions.remove(key);
  }

  // 取消所有订阅
  void unsubscribeAll() {
    _subscriptions.values.forEach((list) => list.forEach((s) => s.cancel()));
    _subscriptions.clear();
  }
}

// 事件过滤器
abstract class EventFilter {
  bool accept(AppEvent event);
}

// 示例：只处理特定图的事件
class GraphEventFilter implements EventFilter {
  GraphEventFilter(this.graphId);

  final String graphId;

  @override
  bool accept(AppEvent event) {
    if (event is GraphRelatedEvent) {
      return event.graphId == graphId;
    }
    return false;
  }
}
```

**好处**:
- 统一管理订阅
- 支持事件过滤
- 自动清理订阅

### 3.3 统一事件发布接口

**建议**: 提供统一的事件发布接口

```dart
// 增强的事件总线
class AppEventBus {
  // 单例
  factory AppEventBus() => _instance;
  AppEventBus._internal();
  static final AppEventBus _instance = AppEventBus._internal();

  // 测试用构造函数
  factory AppEventBus.createForTest() => AppEventBus._internal();

  // 事件流
  final _controller = StreamController<AppEvent>.broadcast();
  Stream<AppEvent> get stream => _controller.stream;

  // 分类事件流
  Stream<T> events<T extends AppEvent>() =>
    _controller.stream.whereType<T>();

  // 发布事件
  void publish(AppEvent event) {
    if (_disposed) {
      _logger.warning('EventBus 已释放，无法发布事件: $event');
      return;
    }

    // 记录事件日志
    _logger.info('发布事件: ${event.runtimeType}, 来源: ${event.source}');

    try {
      _controller.add(event);
    } catch (e) {
      _logger.error('发布事件失败: $e');
      if (_errorHandler != null) {
        _errorHandler!(event, e);
      }
    }
  }

  // 错误处理器
  void Function(AppEvent event, Object error)? _errorHandler;
  void setErrorHandler(void Function(AppEvent event, Object error)? handler) {
    _errorHandler = handler;
  }

  // 事件历史记录（用于调试）
  final List<AppEvent> _eventHistory = [];
  List<AppEvent> get eventHistory => List.unmodifiable(_eventHistory);

  bool _disposed = false;
  void dispose() {
    _disposed = true;
    _controller.close();
  }
}
```

**好处**:
- 统一的发布接口
- 支持错误处理
- 提供事件历史记录

### 3.4 简化事件处理逻辑

**建议**: 使用策略模式处理不同类型的事件

```dart
// 事件处理器接口
abstract class EventHandler<T extends AppEvent> {
  bool canHandle(AppEvent event);
  Future<void> handle(T event, Emitter emitter);
}

// 事件处理器注册表
class EventHandlerRegistry {
  final List<EventHandler> _handlers = [];

  void register<T extends AppEvent>(EventHandler<T> handler) {
    _handlers.add(handler);
  }

  Future<void> handle(AppEvent event, Emitter emitter) async {
    for (final handler in _handlers) {
      if (handler.canHandle(event)) {
        await handler.handle(event, emitter);
      }
    }
  }
}

// 示例：节点数据变化处理器
class NodeDataChangedEventHandler implements EventHandler<NodeDataChangedEvent> {
  @override
  bool canHandle(AppEvent event) => event is NodeDataChangedEvent;

  @override
  Future<void> handle(NodeDataChangedEvent event, Emitter emitter) async {
    switch (event.action) {
      case DataChangeAction.delete:
        await _handleDelete(event, emitter);
        break;
      case DataChangeAction.update:
      case DataChangeAction.create:
        await _handleUpdate(event, emitter);
        break;
    }
  }

  Future<void> _handleDelete(NodeDataChangedEvent event, Emitter emitter) async {
    // 删除逻辑
  }

  Future<void> _handleUpdate(NodeDataChangedEvent event, Emitter emitter) async {
    // 更新逻辑
  }
}
```

**好处**:
- 每个处理器职责单一
- 易于扩展
- 易于测试

### 3.5 添加事件优先级和队列机制

**建议**: 实现优先级队列

```dart
// 优先级事件总线
class PriorityEventBus {
  final _queue = PriorityQueue<AppEvent>((a, b) =>
    b.priority.index.compareTo(a.priority.index));

  final _controller = StreamController<AppEvent>.broadcast();

  void publish(AppEvent event) {
    _queue.add(event);
    _processQueue();
  }

  Future<void> _processQueue() async {
    while (_queue.isNotEmpty) {
      final event = _queue.removeFirst();
      _controller.add(event);
      await Future.delayed(Duration.zero); // 让其他任务有机会执行
    }
  }
}
```

**好处**:
- 高优先级事件优先处理
- 避免事件堆积

### 3.6 改进错误处理

**建议**: 添加错误处理机制

```dart
// 事件总线错误处理
class AppEventBus {
  void Function(AppEvent event, Object error, StackTrace)? _errorHandler;

  void setErrorHandler(
    void Function(AppEvent event, Object error, StackTrace)? handler
  ) {
    _errorHandler = handler;
  }

  void publish(AppEvent event) {
    try {
      _controller.add(event);
    } catch (e, stackTrace) {
      _logger.error('发布事件失败: $e', e, stackTrace);
      _errorHandler?.call(event, e, stackTrace);
    }
  }
}

// 订阅者错误隔离
class SafeSubscription {
  SafeSubscription(
    Stream<AppEvent> stream,
    void Function(AppEvent) handler,
  ) {
    _subscription = stream.handleError((e, stackTrace) {
      _logger.error('订阅者处理事件失败: $e', e, stackTrace);
    }).listen(handler);
  }

  late final StreamSubscription _subscription;

  void cancel() => _subscription.cancel();
}
```

**好处**:
- 错误不会影响其他订阅者
- 集中的错误处理
- 便于调试

### 3.7 改进测试支持

**建议**: 提供测试友好的 API

```dart
// 测试用事件总线
class TestEventBus extends AppEventBus {
  final List<AppEvent> _publishedEvents = [];
  final List<AppEvent> _consumedEvents = [];

  @override
  void publish(AppEvent event) {
    _publishedEvents.add(event);
    super.publish(event);
  }

  // 获取发布的事件
  List<AppEvent> get publishedEvents => List.unmodifiable(_publishedEvents);

  // 清除事件历史
  void clearHistory() {
    _publishedEvents.clear();
    _consumedEvents.clear();
  }

  // 等待特定事件
  Future<T> waitForEvent<T extends AppEvent>(
    Duration timeout = const Duration(seconds: 5),
  ) async {
    return stream
        .whereType<T>()
        .first
        .timeout(timeout);
  }
}

// 使用示例
test('should publish node data changed event', () async {
  final eventBus = TestEventBus.createForTest();
  final bloc = NodeBloc(
    commandBus: mockCommandBus,
    nodeRepository: mockRepository,
    eventBus: eventBus,
  );

  await bloc.add(NodeCreateEvent(title: 'Test'));

  final events = eventBus.publishedEvents;
  expect(events, contains(isA<NodeDataChangedEvent>()));
});
```

**好处**:
- 易于测试
- 提供断言方法
- 清除测试隔离

### 3.8 防止内存泄漏

**建议**: 自动清理订阅

```dart
// 自动清理的订阅
class AutoDisposingSubscription {
  AutoDisposingSubscription(
    StreamSubscription subscription,
    DisposeBag disposeBag,
  ) {
    _subscription = subscription;
    disposeBag.add(subscription);
  }

  late final StreamSubscription _subscription;
}

// DisposeBag - 自动管理多个订阅
class DisposeBag {
  final List<StreamSubscription> _subscriptions = [];

  void add(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}

// 在 BLoC 中使用
class GraphBloc extends Bloc<GraphEvent, GraphState> {
  final _disposeBag = DisposeBag();

  GraphBloc(...) : super(...) {
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    AutoDisposingSubscription(
      _eventBus.stream.listen(_handleEvent),
      _disposeBag,
    );
  }

  @override
  Future<void> close() {
    _disposeBag.dispose();
    return super.close();
  }
}
```

**好处**:
- 自动清理订阅
- 防止内存泄漏
- 简化代码

### 3.9 统一事件命名规范

**建议**: 建立命名规范

```dart
// 命名规范：
// 1. 所有事件类以 Event 结尾
// 2. 使用动词+名词的形式
// 3. 清晰表达事件的语义

// 好的命名示例
class NodeCreatedEvent extends AppEvent { ... }
class NodeUpdatedEvent extends AppEvent { ... }
class NodeDeletedEvent extends AppEvent { ... }
class GraphLoadedEvent extends AppEvent { ... }
class ViewZoomedEvent extends AppEvent { ... }

// 不好的命名示例
class NodeDataChangedEvent extends AppEvent { ... } // 太模糊
class LayoutApplied extends AppEvent { ... } // 缺少 Event 后缀
```

### 3.10 添加事件追踪和调试

**建议**: 实现事件追踪系统

```dart
// 事件追踪器
class EventTracer {
  final List<EventTrace> _traces = [];

  void trace(AppEvent event, String from, String to) {
    _traces.add(EventTrace(
      event: event,
      from: from,
      to: to,
      timestamp: DateTime.now(),
    ));
  }

  List<EventTrace> getTracesForEvent(AppEvent event) {
    return _traces.where((t) => t.event == event).toList();
  }

  void printTrace() {
    for (final trace in _traces) {
      print('${trace.timestamp} ${trace.from} -> ${trace.to}: ${trace.event.runtimeType}');
    }
  }
}

class EventTrace {
  final AppEvent event;
  final String from;
  final String to;
  final DateTime timestamp;
}

// 增强的事件总线
class AppEventBus {
  final EventTracer _tracer = EventTracer();

  void publish(AppEvent event, {String? source}) {
    _tracer.trace(event, source ?? 'unknown', 'eventBus');
    _controller.add(event);
  }

  StreamSubscription<T> subscribe<T extends AppEvent>(
    void Function(T) handler, {
    String? subscriber,
  }) {
    return _controller.stream.whereType<T>().listen((event) {
      _tracer.trace(event, 'eventBus', subscriber ?? 'unknown');
      handler(event);
    });
  }
}
```

**好处**:
- 可视化事件流
- 便于调试
- 性能分析

## 四、重构实施建议

### 4.1 渐进式重构策略

**第一阶段**: 添加新功能，不破坏现有代码
- 添加 EventCategory 和 EventPriority
- 添加事件追踪器
- 添加测试支持

**第二阶段**: 重构现有代码
- 统一事件命名
- 引入订阅管理器
- 改进错误处理

**第三阶段**: 清理和优化
- 移除内部事件
- 简化事件处理逻辑
- 添加文档

### 4.2 重构优先级

**高优先级**:
1. 改进错误处理
2. 防止内存泄漏
3. 统一事件命名

**中优先级**:
4. 统一事件发布接口
5. 简化事件处理逻辑
6. 改进测试支持

**低优先级**:
7. 添加事件优先级
8. 添加事件追踪
9. 统一事件类型

### 4.3 风险控制

1. **保持向后兼容**: 新功能不破坏现有代码
2. **充分测试**: 重构前编写测试
3. **逐步迁移**: 一次只重构一个模块
4. **代码审查**: 所有重构代码需要审查

### 4.4 实施步骤

**步骤 1**: 创建新的事件基础设施
- 创建 EventCategory 和 EventPriority 枚举
- 创建 EventSubscriptionManager
- 创建 DisposeBag

**步骤 2**: 增强 AppEventBus
- 添加错误处理
- 添加事件历史记录
- 添加事件追踪器

**步骤 3**: 重构 GraphBloc
- 使用 DisposeBag 管理订阅
- 使用 EventHandlerRegistry 处理事件
- 移除内部事件

**步骤 4**: 重构 NodeBloc
- 使用 DisposeBag 管理订阅
- 统一事件发布方式
- 改进错误处理

**步骤 5**: 更新测试
- 使用 TestEventBus
- 添加事件相关测试
- 验证内存泄漏修复

**步骤 6**: 清理和优化
- 统一事件命名
- 添加文档
- 性能优化

## 五、预期收益

### 5.1 代码质量提升
- 事件类型清晰，职责明确
- 代码可读性和可维护性提高
- 减少代码重复

### 5.2 开发效率提升
- 统一的 API，减少学习成本
- 更好的错误处理，减少调试时间
- 改进的测试支持，提高测试效率

### 5.3 性能提升
- 事件过滤，减少不必要的处理
- 优先级队列，优化事件处理顺序
- 防止内存泄漏，提高长期运行稳定性

### 5.4 可维护性提升
- 清晰的事件追踪，便于调试
- 统一的命名规范，提高代码一致性
- 完善的文档，降低维护成本

## 六、总结

当前事件系统存在10个主要问题，包括事件类型混乱、订阅管理混乱、发布方式不统一、处理逻辑复杂、缺乏优先级和过滤、错误处理不足、测试困难、内存泄漏风险、命名不一致、缺乏追踪调试。

通过实施上述重构建议，可以显著提升代码质量、开发效率、性能和可维护性。建议采用渐进式重构策略，分三个阶段逐步实施，确保重构过程平稳可控。

重构的关键在于保持向后兼容、充分测试、逐步迁移和代码审查，以降低风险并确保重构成功。
