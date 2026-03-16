import '../../../plugins/builtin_plugins/graph/service/graph_service.dart';
import '../../../plugins/builtin_plugins/graph/service/node_service.dart';
import '../../events/app_events.dart';
import '../../models/node.dart';
import '../../plugin/service_registry.dart';
import '../../repositories/graph_repository.dart';
import '../../repositories/node_repository.dart';

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
class CommandContext {
  /// 构造函数
  CommandContext({
    NodeService? nodeService,
    GraphService? graphService,
    NodeRepository? nodeRepository,
    GraphRepository? graphRepository,
    AppEventBus? eventBus,
  }) {
    if (nodeService != null) {
      _services[NodeService] = nodeService;
    }
    if (graphService != null) {
      _services[GraphService] = graphService;
    }
    if (nodeRepository != null) {
      _services[NodeRepository] = nodeRepository;
    }
    if (graphRepository != null) {
      _services[GraphRepository] = graphRepository;
    }
    this.eventBus = eventBus ?? getAppEventBus();
  }

  /// 服务注册表
  final Map<Type, dynamic> _services = {};

  /// 元数据存储
  final Map<String, dynamic> _metadata = {};

  /// 事件总线
  late final AppEventBus eventBus;

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

  /// 获取节点服务
  ///
  /// 如果节点服务未注册，返回 null
  NodeService? get nodeService => tryRead<NodeService>();

  /// 获取图服务
  ///
  /// 如果图服务未注册，返回 null
  GraphService? get graphService => tryRead<GraphService>();

  // === 事件发布辅助方法 ===
  // 说明：为常用的事件发布操作提供便捷方法
  // 好处：统一事件发布逻辑，减少重复代码，便于维护

  /// 发布节点数据变化事件
  ///
  /// 当节点数据发生变化时（创建、更新、删除），通过此方法发布事件。
  /// 其他组件（如 BLoC）可以订阅此事件以更新 UI 状态。
  ///
  /// 参数：
  /// - [nodes] 发生变化的节点列表
  /// - [action] 变化类型（创建、更新、删除）
  void publishNodeEvent(List<Node> nodes, DataChangeAction action) {
    eventBus.publish(NodeDataChangedEvent(
      changedNodes: nodes,
      action: action,
    ));
  }

  /// 发布单个节点数据变化事件
  ///
  /// 便捷方法，用于发布单个节点的变化事件
  ///
  /// 参数：
  /// - [node] 发生变化的节点
  /// - [action] 变化类型（创建、更新、删除）
  void publishSingleNodeEvent(Node node, DataChangeAction action) {
    publishNodeEvent([node], action);
  }

  /// 发布图节点关系变化事件
  ///
  /// 当节点与图的关系发生变化时（添加到图、从图移除），通过此方法发布事件
  ///
  /// 参数：
  /// - [graphId] 发生变化的图 ID
  /// - [nodeIds] 涉及的节点 ID 列表
  /// - [action] 变化类型（添加到图、从图移除）
  void publishGraphRelationEvent(
    String graphId,
    List<String> nodeIds,
    RelationChangeAction action,
  ) {
    eventBus.publish(GraphNodeRelationChangedEvent(
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

  /// 获取全局事件总线实例
  ///
  /// AppEventBus 是单例模式，直接返回工厂构造函数创建的实例
  AppEventBus getAppEventBus() => AppEventBus();

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
      nodeService: tryRead<NodeService>(),
      graphService: tryRead<GraphService>(),
      nodeRepository: tryRead<NodeRepository>(),
      graphRepository: tryRead<GraphRepository>(),
      eventBus: eventBus,
    );

    // 复制元数据
    child._metadata.addAll(_metadata);

    return child;
  }
}
