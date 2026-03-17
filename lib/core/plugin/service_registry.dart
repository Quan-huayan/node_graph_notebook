import 'package:flutter/foundation.dart';
import 'package:provider/single_child_widget.dart';
import 'service_binding.dart';

/// Service 注册表
///
/// 管理所有插件提供的 Service，统一生成 Provider 列表
///
/// 职责：
/// - 收集所有插件的 ServiceBinding
/// - 解析 Service 依赖关系
/// - 生成 Flutter Provider 列表
/// - 管理 Service 生命周期
/// - 支持立即实例化（解决插件 onLoad() 中无法访问自己注册的服务的问题）
/// - 支持服务变化通知（触发 Provider 树重建）
class ServiceRegistry with ChangeNotifier {
  /// 创建一个新的 Service 注册表实例。
  ServiceRegistry({Map<Type, dynamic>? coreDependencies})
      : _coreDependencies = coreDependencies ?? {},
        _instantiatedServices = {} {
    debugPrint('[ServiceRegistry] =========================================');
    debugPrint('[ServiceRegistry] ServiceRegistry 初始化');
    debugPrint('[ServiceRegistry] =========================================');
    debugPrint('[ServiceRegistry] 核心依赖数量: ${_coreDependencies.length}');
    debugPrint('[ServiceRegistry] 核心依赖类型: ${_coreDependencies.keys.join(", ")}');
    debugPrint('[ServiceRegistry] =========================================');
  }

  /// Service 绑定注册表
  ///
  /// Key: Service 类型
  /// Value: ServiceBinding 实例
  final Map<Type, ServiceBinding> _bindings = {};

  /// Service 实例（单例）
  ///
  /// Key: Service 类型
  /// Value: Service 实例
  final Map<Type, dynamic> _instances = {};

  /// 已立即实例化的服务缓存
  ///
  /// Key: Service 类型
  /// Value: 服务实例
  ///
  /// 与 _instances 的区别：
  /// - _instantiatedServices: 在 registerService() 时立即创建
  /// - _instances: 在 Provider.create() 时延迟创建
  final Map<Type, dynamic> _instantiatedServices;

  /// 插件 ID 到 Service 类型的映射
  ///
  /// 用于跟踪哪些 Service 是由哪个插件提供的
  final Map<String, Set<Type>> _pluginServices = {};

  /// 核心依赖（Repository、CommandBus、EventBus 等）
  ///
  /// 这些依赖不是通过插件提供的，但是插件的 Service 可能会依赖它们
  final Map<Type, dynamic> _coreDependencies;

  /// 注册 Service 绑定
  ///
  /// [pluginId] 插件 ID
  /// [binding] Service 绑定
  ///
  /// 关键改进：立即实例化服务（除非标记为懒加载）
  /// 这解决了 PluginContext 在 onLoad() 中无法访问自己注册的服务的问题
  ///
  /// 使用示例：
  /// ```dart
  /// registry.registerService('graph_plugin', NodeServiceBinding());
  /// ```
  void registerService<T>(String pluginId, ServiceBinding<T> binding) {
    final serviceType = binding.serviceType;

    debugPrint('[ServiceRegistry] -----------------------------------------');
    debugPrint('[ServiceRegistry] 开始注册服务');
    debugPrint('[ServiceRegistry]   插件 ID: $pluginId');
    debugPrint('[ServiceRegistry]   服务类型: $serviceType');
    debugPrint('[ServiceRegistry]   是否懒加载: ${binding.isLazy}');
    debugPrint('[ServiceRegistry]   是否单例: ${binding.isSingleton}');

    // 检查是否已被注册
    if (_bindings.containsKey(serviceType)) {
      debugPrint('[ServiceRegistry] ✗ 注册失败: 服务已存在');
      throw ServiceRegistrationException(
        'Service $serviceType is already registered',
      );
    }

    // 注册绑定
    _bindings[serviceType] = binding;

    // 记录插件提供的 Service
    _pluginServices.putIfAbsent(pluginId, () => {}).add(serviceType);

    debugPrint('[ServiceRegistry] ✓ 绑定已注册到注册表');

    // === 立即实例化服务（除非标记为懒加载）===
    // 懒加载的服务只在第一次被请求时创建
    if (!binding.isLazy) {
      debugPrint('[ServiceRegistry] 正在立即实例化服务...');
      try {
        final instance = _createServiceInstance(binding);
        _instantiatedServices[serviceType] = instance;

        debugPrint('[ServiceRegistry] ✓ 服务实例化成功');
        debugPrint('[ServiceRegistry]   实例类型: ${instance.runtimeType}');
        debugPrint('[ServiceRegistry]   实例哈希: ${instance.hashCode}');

        debugPrint(
          '[ServiceRegistry] Instantiated $serviceType from $pluginId',
        );
      } catch (e) {
        debugPrint('[ServiceRegistry] ✗ 实例化失败: $e');
        // 实例化失败，回滚注册
        _bindings.remove(serviceType);
        _pluginServices[pluginId]?.remove(serviceType);
        throw ServiceRegistrationException(
          'Failed to instantiate $serviceType: $e',
        );
      }
    } else {
      debugPrint('[ServiceRegistry] 服务标记为懒加载，延迟实例化');
      debugPrint(
        '[ServiceRegistry] Registered lazy service $serviceType from $pluginId',
      );
    }

    debugPrint('[ServiceRegistry] 当前已注册服务总数: ${_bindings.length}');
    debugPrint('[ServiceRegistry] 当前已实例化服务总数: ${_instantiatedServices.length}');
    debugPrint('[ServiceRegistry] -----------------------------------------');

    // 通知监听器（触发 Provider 树重建）
    notifyListeners();
    debugPrint('[ServiceRegistry] 已通知监听器，Provider 树将重建');
  }

  /// 批量注册 Service 绑定
  ///
  /// [pluginId] 插件 ID
  /// [bindings] Service 绑定列表
  void registerServices(String pluginId, List<ServiceBinding> bindings) {
    for (final binding in bindings) {
      registerService(pluginId, binding);
    }
  }

  /// 注销插件的所有 Service
  ///
  /// [pluginId] 插件 ID
  ///
  /// 在插件卸载时调用，释放相关 Service 资源
  void unregisterPluginServices(String pluginId) {
    debugPrint('[ServiceRegistry] -----------------------------------------');
    debugPrint('[ServiceRegistry] 开始注销插件服务');
    debugPrint('[ServiceRegistry]   插件 ID: $pluginId');

    final serviceTypes = _pluginServices[pluginId];
    if (serviceTypes == null) {
      debugPrint('[ServiceRegistry] ✗ 插件没有注册的服务');
      return;
    }

    debugPrint('[ServiceRegistry]   服务数量: ${serviceTypes.length}');
    debugPrint('[ServiceRegistry]   服务类型: ${serviceTypes.join(", ")}');

    for (final serviceType in serviceTypes) {
      debugPrint('[ServiceRegistry] 正在注销服务: $serviceType');
      
      final binding = _bindings[serviceType];
      final instance = _instances[serviceType];
      final instantiatedInstance = _instantiatedServices[serviceType];

      // 释放资源（优先释放立即实例化的服务）
      if (binding != null && instantiatedInstance != null) {
        try {
          debugPrint('[ServiceRegistry] 正在释放立即实例化的服务...');
          binding.dispose(instantiatedInstance);
          debugPrint('[ServiceRegistry] ✓ 服务资源释放成功');
        } catch (e) {
          debugPrint('[ServiceRegistry] ✗ 释放服务资源失败: $e');
        }
      } else if (binding != null && instance != null) {
        try {
          debugPrint('[ServiceRegistry] 正在释放延迟实例化的服务...');
          binding.dispose(instance);
          debugPrint('[ServiceRegistry] ✓ 服务资源释放成功');
        } catch (e) {
          debugPrint('[ServiceRegistry] ✗ 释放服务资源失败: $e');
        }
      }

      // 移除绑定和实例
      _bindings.remove(serviceType);
      _instances.remove(serviceType);
      _instantiatedServices.remove(serviceType);
      
      debugPrint('[ServiceRegistry] ✓ 服务已从注册表移除');
    }

    // 移除插件记录
    _pluginServices.remove(pluginId);

    debugPrint('[ServiceRegistry] ✓ 插件服务注销完成');
    debugPrint('[ServiceRegistry]   剩余已注册服务: ${_bindings.length}');
    debugPrint('[ServiceRegistry]   剩余已实例化服务: ${_instantiatedServices.length}');

    debugPrint(
      '[ServiceRegistry] Unregistered ${serviceTypes.length} services from $pluginId',
    );

    debugPrint('[ServiceRegistry] -----------------------------------------');

    // 通知监听器（触发 Provider 树重建）
    notifyListeners();
    debugPrint('[ServiceRegistry] 已通知监听器，Provider 树将重建');
  }

  /// 生成 Provider 列表
  ///
  /// 根据 Service 的依赖关系，生成正确的 Provider 顺序。
  /// 使用 Provider.value 注册已经实例化的服务，避免不必要的重建。
  ///
  /// 返回 Provider 列表，可直接用于 MultiProvider
  ///
  /// 使用示例：
  /// ```dart
  /// MultiProvider(
  ///   providers: serviceRegistry.generateProviders(),
  ///   child: MyApp(),
  /// )
  /// ```
  List<SingleChildWidget> generateProviders() {
    debugPrint('[ServiceRegistry] =========================================');
    debugPrint('[ServiceRegistry] 开始生成 Provider 列表');
    debugPrint('[ServiceRegistry] 当前已注册服务数量: ${_bindings.length}');
    
    // 使用拓扑排序确定 Provider 顺序
    final sortedTypes = _topologicalSort();
    debugPrint('[ServiceRegistry] 拓扑排序完成，Provider 顺序:');
    for (var i = 0; i < sortedTypes.length; i++) {
      debugPrint('[ServiceRegistry]   $i. ${sortedTypes[i]}');
    }
    
    final providers = <SingleChildWidget>[];

    for (final type in sortedTypes) {
      final binding = _bindings[type]!;
      final provider = _createValueProvider(binding);
      providers.add(provider);
      debugPrint('[ServiceRegistry] ✓ 已创建 Provider: $type');
    }

    debugPrint('[ServiceRegistry] Provider 列表生成完成，总数: ${providers.length}');
    debugPrint('[ServiceRegistry] =========================================');
    
    return providers;
  }

  /// 为绑定创建 Provider（使用 .value 构造函数）
  ///
  /// 关键：使用 Provider.value 而不是 Provider(create: ...)
  /// 因为服务已经在 registerService 时实例化，不需要再次创建
  SingleChildWidget _createValueProvider(ServiceBinding binding) {
    final serviceType = binding.serviceType;
    
    // 优先使用立即实例化的服务
    final instance = _instantiatedServices[serviceType] ?? _instances[serviceType];
    
    if (instance == null) {
      throw ServiceRegistrationException(
        'Service $serviceType not instantiated. '
        'Make sure to call registerService() before generateProviders().',
      );
    }
    
    // 使用 ServiceBinding 的 createProvider 方法创建 Provider
    // 关键：通过 binding.createProvider(instance) 调用，保留泛型类型信息
    // 由于 binding 是 ServiceBinding<T>，createProvider 方法会返回 Provider<T>.value
    // 这样可以确保 Provider 的类型参数正确
    
    // 注意：这里我们使用 dynamic 类型转换来调用 createProvider 方法
    // 虽然 binding 的静态类型是 ServiceBinding（没有泛型参数），
    // 但它的运行时类型是 ServiceBinding<T>，
    // 所以 createProvider 方法会正确返回 Provider<T>.value
    
    return binding.createProvider(instance);
  }

  /// 拓扑排序 Service 类型
  ///
  /// 根据 Service 依赖关系排序，确保依赖的 Service 排在前面
  List<Type> _topologicalSort() {
    final sorted = <Type>[];
    final visiting = <Type>{};
    final visited = <Type>{};

    void visit(Type type) {
      if (visited.contains(type)) return;
      if (visiting.contains(type)) {
        throw ServiceRegistrationException(
          'Circular dependency detected: $type',
        );
      }

      visiting.add(type);

      _getDependencies(type).forEach(visit);

      visiting.remove(type);
      visited.add(type);
      sorted.add(type);
    }

    // 访问所有 Service
    _bindings.keys.forEach(visit);

    return sorted;
  }

  /// 获取 Service 的依赖类型
  ///
  /// 通过分析 createService 方法调用的 resolver.get<T>() 获取依赖
  ///
  /// 注意：这里简化处理，实际需要更复杂的依赖分析
  /// 当前实现假设所有 Service 都可能依赖所有其他 Service
  /// 正确的做法是在 ServiceBinding 中显式声明依赖
  Set<Type> _getDependencies(Type serviceType) {
    // TODO: 实现真正的依赖分析
    // 当前简化处理：假设没有依赖
    return {};
  }

  /// 检查 Service 是否已注册
  ///
  /// [T] Service 类型
  /// 返回 true 如果 Service 已注册
  bool isRegistered<T>() => _bindings.containsKey(T);

  /// 获取所有已注册的 Service 类型
  Set<Type> get registeredTypes => _bindings.keys.toSet();

  /// 获取插件提供的 Service 类型
  ///
  /// [pluginId] 插件 ID
  /// 返回插件提供的所有 Service 类型
  Set<Type> getPluginServices(String pluginId) => _pluginServices[pluginId] ?? {};

  /// 获取 Service 绑定
  ///
  /// [T] Service 类型
  /// 返回 Service 绑定，如果未注册则返回 null
  ServiceBinding<T>? getBinding<T>() {
    final serviceType = T;
    if (!_bindings.containsKey(serviceType)) return null;
    return _bindings[serviceType] as ServiceBinding<T>;
  }

  /// 获取 Service 实例
  ///
  /// [T] Service 类型
  /// 返回 Service 实例，如果不存在则返回 null
  T? getService<T>() {
    final serviceType = T;

    // 如果已有缓存实例，直接返回
    if (_instances.containsKey(serviceType)) {
      return _instances[serviceType] as T;
    }

    // 如果没有缓存实例，但已注册，则创建新实例
    if (_bindings.containsKey(serviceType)) {
      try {
        final binding = _bindings[serviceType]!;
        final resolver = ServiceResolver(
          _bindings,
          _instances,
          coreDependencies: _coreDependencies,
        );
        final instance = binding.createService(resolver);

        // 如果是单例，缓存实例
        if (binding.isSingleton) {
          _instances[serviceType] = instance;
        }

        return instance as T;
      } catch (e) {
        debugPrint('[ServiceRegistry] Error creating service $serviceType: $e');
        return null;
      }
    }

    return null;
  }

  /// 直接获取服务实例（绕过 Provider）
  ///
  /// [T] Service 类型
  /// 返回服务实例
  ///
  /// 抛出 [ServiceNotFoundException] 如果服务未注册
  ///
  /// 使用场景：
  /// - PluginContext 在 onLoad() 中访问自己注册的服务
  /// - 在 Provider 树构建前访问服务
  T getServiceDirect<T>() {
    final serviceType = T;

    debugPrint('[ServiceRegistry] -----------------------------------------');
    debugPrint('[ServiceRegistry] 直接获取服务实例');
    debugPrint('[ServiceRegistry]   服务类型: $serviceType');

    // 1. 优先从立即实例化缓存获取
    if (_instantiatedServices.containsKey(serviceType)) {
      final instance = _instantiatedServices[serviceType] as T;
      debugPrint('[ServiceRegistry] ✓ 从立即实例化缓存获取成功');
      debugPrint('[ServiceRegistry]   实例哈希: ${instance.hashCode}');
      debugPrint('[ServiceRegistry] -----------------------------------------');
      return instance;
    }

    debugPrint('[ServiceRegistry] 立即实例化缓存中未找到');

    // 2. 检查是否是懒加载服务，如果是则创建实例
    if (_bindings.containsKey(serviceType)) {
      final binding = _bindings[serviceType]!;
      if (binding.isLazy) {
        debugPrint('[ServiceRegistry] 服务标记为懒加载，开始实例化...');
        try {
          final instance = _createServiceInstance(binding);
          _instantiatedServices[serviceType] = instance;
          debugPrint('[ServiceRegistry] ✓ 懒加载实例化成功');
          debugPrint('[ServiceRegistry]   实例类型: ${instance.runtimeType}');
          debugPrint('[ServiceRegistry]   实例哈希: ${instance.hashCode}');
          debugPrint(
            '[ServiceRegistry] Lazy instantiated $serviceType',
          );
          debugPrint('[ServiceRegistry] -----------------------------------------');
          return instance;
        } catch (e) {
          debugPrint('[ServiceRegistry] ✗ 懒加载实例化失败: $e');
          throw ServiceNotFoundException(
            'Failed to instantiate lazy service $T: $e',
          );
        }
      } else {
        debugPrint('[ServiceRegistry] 服务已注册但未实例化（非懒加载）');
      }
    }

    debugPrint('[ServiceRegistry] 服务未在注册表中找到');

    // 3. 尝试从父类实例缓存获取
    debugPrint('[ServiceRegistry] 尝试从父类实例缓存获取...');
    final parentInstance = getService<T>();
    if (parentInstance != null) {
      debugPrint('[ServiceRegistry] ✓ 从父类实例缓存获取成功');
      debugPrint('[ServiceRegistry]   实例哈希: ${parentInstance.hashCode}');
      debugPrint('[ServiceRegistry] -----------------------------------------');
      return parentInstance;
    }

    debugPrint('[ServiceRegistry] ✗ 父类实例缓存中也未找到');

    // 4. 如果都找不到，抛出异常
    debugPrint('[ServiceRegistry] ✗ 服务查找失败，抛出异常');
    debugPrint('[ServiceRegistry] -----------------------------------------');
    throw ServiceNotFoundException(
      'Service $T not found in registry',
    );
  }

  /// 检查服务是否可用（可立即解析）
  ///
  /// [T] Service 类型
  /// 返回 true 如果服务已注册并可立即解析
  bool hasService<T>() {
    // 检查是否在立即实例化缓存中
    if (_instantiatedServices.containsKey(T)) {
      return true;
    }

    // 检查是否已注册（包括懒加载服务）
    return _bindings.containsKey(T);
  }

  /// 创建服务实例（内部方法）
  ///
  /// [binding] Service 绑定
  /// 返回服务实例
  dynamic _createServiceInstance(ServiceBinding binding) {
    // 策略：使用 getService() 方法来处理依赖解析
    // 这会自动使用 ServiceResolver，它包含核心依赖
    final instance = binding.createService(_ServiceResolverAdapter(this));
    return instance;
  }

  /// 清空所有注册
  ///
  /// 仅用于测试
  @visibleForTesting
  void clear() {
    // 释放所有 Service 资源
    for (final entry in _instances.entries) {
      final binding = _bindings[entry.key];
      if (binding != null) {
        try {
          binding.dispose(entry.value);
        } catch (e) {
          debugPrint('[ServiceRegistry] Error disposing ${entry.key}: $e');
        }
      }
    }

    // 释放立即实例化的服务
    for (final entry in _instantiatedServices.entries) {
      final binding = _bindings[entry.key];
      if (binding != null) {
        try {
          binding.dispose(entry.value);
        } catch (e) {
          debugPrint('[ServiceRegistry] Error disposing ${entry.key}: $e');
        }
      }
    }

    _bindings.clear();
    _instances.clear();
    _instantiatedServices.clear();
    _pluginServices.clear();
  }
}

/// Service 解析器适配器
///
/// 将 ServiceRegistry 适配为 ServiceResolver 接口
/// 用于在服务创建过程中解析依赖
class _ServiceResolverAdapter extends ServiceResolver {
  /// 创建一个新的服务解析器适配器实例
  ///
  /// [registry] 服务注册表
  _ServiceResolverAdapter(this._registry)
      : super({}, {}, coreDependencies: {});

  final ServiceRegistry _registry;

  @override
  T get<T>() {
    // 1. 优先从立即实例化缓存获取
    if (_registry._instantiatedServices.containsKey(T)) {
      return _registry._instantiatedServices[T] as T;
    }

    // 2. 检查核心依赖（NodeRepository, GraphRepository, CommandBus 等）
    if (_registry._coreDependencies.containsKey(T)) {
      return _registry._coreDependencies[T] as T;
    }

    // 3. 尝试从 ServiceRegistry 获取
    final parentInstance = _registry.getService<T>();
    if (parentInstance != null) {
      return parentInstance;
    }

    // 4. 如果都找不到，抛出异常
    final availableServices = [
      ..._registry._instantiatedServices.keys,
      ..._registry._coreDependencies.keys,
    ].join(', ');
    throw ServiceNotFoundException(
      'Service $T not found (services available: $availableServices)',
    );
  }

  @override
  bool has<T>() => _registry._instantiatedServices.containsKey(T) ||
        _registry._coreDependencies.containsKey(T) ||
        _registry._bindings.containsKey(T);
}

/// 服务未找到异常
///
/// 当请求的服务未注册时抛出
class ServiceNotFoundException implements Exception {
  /// 创建一个新的服务未找到异常实例
  ///
  /// [message] 错误消息
  const ServiceNotFoundException(this.message);

  /// 错误消息
  final String message;

  @override
  String toString() => 'ServiceNotFoundException: $message';
}

/// Service 注册异常
///
/// 当 Service 注册失败时抛出
class ServiceRegistrationException implements Exception {
  /// 创建一个新的 Service 注册异常实例。
  ///
  /// [message] 错误消息
  const ServiceRegistrationException(this.message);

  /// 错误消息
  final String message;

  @override
  String toString() => 'ServiceRegistrationException: $message';
}
