import '../../plugins/builtin_plugins/graph/service/node_service.dart';
import '../../plugins/builtin_plugins/graph/service/graph_service.dart';
import '../repositories/node_repository.dart';
import '../repositories/graph_repository.dart';
import '../events/app_events.dart';

/// 命令执行上下文
///
/// 提供命令执行所需的依赖和服务
/// 采用读写器模式访问各种服务
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

  /// 获取全局事件总线实例
  ///
  /// AppEventBus 是单例模式，直接返回工厂构造函数创建的实例
  AppEventBus getAppEventBus() {
    return AppEventBus();
  }

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
      throw ServiceNotFoundException(T.toString());
    }
    return service as T;
  }

  /// 尝试获取服务
  ///
  /// 返回服务或 null（如果不存在）
  T? tryRead<T>() {
    return _services[T] as T?;
  }

  /// 设置元数据
  ///
  /// 用于在命令执行过程中传递上下文信息
  void setMetadata(String key, dynamic value) {
    _metadata[key] = value;
  }

  /// 获取元数据
  ///
  /// 返回指定键的元数据值，或 null（如果不存在）
  dynamic getMetadata(String key) {
    return _metadata[key];
  }

  /// 检查元数据是否存在
  bool hasMetadata(String key) {
    return _metadata.containsKey(key);
  }

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

/// 服务未找到异常
///
/// 当请求的服务未在上下文中注册时抛出
class ServiceNotFoundException implements Exception {
  ServiceNotFoundException(this.serviceType);

  /// 服务类型名称
  final String serviceType;

  @override
  String toString() => 'ServiceNotFoundException: 未找到服务 $serviceType';
}
