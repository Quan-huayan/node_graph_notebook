import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// 服务未找到异常。
class ServiceNotFoundException implements Exception {
  /// 创建服务未找到异常。
  ServiceNotFoundException(this.typeName);

  /// 未找到的服务类型名称。
  final String typeName;
  @override
  String toString() =>
      "ServiceNotFoundException: No service for type '$typeName' has been registered.";
}

/// 服务注册表 — 类型安全的 DI 容器。
///
/// 两种注册方式：
/// - `register` → Provider<T>.value        (T 任意)
/// - `registerNotifier` → ChangeNotifierProvider<T>.value  (T extends ChangeNotifier)
///
/// 闭包捕获泛型，generateProviders() 产出类型正确的 Provider。
class ServiceRegistry {

  /// 创建服务注册表。
  ServiceRegistry();
  final Map<Type, dynamic> _instances = {};
  final List<_ProviderEntry> _providerEntries = [];

  /// 注册一个服务实例（Provider<T>.value）。
  void register<T>({required T instance, String? owner}) {
    _instances[T] = instance;
    _providerEntries.add(_ProviderEntry(
      owner: owner,
      create: () => Provider<T>.value(value: instance),
    ));
  }

  /// 注册一个 ChangeNotifier 服务（ChangeNotifierProvider<T>.value）。
  void registerNotifier<T extends ChangeNotifier>({required T instance, String? owner}) {
    _instances[T] = instance;
    _providerEntries.add(_ProviderEntry(
      owner: owner,
      create: () => ChangeNotifierProvider<T>.value(value: instance),
    ));
  }

  /// 注册一个工厂（Provider<T>.value）。
  void registerFactory<T>({required T Function() factory, String? owner}) {
    final instance = factory();
    _instances[T] = instance;
    _providerEntries.add(_ProviderEntry(
      owner: owner,
      create: () => Provider<T>.value(value: instance),
    ));
  }

  /// 注册一个 ChangeNotifier 工厂（ChangeNotifierProvider<T>.value）。
  void registerNotifierFactory<T extends ChangeNotifier>({required T Function() factory, String? owner}) {
    final instance = factory();
    _instances[T] = instance;
    _providerEntries.add(_ProviderEntry(
      owner: owner,
      create: () => ChangeNotifierProvider<T>.value(value: instance),
    ));
  }

  /// 获取指定类型的服务实例。
  T get<T>() => _instances[T] as T;

  /// 尝试获取指定类型的服务实例（不存在时返回 null）。
  T? tryGet<T>() => _instances[T] as T?;

  /// 检查指定类型的服务是否已注册。
  bool isRegistered<T>() => _instances.containsKey(T);

  /// 生成所有已注册服务的 Provider 列表。
  List<SingleChildWidget> generateProviders() =>
      _providerEntries.map((e) => e.create()).toList();

  /// 移除指定所有者注册的所有服务。
  void removeByOwner(String owner) {
    _providerEntries.removeWhere((e) => e.owner == owner);
  }

  /// 清空所有已注册的服务。
  void clear() {
    _instances.clear();
    _providerEntries.clear();
  }

  /// 已注册服务的数量。
  int get serviceCount => _providerEntries.length;
}

class _ProviderEntry {
  _ProviderEntry({this.owner, required this.create});
  final String? owner;
  final SingleChildWidget Function() create;
}
