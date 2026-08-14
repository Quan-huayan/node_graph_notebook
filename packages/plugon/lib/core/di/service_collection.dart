import 'disposable.dart';
import 'exceptions.dart';
import 'service_descriptor.dart';
import 'service_lifetime.dart';
import 'service_provider.dart';

/// .NET 风格的注册表：只收集描述符，不实例化任何东西。
///
/// build 后得到 ServiceProvider，实例在首次解析时才创建（懒加载）。
///
/// 注册策略与 .NET 对齐：
/// - **同一类型允许多次注册**，`get<T>()` 返回最后一个注册（last-wins），
///   `getAll<T>()` 返回全部（按注册序，对应 .NET 的 `IEnumerable<T>`）；
/// - **双类型注册** `addSingletonFor<TService, TImpl>`：注册接口与实现，
///   两个类型都能解析到同一实例（.NET `AddSingleton<TService, TImpl>`）。
class ServiceCollection {
  /// 创建宿主注册表。
  ServiceCollection() : this._(null, [], _OrderCounter());

  /// 内部：owned 视图与宿主共享描述符列表与计数器。
  ServiceCollection._(this._viewOwner, this._descriptors, this._counter);

  final String? _viewOwner;
  final List<ServiceDescriptor<dynamic>> _descriptors;
  final _OrderCounter _counter;

  /// 返回一个"盖章视图"：通过它注册的所有服务 owner 自动标记为 [ownerId]，
  /// 插件无需在每次注册时传 owner。视图与宿主共享描述符列表。
  ServiceCollection owned(String ownerId) =>
      ServiceCollection._(ownerId, _descriptors, _counter);

  /// 注册单例：首次解析时创建，全局复用。
  ///
  /// 单类型形式：T 既是服务类型也是实现类型，只能按 T 解析。
  /// 需要接口/实现分离注册时用 [addSingletonFor]。
  ServiceCollection addSingleton<T>(
    T Function(ServiceProvider sp)? factory, {
    String? owner,
    bool isNotifier = false,
    bool isBloc = false,
    void Function(Object instance)? onDispose,
    Object Function(ServiceProvider sp)? providerFactory,
  }) {
    _register(
      T,
      null,
      _requireFactory(T, factory, 'addSingleton'),
      ServiceLifetime.singleton,
      owner: owner,
      isNotifier: isNotifier,
      isBloc: isBloc,
      onDispose: onDispose,
      providerFactory: providerFactory,
    );
    return this;
  }

  /// 双类型注册单例：注册服务类型 [TService] 与其实现 [TImpl]。
  ///
  /// `get<TService>()` 与 `get<TImpl>()` 解析到同一实例（.NET
  /// `AddSingleton<TService, TImpl>` 的 Dart 等价物，并额外允许按实现类型
  /// 解析——测试与具体类型依赖更便利）。
  ///
  /// 工厂二选一：
  /// - [factory]：接收 provider 的工厂闭包（构造器需要依赖注入时使用）；
  /// - [construct]：无参构造器 tear-off（如 `construct: Foo.new`）——
  ///   纯 Dart 无反射，无法自动实例化，这是 .NET 自动构造最近的等价物。
  ///
  /// **已知陷阱**：同一具体类型既作别名又单独注册时，两个键会解析到不同
  /// 实例。例如 `addSingletonFor<IFoo, Foo>(f1)` 后再 `addSingleton<Foo>(f2)`，
  /// `get<IFoo>` 是 f1 的实例而 `get<Foo>` 是 f2 的实例——别名一致性仅在
  /// 双方都走同一描述符时成立。
  ServiceCollection addSingletonFor<TService, TImpl extends TService>({
    TImpl Function(ServiceProvider sp)? factory,
    TImpl Function()? construct,
    String? owner,
    bool isNotifier = false,
    bool isBloc = false,
    void Function(Object instance)? onDispose,
    Object Function(ServiceProvider sp)? providerFactory,
  }) {
    _register(
      TService,
      TImpl,
      _requirePairFactory<TImpl>(
        factory,
        construct,
        TService,
        'addSingletonFor',
      ),
      ServiceLifetime.singleton,
      owner: owner,
      isNotifier: isNotifier,
      isBloc: isBloc,
      onDispose: onDispose,
      providerFactory: providerFactory,
    );
    return this;
  }

  /// 注册瞬态服务：每次解析创建新实例；实现 [Disposable] 或带
  /// [onDispose] 的实例被当前作用域追踪，作用域销毁时逆创建序清理
  /// （与 .NET 一致，防止资源泄漏）。
  ServiceCollection addTransient<T>(
    T Function(ServiceProvider sp)? factory, {
    String? owner,
    bool isNotifier = false,
    void Function(Object instance)? onDispose,
    Object Function(ServiceProvider sp)? providerFactory,
  }) {
    _register(
      T,
      null,
      _requireFactory(T, factory, 'addTransient'),
      ServiceLifetime.transient,
      owner: owner,
      isNotifier: isNotifier,
      onDispose: onDispose,
      providerFactory: providerFactory,
    );
    return this;
  }

  /// 双类型注册瞬态：语义同 [addSingletonFor]，生命周期为每次新建。
  ServiceCollection addTransientFor<TService, TImpl extends TService>({
    TImpl Function(ServiceProvider sp)? factory,
    TImpl Function()? construct,
    String? owner,
    bool isNotifier = false,
    void Function(Object instance)? onDispose,
    Object Function(ServiceProvider sp)? providerFactory,
  }) {
    _register(
      TService,
      TImpl,
      _requirePairFactory<TImpl>(
        factory,
        construct,
        TService,
        'addTransientFor',
      ),
      ServiceLifetime.transient,
      owner: owner,
      isNotifier: isNotifier,
      onDispose: onDispose,
      providerFactory: providerFactory,
    );
    return this;
  }

  /// 注册作用域服务：每个 scope 内单例，scope 销毁时销毁。
  ServiceCollection addScoped<T>(
    T Function(ServiceProvider sp)? factory, {
    String? owner,
    bool isNotifier = false,
    void Function(Object instance)? onDispose,
    Object Function(ServiceProvider sp)? providerFactory,
  }) {
    _register(
      T,
      null,
      _requireFactory(T, factory, 'addScoped'),
      ServiceLifetime.scoped,
      owner: owner,
      isNotifier: isNotifier,
      onDispose: onDispose,
      providerFactory: providerFactory,
    );
    return this;
  }

  /// 双类型注册作用域：语义同 [addSingletonFor]，生命周期按 scope 缓存。
  ServiceCollection addScopedFor<TService, TImpl extends TService>({
    TImpl Function(ServiceProvider sp)? factory,
    TImpl Function()? construct,
    String? owner,
    bool isNotifier = false,
    void Function(Object instance)? onDispose,
    Object Function(ServiceProvider sp)? providerFactory,
  }) {
    _register(
      TService,
      TImpl,
      _requirePairFactory<TImpl>(factory, construct, TService, 'addScopedFor'),
      ServiceLifetime.scoped,
      owner: owner,
      isNotifier: isNotifier,
      onDispose: onDispose,
      providerFactory: providerFactory,
    );
    return this;
  }

  /// 注册已构建的实例（等价于单例，工厂为恒等返回）。
  ///
  /// 与 .NET 不同：容器会按 [onDispose] 回调（或实例实现 [Disposable]）
  /// 清理该实例——Flutter 适配层的 addNotifier/addValue 依赖此行为。
  ServiceCollection addInstance<T>(
    T instance, {
    String? owner,
    bool isNotifier = false,
    bool isBloc = false,
    void Function(Object instance)? onDispose,
    Object Function(ServiceProvider sp)? providerFactory,
  }) {
    _register(
      T,
      null,
      (sp) => instance,
      ServiceLifetime.singleton,
      owner: owner,
      isNotifier: isNotifier,
      isBloc: isBloc,
      onDispose: onDispose,
      providerFactory: providerFactory,
    );
    return this;
  }

  /// 单例注册，仅当 [T] 尚未注册时生效（no-op 并返回 this）。
  ///
  /// 供框架/插件注册可选默认实现而不与宿主冲突（对应 .NET 的
  /// `TryAddSingleton`）。注意：只要存在任一描述符即视为已注册，不会
  /// 用新注册覆盖现有注册。
  ServiceCollection tryAddSingleton<T>(
    T Function(ServiceProvider sp) factory, {
    String? owner,
    bool isNotifier = false,
    bool isBloc = false,
    void Function(Object instance)? onDispose,
    Object Function(ServiceProvider sp)? providerFactory,
  }) {
    if (_hasKey(T)) return this;
    return addSingleton<T>(
      factory,
      owner: owner,
      isNotifier: isNotifier,
      isBloc: isBloc,
      onDispose: onDispose,
      providerFactory: providerFactory,
    );
  }

  /// 双类型单例注册，仅当 TService 与 TImpl 均未注册时生效。
  ///
  /// 比 .NET 的 TryAdd 更严格：同时检查两个键——若 TImpl 已注册而
  /// TService 未注册，直接添加会静默改写 `get<TImpl>()` 的 last-wins，
  /// 故视为"已占用"而 no-op。
  ServiceCollection tryAddSingletonFor<TService, TImpl extends TService>({
    TImpl Function(ServiceProvider sp)? factory,
    TImpl Function()? construct,
    String? owner,
    bool isNotifier = false,
    bool isBloc = false,
    void Function(Object instance)? onDispose,
    Object Function(ServiceProvider sp)? providerFactory,
  }) {
    if (_hasKey(TService) || _hasKey(TImpl)) return this;
    return addSingletonFor<TService, TImpl>(
      factory: factory,
      construct: construct,
      owner: owner,
      isNotifier: isNotifier,
      isBloc: isBloc,
      onDispose: onDispose,
      providerFactory: providerFactory,
    );
  }

  /// 瞬态注册，仅当 [T] 尚未注册时生效。
  ServiceCollection tryAddTransient<T>(
    T Function(ServiceProvider sp) factory, {
    String? owner,
    bool isNotifier = false,
    void Function(Object instance)? onDispose,
    Object Function(ServiceProvider sp)? providerFactory,
  }) {
    if (_hasKey(T)) return this;
    return addTransient<T>(
      factory,
      owner: owner,
      isNotifier: isNotifier,
      onDispose: onDispose,
      providerFactory: providerFactory,
    );
  }

  /// 双类型瞬态注册，仅当两个键均未注册时生效。
  ServiceCollection tryAddTransientFor<TService, TImpl extends TService>({
    TImpl Function(ServiceProvider sp)? factory,
    TImpl Function()? construct,
    String? owner,
    bool isNotifier = false,
    void Function(Object instance)? onDispose,
    Object Function(ServiceProvider sp)? providerFactory,
  }) {
    if (_hasKey(TService) || _hasKey(TImpl)) return this;
    return addTransientFor<TService, TImpl>(
      factory: factory,
      construct: construct,
      owner: owner,
      isNotifier: isNotifier,
      onDispose: onDispose,
      providerFactory: providerFactory,
    );
  }

  /// 作用域注册，仅当 [T] 尚未注册时生效。
  ServiceCollection tryAddScoped<T>(
    T Function(ServiceProvider sp) factory, {
    String? owner,
    bool isNotifier = false,
    void Function(Object instance)? onDispose,
    Object Function(ServiceProvider sp)? providerFactory,
  }) {
    if (_hasKey(T)) return this;
    return addScoped<T>(
      factory,
      owner: owner,
      isNotifier: isNotifier,
      onDispose: onDispose,
      providerFactory: providerFactory,
    );
  }

  /// 双类型作用域注册，仅当两个键均未注册时生效。
  ServiceCollection tryAddScopedFor<TService, TImpl extends TService>({
    TImpl Function(ServiceProvider sp)? factory,
    TImpl Function()? construct,
    String? owner,
    bool isNotifier = false,
    void Function(Object instance)? onDispose,
    Object Function(ServiceProvider sp)? providerFactory,
  }) {
    if (_hasKey(TService) || _hasKey(TImpl)) return this;
    return addScopedFor<TService, TImpl>(
      factory: factory,
      construct: construct,
      owner: owner,
      isNotifier: isNotifier,
      onDispose: onDispose,
      providerFactory: providerFactory,
    );
  }

  /// 类型是否已作为任一描述符的解析键存在。
  bool _hasKey(Type type) => _descriptors.any((d) => d.keys.contains(type));

  void _register<T>(
    Type serviceType,
    Type? implType,
    T Function(ServiceProvider sp) factory,
    ServiceLifetime lifetime, {
    String? owner,
    bool isNotifier = false,
    bool isBloc = false,
    void Function(Object instance)? onDispose,
    Object Function(ServiceProvider sp)? providerFactory,
  }) {
    _descriptors.add(
      ServiceDescriptor<T>(
        lifetime: lifetime,
        factory: factory,
        type: serviceType,
        implType: implType,
        owner: _viewOwner ?? owner,
        isNotifier: isNotifier,
        isBloc: isBloc,
        onDispose: onDispose,
        providerFactory: providerFactory,
        registrationOrder: _counter.next(),
      ),
    );
  }

  /// 单类型注册的工厂校验（null 工厂抛错，保持旧语义）。
  static T Function(ServiceProvider sp) _requireFactory<T>(
    Type type,
    T Function(ServiceProvider sp)? factory,
    String method,
  ) {
    if (factory == null) {
      throw InvalidServiceRegistrationException(
        '$method: 类型 $type 的工厂不能为 null',
      );
    }
    return factory;
  }

  /// 双类型注册的工厂校验：factory 与 construct 恰好给一个。
  static TImpl Function(ServiceProvider sp) _requirePairFactory<TImpl>(
    TImpl Function(ServiceProvider sp)? factory,
    TImpl Function()? construct,
    Type serviceType,
    String method,
  ) {
    if (factory != null && construct != null) {
      throw InvalidServiceRegistrationException(
        '$method: factory 与 construct 不能同时提供（服务类型 $serviceType）',
      );
    }
    if (factory != null) return factory;
    if (construct != null) return (sp) => construct();
    throw InvalidServiceRegistrationException(
      '$method: 必须提供 factory 或 construct 之一（服务类型 $serviceType）',
    );
  }

  /// 构建 provider；同一类型可注册多次，get 时 last-wins。
  ///
  /// [validateScopes] 为 true 时，从根 provider 解析 scoped 服务抛
  /// [ScopedResolutionFromRootException]（.NET 开发期默认行为）。
  ServiceProvider build({bool validateScopes = false}) =>
      ServiceProvider.root(_descriptors, validateScopes: validateScopes);

  /// 所有描述符的不可变快照。
  List<ServiceDescriptor<dynamic>> get descriptors =>
      List.unmodifiable(_descriptors);

  /// 移除某 owner 的全部描述符（加载失败回滚 / 卸载清理时使用）。
  void removeOwner(String ownerId) {
    _descriptors.removeWhere((d) => d.owner == ownerId);
  }

  /// 已注册的描述符数量。
  int get count => _descriptors.length;
}

/// 实例级注册计数器：优先级平局时的破平依据，杜绝全局可变状态。
class _OrderCounter {
  int _value = 0;
  int next() => _value++;
}
