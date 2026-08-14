/// 请求的服务未注册时抛出。
class ServiceNotFoundException implements Exception {
  /// 构造：未注册的服务类型与可选的所有者提示。
  ServiceNotFoundException(this.type, {this.ownerHint});

  /// 未注册的服务类型。
  final Type type;

  /// 可选提示：谁（插件 id）可能曾经拥有该服务。
  final String? ownerHint;

  @override
  String toString() {
    final hint = ownerHint == null ? '' : ' (可能属于已卸载的插件 "$ownerHint")';
    return 'ServiceNotFoundException: 未注册服务 $type$hint';
  }
}

/// 解析过程中检测到循环依赖时抛出。
///
/// 与 .NET 的 "A circular dependency was detected" 对齐：工厂内通过
/// `sp.get` 间接依赖自身（经任一中间服务）时，在栈溢出前报出完整链路。
/// 循环检测按描述符身份进行——双类型注册的别名键（`get<IFoo>` 与
/// `get<Foo>`）命中同一描述符，视为同一节点。
class CircularDependencyException implements Exception {
  /// 构造：循环链路（注册时的服务类型，首尾相同）。
  CircularDependencyException(this.chain);

  /// 循环链路：`[A, B, A]` 表示 A 依赖 B、B 又依赖 A。
  final List<Type> chain;

  @override
  String toString() =>
      'CircularDependencyException: 检测到循环依赖 ${chain.join(' -> ')}';
}

/// 开启 validateScopes 时，从根 provider 解析 scoped 服务抛出。
///
/// scoped 实例应通过 `createScope()` 解析；从根解析会使其退化为根级单例，
/// 可能被单例工厂捕获造成跨代引用。默认关闭（与 .NET 默认行为一致，
/// 允许根解析 scoped）；`ServiceCollection.build(validateScopes: true)`
/// 开启后变为硬性错误。
class ScopedResolutionFromRootException implements Exception {
  /// 构造：被非法解析的 scoped 服务类型。
  ScopedResolutionFromRootException(this.type);

  /// 被非法解析的 scoped 服务类型。
  final Type type;

  @override
  String toString() =>
      'ScopedResolutionFromRootException: scoped 服务 $type 从根 provider 解析'
      '（validateScopes 已开启）——请通过 createScope() 获取作用域后再解析';
}

/// 注册参数非法时抛出（如工厂为 null、双类型注册缺工厂/构造）。
class InvalidServiceRegistrationException implements Exception {
  /// 构造：错误描述信息。
  InvalidServiceRegistrationException(this.message);

  /// 错误描述。
  final String message;

  @override
  String toString() => 'InvalidServiceRegistrationException: $message';
}
