import 'service_lifetime.dart';
import 'service_provider.dart';

/// 一条服务注册的完整描述。
///
/// 不可变；由 ServiceCollection 在注册时创建。
class ServiceDescriptor<T> {
  /// 构造：不可变描述符（[type] 为注册时的服务类型 TService）。
  ServiceDescriptor({
    required this.lifetime,
    required this.factory,
    required this.type,
    this.implType,
    this.owner,
    this.isNotifier = false,
    this.isBloc = false,
    this.onDispose,
    this.providerFactory,
    required this.registrationOrder,
  });

  /// 服务类型（注册时的 TService；双类型注册的主键）。
  final Type type;

  /// 双类型注册（`addXxxFor<TService, TImpl>`）的实现类型；
  /// 单类型注册为 null。
  final Type? implType;

  /// 生命周期语义。
  final ServiceLifetime lifetime;

  /// 实例工厂：首次（或每次，取决于 lifetime）解析时调用，接收 provider
  /// 以解析自身依赖。禁止在服务字段中保存 sp（会造成 provider 泄漏）。
  final T Function(ServiceProvider sp) factory;

  /// 拥有者：插件 id，或 null 表示宿主所有。
  final String? owner;

  /// 标记该服务是 ChangeNotifier 类（供 Flutter 适配层选择 Provider 类型）。
  /// 纯 Dart 标记，不依赖 Flutter 类型。
  final bool isNotifier;

  /// 标记该服务是 Bloc 类（供 Flutter 适配层的 buildBlocProviders 筛选）。
  /// 纯 Dart 标记。
  final bool isBloc;

  /// 清理回调：仅对已实例化且被容器追踪（singleton/scoped/可追踪
  /// transient）的实例调用。
  final void Function(Object instance)? onDispose;

  /// 类型化 Provider 构造器（供 Flutter 适配层附加）。
  ///
  /// 由 flutter 扩展在注册时捕获（此时泛型 T 静态已知）：
  /// 返回 `Object` 而非 Widget 类型，core 保持零 Flutter 依赖。
  final Object Function(ServiceProvider sp)? providerFactory;

  /// 同 collection 内的注册序号（优先级平局时的破平依据，实例级计数器）。
  final int registrationOrder;

  /// 本描述符的全部解析键：单类型注册为 `[type]`；双类型注册为
  /// `[type, implType]`——通过任一键解析都命中同一描述符（同一实例）。
  List<Type> get keys {
    final impl = implType;
    return [type, if (impl != null) impl];
  }
}
