import '../../../models/node.dart';
import '../../../plugin/service_registry.dart';
import '../../../repositories/graph_repository.dart';
import '../../../repositories/node_repository.dart';
import '../command_bus.dart';
import '../events/app_events.dart';

/// 命令执行上下文
///
/// 提供命令执行所需的依赖和服务
/// 采用读写器模式访问各种服务
///
/// 架构说明：
/// - CommandContext 作为命令执行期间的统一服务访问入口
/// - 提供便捷的 getter 方法访问常用仓库和服务
/// - 提供事件发布辅助方法，减少重复代码
/// - 支持元数据传递，用于命令链中的上下文信息共享
/// - 收集的事件将添加到 CommandResult 并由 CommandBus 发布
class CommandContext {
  /// 构造函数
  CommandContext({
    NodeRepository? nodeRepository,
    GraphRepository? graphRepository,
    CommandBus? commandBus,
    Map<Type, dynamic>? additionalServices,
  }) {
    if (nodeRepository != null) {
      _services[NodeRepository] = nodeRepository;
    }
    if (graphRepository != null) {
      _services[GraphRepository] = graphRepository;
    }
    if (additionalServices != null) {
      _services.addAll(additionalServices);
    }
    this.commandBus = commandBus ?? CommandBus();
  }

  /// 服务注册表
  final Map<Type, dynamic> _services = {};

  /// 元数据存储
  final Map<String, dynamic> _metadata = {};

  /// 待发布的事件列表
  ///
  /// 这些事件将在命令执行完成后添加到 CommandResult
  /// CommandBus 会自动将这些事件发布到 eventStream
  final List<AppEvent> _pendingEvents = [];

  /// 命令总线
  ///
  /// 提供对 CommandBus 的访问，用于执行嵌套命令或访问事件流
  late final CommandBus commandBus;

  // === 便捷访问器 ===
  // 说明：为常用的 Repository 和 Service 提供类型安全的 getter 方法
  // 好处：减少代码中的类型转换，提高可读性

  /// 获取节点仓库
  ///
  /// 如果节点仓库未注册，抛出 [ServiceNotFoundException]
  NodeRepository get nodeRepository => read<NodeRepository>();

  /// 获取图仓库
  ///
  /// 如果图仓库未注册，抛出 [ServiceNotFoundException]
  GraphRepository get graphRepository => read<GraphRepository>();

  // === 事件发布辅助方法 ===
  // 说明：为常用的事件发布操作提供便捷方法
  // 好处：统一事件发布逻辑，减少重复代码，便于维护
  //
  // 架构变更：新的事件发布方式
  // - 旧方式：直接通过 eventBus.publish()（同步发布）
  // - 新方式：通过 publishEvent() 收集事件，由 CommandBus 统一发布（解耦）

  /// 发布应用事件
  ///
  /// 将事件添加到待发布列表，命令执行完成后由 CommandBus 统一发布
  /// 这是新的事件发布方式，替代直接调用 eventBus.publish()
  ///
  /// 参数：
  /// - [event] 要发布的应用事件
  ///
  /// 架构说明：
  /// - 事件不会立即发布，而是收集到 _pendingEvents 列表
  /// - CommandBus 在命令执行成功后会自动发布这些事件
  /// - 这样可以确保事件只在命令成功时才发布
  void publishEvent(AppEvent event) {
    _pendingEvents.add(event);
  }

  /// 批量发布应用事件
  ///
  /// 将多个事件添加到待发布列表
  ///
  /// 参数：
  /// - [events] 要发布的应用事件列表
  void publishEvents(List<AppEvent> events) {
    _pendingEvents.addAll(events);
  }

  /// 获取待发布的事件列表
  ///
  /// 此方法由 CommandBus 调用，用于获取命令执行过程中产生的事件
  /// 事件将被添加到 CommandResult 并发布到 eventStream
  List<AppEvent> getPendingEvents() => List.unmodifiable(_pendingEvents);

  /// 清空待发布的事件列表
  ///
  /// 通常在命令执行完成后调用
  void clearPendingEvents() {
    _pendingEvents.clear();
  }

  /// 发布节点数据变化事件（向后兼容方法）
  ///
  /// 当节点数据发生变化时（创建、更新、删除），通过此方法发布事件。
  /// 其他组件（如 BLoC）可以订阅此事件以更新 UI 状态。
  ///
  /// 参数：
  /// - [nodes] 发生变化的节点列表
  /// - [action] 变化类型（创建、更新、删除）
  ///
  /// 架构说明：
  /// 此方法已更新为使用新的事件发布机制
  /// 事件将被收集并在命令执行完成后由 CommandBus 发布
  @Deprecated('Use publishEvent() instead')
  void publishNodeEvent(List<Node> nodes, DataChangeAction action) {
    publishEvent(NodeDataChangedEvent(
      changedNodes: nodes,
      action: action,
    ));
  }

  /// 发布单个节点数据变化事件（向后兼容方法）
  ///
  /// 便捷方法，用于发布单个节点的变化事件
  ///
  /// 参数：
  /// - [node] 发生变化的节点
  /// - [action] 变化类型（创建、更新、删除）
  @Deprecated('Use publishEvent() instead')
  void publishSingleNodeEvent(Node node, DataChangeAction action) {
    publishEvent(NodeDataChangedEvent(
      changedNodes: [node],
      action: action,
    ));
  }

  /// 发布图节点关系变化事件（向后兼容方法）
  ///
  /// 当节点与图的关系发生变化时（添加到图、从图移除），通过此方法发布事件
  ///
  /// 参数：
  /// - [graphId] 发生变化的图 ID
  /// - [nodeIds] 涉及的节点 ID 列表
  /// - [action] 变化类型（添加到图、从图移除）
  @Deprecated('Use publishEvent() instead')
  void publishGraphRelationEvent(
    String graphId,
    List<String> nodeIds,
    RelationChangeAction action,
  ) {
    publishEvent(GraphNodeRelationChangedEvent(
      graphId: graphId,
      nodeIds: nodeIds,
      action: action,
    ));
  }

  // === 事务处理辅助方法 ===
  // 说明：支持命令执行的事务性操作
  // 注意：当前实现为简化版本，完整事务支持需要中间件配合

  /// 在事务中执行操作
  ///
  /// 包装操作以支持事务性执行。如果操作失败，会自动回滚。
  /// 注意：此方法需要事务中间件支持才能实现真正的 ACID 特性。
  ///
  /// 参数：
  /// - [operation] 要执行的异步操作
  ///
  /// 返回：操作的结果
  ///
  /// 抛出：如果操作失败，抛出原始异常
  Future<T> withTransaction<T>(
    Future<T> Function() operation,
  ) async {
    // 标记事务开始（通过元数据）
    setMetadata('_transaction_active', true);

    try {
      // 执行操作
      final result = await operation();

      // 标记事务提交
      setMetadata('_transaction_committed', true);

      return result;
    } catch (e) {
      // 标记事务回滚
      setMetadata('_transaction_rolled_back', true);
      rethrow;
    }
  }

  /// 检查是否在事务中
  ///
  /// 返回 true 如果当前上下文处于活动的事务中
  bool get isInTransaction =>
      getMetadata('_transaction_active') == true &&
      getMetadata('_transaction_committed') != true &&
      getMetadata('_transaction_rolled_back') != true;

  /// 注册服务
  ///
  /// 用于在执行上下文中注入额外的服务
  void registerService<T>(T service) {
    _services[T] = service;
  }

  /// 获取服务
  ///
  /// 通过类型获取已注册的服务
  /// 如果服务不存在，抛出 [ServiceNotFoundException]
  T read<T>() {
    final service = _services[T];
    if (service == null) {
      throw ServiceNotFoundException('Service not found: $T');
    }
    return service as T;
  }

  /// 尝试获取服务
  ///
  /// 返回服务或 null（如果不存在）
  T? tryRead<T>() => _services[T] as T?;

  /// 设置元数据
  ///
  /// 用于在命令执行过程中传递上下文信息
  void setMetadata(String key, dynamic value) {
    _metadata[key] = value;
  }

  /// 获取元数据
  ///
  /// 返回指定键的元数据值，或 null（如果不存在）
  dynamic getMetadata(String key) => _metadata[key];

  /// 检查元数据是否存在
  bool hasMetadata(String key) => _metadata.containsKey(key);

  /// 清除所有元数据
  void clearMetadata() {
    _metadata.clear();
  }

  /// 创建子上下文
  ///
  /// 继承当前上下文的所有服务，但元数据独立
  CommandContext createChild() {
    final child = CommandContext(
      nodeRepository: tryRead<NodeRepository>(),
      graphRepository: tryRead<GraphRepository>(),
      commandBus: commandBus,
      additionalServices: Map.from(_services),
    );

    // 复制元数据
    child._metadata.addAll(_metadata);

    return child;
  }
}
