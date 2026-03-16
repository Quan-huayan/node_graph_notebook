import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
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
        _instantiatedServices = {};

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

    // 检查是否已被注册
    if (_bindings.containsKey(serviceType)) {
      throw ServiceRegistrationException(
        'Service $serviceType is already registered',
      );
    }

    // 注册绑定
    _bindings[serviceType] = binding;

    // 记录插件提供的 Service
    _pluginServices.putIfAbsent(pluginId, () => {}).add(serviceType);

    // === 立即实例化服务（除非标记为懒加载）===
    // 懒加载的服务只在第一次被请求时创建
    if (!binding.isLazy) {
      try {
        final instance = _createServiceInstance(binding);
        _instantiatedServices[serviceType] = instance;

        debugPrint(
          '[ServiceRegistry] Instantiated $serviceType from $pluginId',
        );
      } catch (e) {
        // 实例化失败，回滚注册
        _bindings.remove(serviceType);
        _pluginServices[pluginId]?.remove(serviceType);
        throw ServiceRegistrationException(
          'Failed to instantiate $serviceType: $e',
        );
      }
    } else {
      debugPrint(
        '[ServiceRegistry] Registered lazy service $serviceType from $pluginId',
      );
    }

    // 通知监听器（触发 Provider 树重建）
    notifyListeners();
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
    final serviceTypes = _pluginServices[pluginId];
    if (serviceTypes == null) return;

    for (final serviceType in serviceTypes) {
      final binding = _bindings[serviceType];
      final instance = _instances[serviceType];
      final instantiatedInstance = _instantiatedServices[serviceType];

      // 释放资源（优先释放立即实例化的服务）
      if (binding != null && instantiatedInstance != null) {
        try {
          binding.dispose(instantiatedInstance);
        } catch (e) {
          debugPrint('[ServiceRegistry] Error disposing $serviceType: $e');
        }
      } else if (binding != null && instance != null) {
        try {
          binding.dispose(instance);
        } catch (e) {
          debugPrint('[ServiceRegistry] Error disposing $serviceType: $e');
        }
      }

      // 移除绑定和实例
      _bindings.remove(serviceType);
      _instances.remove(serviceType);
      _instantiatedServices.remove(serviceType);
    }

    // 移除插件记录
    _pluginServices.remove(pluginId);

    debugPrint(
      '[ServiceRegistry] Unregistered ${serviceTypes.length} services from $pluginId',
    );

    // 通知监听器（触发 Provider 树重建）
    notifyListeners();
  }

  /// 生成 Provider 列表
  ///
  /// 根据 Service 的依赖关系，生成正确的 Provider 顺序
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
    // 使用拓扑排序确定 Provider 顺序
    final sortedTypes = _topologicalSort();
    final providers = <SingleChildWidget>[];

    for (final type in sortedTypes) {
      final binding = _bindings[type]!;
      providers.add(_createProvider(binding));
    }

    return providers;
  }

  /// 为绑定创建 Provider
  ///
  /// 根据 Service 类型自动选择合适的 Provider 类型
  SingleChildWidget _createProvider(ServiceBinding binding) {
    return Provider(
      create: (ctx) {
        // 如果已经有实例（单例），直接返回
        if (_instances.containsKey(binding.serviceType)) {
          return _instances[binding.serviceType];
        }

        // 创建依赖解析器（包含核心依赖）
        final resolver = ServiceResolver(
          _bindings,
          _instances,
          coreDependencies: _coreDependencies,
        );

        // 创建新实例
        final instance = binding.createService(resolver);

        // 如果是单例，缓存实例
        if (binding.isSingleton) {
          _instances[binding.serviceType] = instance;
        }

        return instance;
      },
    );
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

    // 1. 优先从立即实例化缓存获取
    if (_instantiatedServices.containsKey(serviceType)) {
      return _instantiatedServices[serviceType] as T;
    }

    // 2. 检查是否是懒加载服务，如果是则创建实例
    if (_bindings.containsKey(serviceType)) {
      final binding = _bindings[serviceType]!;
      if (binding.isLazy) {
        try {
          final instance = _createServiceInstance(binding);
          _instantiatedServices[serviceType] = instance;
          debugPrint(
            '[ServiceRegistry] Lazy instantiated $serviceType',
          );
          return instance;
        } catch (e) {
          throw ServiceNotFoundException(
            'Failed to instantiate lazy service $T: $e',
          );
        }
      }
    }

    // 3. 尝试从父类实例缓存获取
    final parentInstance = getService<T>();
    if (parentInstance != null) {
      return parentInstance;
    }

    // 4. 如果都找不到，抛出异常
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

    // 2. 尝试从 ServiceRegistry 获取（包括核心依赖）
    final parentInstance = _registry.getService<T>();
    if (parentInstance != null) {
      return parentInstance;
    }

    // 3. 如果都找不到，抛出异常
    throw ServiceNotFoundException(
      'Service $T not found (services available: ${_registry._instantiatedServices.keys.join(', ')})',
    );
  }

  @override
  bool has<T>() => _registry._instantiatedServices.containsKey(T) ||
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
