import 'package:flutter/foundation.dart';

import 'service_registry.dart';

/// 服务注册描述符。
///
/// 四种工厂方法对应 ServiceRegistry 的四种注册方法：
/// - `of<T>` → `register<T>`                      (Provider<T>.value)
/// - `notifier<T extends ChangeNotifier>` → `registerNotifier<T>`   (ChangeNotifierProvider<T>.value)
/// - `singleton<T>` → `registerFactory<T>`          (Provider<T>.value)
/// - `notifierFactory<T extends ChangeNotifier>` → `registerNotifierFactory<T>`  (ChangeNotifierProvider<T>.value)
class ServiceRegistration {
  const ServiceRegistration._({
    required this.serviceType,
    this.factory,
    this.instanceValue,
    this.owner,
    required this.registerWith,
  });

  /// 服务类型。
  final Type serviceType;

  /// 可选的工厂函数（用于延迟创建）。
  final dynamic Function(ServiceRegistry)? factory;

  /// 可选的实例值（用于直接注册）。
  final dynamic instanceValue;

  /// 注册者标识。
  final String? owner;

  /// 注册逻辑函数。
  final void Function(ServiceRegistry registry, String? owner) registerWith;

  /// 注册一个实例 → Provider<T>.value。
  static ServiceRegistration of<T>(T instance, {String? owner}) =>
      ServiceRegistration._(
        serviceType: T,
        instanceValue: instance,
        owner: owner,
        registerWith: (r, o) => r.register<T>(instance: instance, owner: o),
      );

  /// 注册一个 ChangeNotifier 实例 → ChangeNotifierProvider<T>.value。
  static ServiceRegistration notifier<T extends ChangeNotifier>(T instance, {String? owner}) =>
      ServiceRegistration._(
        serviceType: T,
        instanceValue: instance,
        owner: owner,
        registerWith: (r, o) => r.registerNotifier<T>(instance: instance, owner: o),
      );

  /// 注册一个工厂 → Provider<T>.value。
  static ServiceRegistration singleton<T>(T Function(ServiceRegistry) factory, {String? owner}) =>
      ServiceRegistration._(
        serviceType: T,
        factory: factory,
        owner: owner,
        registerWith: (r, o) => r.registerFactory<T>(factory: () => factory(r), owner: o),
      );

  /// 注册一个 ChangeNotifier 工厂 → ChangeNotifierProvider<T>.value。
  static ServiceRegistration notifierFactory<T extends ChangeNotifier>(T Function(ServiceRegistry) factory, {String? owner}) =>
      ServiceRegistration._(
        serviceType: T,
        factory: factory,
        owner: owner,
        registerWith: (r, o) => r.registerNotifierFactory<T>(factory: () => factory(r), owner: o),
      );
}
