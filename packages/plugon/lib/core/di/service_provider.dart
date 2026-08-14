import 'disposable.dart';
import 'exceptions.dart';
import 'service_descriptor.dart';
import 'service_lifetime.dart';

/// .NET 风格的 DI 容器：由 ServiceCollection.build 构建，按需懒解析。
///
/// 解析键为**注册时的静态类型**（精确匹配，不做子类型解析）：
/// `get<T>()` 只命中注册为 `T` 的描述符。
///
/// 同一类型允许多次注册（.NET 语义）：
/// - `get<T>()` 返回**最后一个**注册的实例（last-wins）；
/// - `getAll<T>()` 返回全部实例（按注册序，对应 .NET 的 `IEnumerable<T>`）；
/// - 双类型注册（`addXxxFor<TService, TImpl>`）时 `TImpl` 是别名键，
///   与 `TService` 解析到同一实例。
///
/// 生命周期语义：
/// - singleton：首次解析创建，缓存于根 provider（所有 scope 共享）；
///   **工厂收到的是根 provider**——从作用域内首次解析单例时，工厂内
///   `sp.get` 解析 scoped 服务命中根级缓存，杜绝跨代捕获。
/// - transient：每次解析创建新实例；实现 [Disposable] 或带 onDispose 的
///   实例被当前作用域追踪，作用域销毁时逆创建序清理。
/// - scoped：按 scope 缓存，scope 销毁时销毁；从根解析时退化为根级实例
///   （build(validateScopes: true) 可开启硬性报错）。
///
/// 循环依赖（工厂内经 `sp.get` 间接依赖自身）在栈溢出前抛
/// [CircularDependencyException]；销毁按 .NET 的逆创建序进行。
class ServiceProvider {
  ServiceProvider._(
    this._descriptors,
    this._byType,
    this._singletonCache,
    this._scopedCache,
    this._root,
    this._validateScopes,
  );

  /// 创建根 provider（singleton 缓存的唯一持有者）。
  ///
  /// [validateScopes] 为 true 时，从根解析 scoped 服务抛
  /// [ScopedResolutionFromRootException]。
  factory ServiceProvider.root(
    List<ServiceDescriptor<dynamic>> descriptors, {
    bool validateScopes = false,
  }) => ServiceProvider._(
    descriptors,
    _groupByType(descriptors),
    {},
    {},
    null,
    validateScopes,
  );

  /// 创建子作用域：共享根的单例缓存与描述符表，
  /// scoped 实例按作用域独立缓存，销毁时从根的活跃列表移除。
  ServiceProvider createScope() {
    final root = _root ?? this;
    final scope = ServiceProvider._(
      _descriptors,
      _byType,
      _singletonCache,
      {},
      root,
      root._validateScopes,
    );
    root._scopes.add(scope);
    return scope;
  }

  /// 描述符表（根与 scope 共享同一张表，disposeOwner 的移除对所有作用域可见）。
  final List<ServiceDescriptor<dynamic>> _descriptors;

  /// 类型 → 描述符列表（注册序；根与 scope 共享同一 map 对象）。
  final Map<Type, List<ServiceDescriptor<dynamic>>> _byType;

  /// 单例缓存（所有 scope 共享同一 map；按描述符身份键控，
  /// 双类型注册的别名键自然共享同一缓存条目）。
  final Map<ServiceDescriptor<dynamic>, Object> _singletonCache;

  /// 本作用域的 scoped 缓存（描述符身份键控）。
  final Map<ServiceDescriptor<dynamic>, Object> _scopedCache;

  /// 所属根；根自身为 null。
  final ServiceProvider? _root;

  /// validateScopes 开关（根决定，scope 继承）。
  final bool _validateScopes;

  /// 根持有的活跃子作用域列表（仅根有意义）。
  final List<ServiceProvider> _scopes = [];

  /// 本 provider 的创建序追踪表：可清理的 scoped + transient 实例
  /// （实现 [Disposable] 或描述符带 onDispose），销毁时逆序。
  final List<({ServiceDescriptor<dynamic> descriptor, Object instance})>
  _tracked = [];

  /// 解析栈（循环检测；"栈 = 真正执行工厂的 provider 的栈"——
  /// 单例整体委托根执行，见 [_resolve]）。
  final List<ServiceDescriptor<dynamic>> _resolving = [];

  bool _disposed = false;

  /// 解析服务；未注册抛 [ServiceNotFoundException]。
  ///
  /// 同一类型多次注册时返回最后一个注册的实例（last-wins，.NET 语义）。
  T get<T>() {
    _checkUsable();
    final list = _byType[T];
    if (list == null || list.isEmpty) {
      throw ServiceNotFoundException(T);
    }
    return _resolve(list.last) as T;
  }

  /// 解析服务；未注册返回 null（工厂抛出的异常照常传播）。
  ///
  /// 与 [get] 走同一解析路径：单例返回缓存实例，绝不新建。
  T? tryGet<T>() {
    _checkUsable();
    final list = _byType[T];
    if (list == null || list.isEmpty) return null;
    return _resolve(list.last) as T;
  }

  /// 解析该类型全部注册的实例（按注册序，对应 .NET 的 `IEnumerable<T>`）。
  ///
  /// 按各自 lifetime 解析：singleton/scoped 返回缓存实例，transient
  /// 每次新建。未注册返回空列表。
  List<T> getAll<T>() {
    _checkUsable();
    final list = _byType[T];
    if (list == null || list.isEmpty) return const [];
    return [for (final d in list) _resolve(d) as T];
  }

  /// 是否注册了该类型（反映注册状态，与是否已实例化无关）。
  bool isRegistered<T>() {
    final list = _byType[T];
    return list != null && list.isNotEmpty;
  }

  /// 全部描述符的不可变快照（供 Flutter 适配层构建 widget provider）。
  List<ServiceDescriptor<dynamic>> get descriptors =>
      List.unmodifiable(_descriptors);

  /// 按 owner 清理：销毁该 owner 已实例化且被容器追踪的实例
  /// （根单例 + 所有活跃 scope 的 scoped/可追踪 transient），
  /// 并移除其描述符。幂等；仅销毁实际实例化的实例。
  void disposeOwner(String ownerId) {
    final root = _root;
    if (root != null) {
      root.disposeOwner(ownerId);
      return;
    }
    _disposeOwnedFromCache(_singletonCache, ownerId);
    _disposeOwnedScope(this, ownerId);
    void disposeOwnedScoped(ServiceProvider scope) =>
        _disposeOwnedScope(scope, ownerId);
    List.of(_scopes).forEach(disposeOwnedScoped);
    _descriptors.removeWhere((d) => d.owner == ownerId);
    _byType
      ..clear()
      ..addAll(_groupByType(_descriptors));
  }

  /// 销毁本作用域：销毁本作用域的 scoped/transient 实例并从根的活跃列表
  /// 移除。共享单例不受影响。
  void dispose() {
    final root = _root;
    if (root == null) {
      // 根：先各活跃 scope（各自逆序），再根自身 scoped/transient，最后单例
      List.of(_scopes).forEach(_disposeScope);
      _scopes.clear();
      _disposeScope(this);
      void disposeSingleton(ServiceDescriptor<dynamic> d) =>
          _disposeCached(_singletonCache, d);
      List.of(_singletonCache.keys).reversed.forEach(disposeSingleton);
    } else {
      _disposeScope(this);
      root._scopes.remove(this);
    }
  }

  /// 解析单个描述符；统一解析入口。
  ///
  /// 单例**整体委托根执行**（工厂收根 provider、入根解析栈、走根缓存）——
  /// 保证"解析栈 = 执行工厂的 provider 的栈"，跨 scope/根循环检测
  /// 无误报无漏报；scoped/transient 在请求方执行。
  Object _resolve(ServiceDescriptor<dynamic> d) {
    switch (d.lifetime) {
      case ServiceLifetime.singleton:
        final root = _root;
        if (root != null) return root._resolve(d);
        return _resolveCached(d, _singletonCache);
      case ServiceLifetime.transient:
        return _createAndTrack(d);
      case ServiceLifetime.scoped:
        if (_root == null && _validateScopes) {
          throw ScopedResolutionFromRootException(d.type);
        }
        return _resolveCached(d, _scopedCache);
    }
  }

  /// 解析缓存型实例（singleton/scoped）：命中返回，未命中创建并缓存。
  Object _resolveCached(
    ServiceDescriptor<dynamic> d,
    Map<ServiceDescriptor<dynamic>, Object> cache,
  ) {
    if (cache.containsKey(d)) return cache[d]!;
    final instance = _createAndTrack(d);
    cache[d] = instance;
    return instance;
  }

  /// 执行工厂：循环检测入栈 → 执行 → 追踪 → 出栈。
  /// 工厂抛错时异常照常传播且不缓存（可重试），栈必定已清空。
  Object _createAndTrack(ServiceDescriptor<dynamic> d) {
    _enter(d);
    try {
      final instance = d.factory(this);
      _trackIfNeeded(d, instance);
      return instance;
    } finally {
      _resolving.removeLast();
    }
  }

  /// 循环检测：同描述符已在解析栈中即抛 [CircularDependencyException]。
  void _enter(ServiceDescriptor<dynamic> d) {
    if (_resolving.contains(d)) {
      throw CircularDependencyException([
        for (final e in _resolving) e.type,
        d.type,
      ]);
    }
    _resolving.add(d);
  }

  /// 可清理实例（Disposable / 带 onDispose）进入追踪表；单例不追踪
  /// （单例由 [_singletonCache] 独立管理）。
  void _trackIfNeeded(ServiceDescriptor<dynamic> d, Object instance) {
    if (d.lifetime == ServiceLifetime.singleton) return;
    if (d.onDispose != null || instance is Disposable) {
      _tracked.add((descriptor: d, instance: instance));
    }
  }

  /// 从单例缓存移除并清理 [ownerId] 拥有的实例。
  void _disposeOwnedFromCache(
    Map<ServiceDescriptor<dynamic>, Object> cache,
    String ownerId,
  ) {
    final owned = [
      for (final d in cache.keys)
        if (d.owner == ownerId) d,
    ];
    void disposeOwned(ServiceDescriptor<dynamic> d) => _disposeCached(cache, d);
    owned.reversed.forEach(disposeOwned);
  }

  /// 清理 [scope] 中属于 [ownerId] 的实例：追踪表逆序销毁 +
  /// 不可追踪 scoped 实例从缓存移除。
  void _disposeOwnedScope(ServiceProvider scope, String ownerId) {
    final owned = [
      for (final e in scope._tracked)
        if (e.descriptor.owner == ownerId) e,
    ];
    owned.reversed.forEach(scope._disposeTrackedEntry);
    scope._scopedCache.removeWhere((d, _) => d.owner == ownerId);
  }

  /// 销毁单个追踪条目（从缓存与追踪表移除后执行清理）。
  void _disposeTrackedEntry(
    ({ServiceDescriptor<dynamic> descriptor, Object instance}) entry,
  ) {
    _scopedCache.remove(entry.descriptor);
    _tracked.remove(entry);
    _disposeInstance(entry.descriptor, entry.instance);
  }

  /// 销毁整个 scope：追踪表逆序清理、清空 scoped 缓存、标记失效。
  void _disposeScope(ServiceProvider scope) {
    scope._disposeTracked();
    scope._scopedCache.clear();
    scope._disposed = true;
  }

  /// 逆创建序销毁本 provider 追踪的全部实例。
  void _disposeTracked() {
    for (final e in _tracked.reversed) {
      _disposeInstance(e.descriptor, e.instance);
    }
    _tracked.clear();
  }

  /// 从缓存移除实例并执行清理：优先 onDispose 回调，否则若实现
  /// [Disposable] 则调用其 dispose。
  void _disposeCached(
    Map<ServiceDescriptor<dynamic>, Object> cache,
    ServiceDescriptor<dynamic> d,
  ) {
    final instance = cache.remove(d);
    if (instance == null) return;
    _disposeInstance(d, instance);
  }

  /// 执行实例清理：优先 onDispose 回调，否则若实现 [Disposable]
  /// 则调用其 dispose。
  void _disposeInstance(ServiceDescriptor<dynamic> d, Object instance) {
    final onDispose = d.onDispose;
    if (onDispose != null) {
      onDispose(instance);
    } else if (instance is Disposable) {
      instance.dispose();
    }
  }

  void _checkUsable() {
    if (_disposed) {
      throw StateError('ServiceProvider 已销毁，无法再解析服务');
    }
  }

  /// 按描述符的解析键分组建表（注册序；别名键与主键指向同一描述符）。
  static Map<Type, List<ServiceDescriptor<dynamic>>> _groupByType(
    List<ServiceDescriptor<dynamic>> descriptors,
  ) {
    final byType = <Type, List<ServiceDescriptor<dynamic>>>{};
    for (final d in descriptors) {
      for (final key in d.keys) {
        byType.putIfAbsent(key, () => []).add(d);
      }
    }
    return byType;
  }
}
