/// 插件 Service 绑定系统
///
/// 提供统一的 Service 依赖注入机制，让插件声明它提供的 Service
///
/// 设计理念：
/// - 每个插件通过 ServiceBinding 声明它提供的 Service
/// - ServiceBinding 包含 Service 的创建逻辑和依赖关系
/// - PluginManager 自动收集所有插件的 ServiceBinding 并生成 Provider
///
/// Service 绑定基类
///
/// 声明一个 Service 的创建方式和依赖关系
///
/// 使用示例：
/// ```dart
/// class NodeServiceBinding extends ServiceBinding<NodeService> {
///   @override
///   NodeService createService(ServiceResolver resolver) {
///     final nodeRepository = resolver.get<NodeRepository>();
///     return NodeServiceImpl(nodeRepository);
///   }
/// }
/// ```
abstract class ServiceBinding<T> {
  /// 创建 Service 实例
  ///
  /// [resolver] Service 解析器，用于获取依赖的 Service
  /// 返回创建的 Service 实例
  T createService(ServiceResolver resolver);

  /// Service 类型
  ///
  /// 返回 Service 的类型，用于注册和解析
  Type get serviceType => T;

  /// 是否为单例（默认 true）
  ///
  /// true：整个应用只创建一次实例
  /// false：每次请求都创建新实例
  bool get isSingleton => true;

  /// 是否懒加载（默认 false）
  ///
  /// true：只有在第一次被请求时才创建实例
  /// false：在注册时立即创建实例
  ///
  /// 使用场景：
  /// - 非关键服务（如 AI 服务、导出服务等）
  /// - 初始化成本高的服务
  /// - 可能不被使用的服务
  bool get isLazy => false;

  /// Service 名称（可选）
  ///
  /// 用于区分同一类型的多个 Service 实例
  String? get serviceName => null;

  /// 释放 Service 资源
  ///
  /// 在 Service 被卸载时调用
  void dispose(T service) {
    // 默认不做任何操作
    // Service 如果需要释放资源，重写此方法
  }
}

/// Service 解析器
///
/// 用于在 Service 创建过程中解析依赖
class ServiceResolver {
  /// 创建一个新的 Service 解析器实例。
  ///
  /// [_bindings] 所有 Service 绑定
  /// [_instances] 已创建的 Service 实例（单例）
  ServiceResolver(
    this._bindings,
    this._instances, {
    Map<Type, dynamic>? coreDependencies,
  }) : _coreDependencies = coreDependencies ?? {};

  /// 所有 Service 绑定
  final Map<Type, ServiceBinding> _bindings;

  /// 已创建的 Service 实例（单例）
  final Map<Type, dynamic> _instances;

  /// 核心依赖（Repository、CommandBus、EventBus 等）
  ///
  /// 这些依赖不是通过插件提供的，但是插件的 Service 可能会依赖它们
  final Map<Type, dynamic> _coreDependencies;

  /// 获取 Service 依赖
  ///
  /// [T] Service 类型
  /// 返回 Service 实例
  ///
  /// 注意：此方法仅用于 Service 创建过程中解析依赖
  /// 不要在插件代码中直接使用
  T get<T>() {
    // 先检查是否已有实例（单例）
    if (_instances.containsKey(T)) {
      return _instances[T] as T;
    }

    // 检查核心依赖中是否有
    if (_coreDependencies.containsKey(T)) {
      return _coreDependencies[T] as T;
    }

    // 检查是否有对应的绑定
    if (!_bindings.containsKey(T)) {
      throw ServiceDependencyException('Service $T not found in registry');
    }

    // 创建新实例
    final binding = _bindings[T] as ServiceBinding<T>;
    final instance = binding.createService(this);

    // 如果是单例，缓存实例
    if (binding.isSingleton) {
      _instances[T] = instance;
    }

    return instance;
  }

  /// 检查 Service 是否可用
  ///
  /// [T] Service 类型
  /// 返回 true 如果 Service 可以被解析
  bool has<T>() => _instances.containsKey(T) || _bindings.containsKey(T);
}

/// Service 依赖异常
///
/// 当 Service 的依赖无法满足时抛出
class ServiceDependencyException implements Exception {
  /// 创建一个新的 Service 依赖异常实例。
  ///
  /// [message] 错误消息
  const ServiceDependencyException(this.message);

  /// 错误消息
  final String message;

  @override
  String toString() => 'ServiceDependencyException: $message';
}
