import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:provider/provider.dart';

import '../core/di.dart';

/// ServiceCollection 的 Flutter 扩展：带类型边界的便捷注册 + 类型化
/// Provider 构造器（在注册时捕获泛型 T，运行时无法从 Type 构造泛型 widget）。
extension ServiceCollectionFlutterExt on ServiceCollection {
  /// 注册已构建的 ChangeNotifier 实例并暴露为 widget provider。
  ///
  /// **销毁归属：DI**——注册时挂 onDispose，插件卸载时由容器关闭；
  /// widget 树（ChangeNotifierProvider.value）不会重复关闭。
  void addNotifier<T extends ChangeNotifier>(T instance, {String? owner}) {
    addInstance<T>(
      instance,
      owner: owner,
      isNotifier: true,
      onDispose: (i) => (i as ChangeNotifier).dispose(),
      providerFactory: (sp) =>
          ChangeNotifierProvider<T>.value(value: sp.get<T>()),
    );
  }

  /// 注册 ChangeNotifier 工厂并暴露为 widget provider。
  ///
  /// **销毁归属：widget 树**——ChangeNotifierProvider(create:) 在树卸载时
  /// 关闭实例；DI 不追踪（ChangeNotifier 非 plugon 的 Disposable，且未挂
  /// onDispose，容器不会重复关闭）。
  void addNotifierSingleton<T extends ChangeNotifier>(
    T Function(ServiceProvider sp) factory, {
    String? owner,
  }) {
    addSingleton<T>(
      factory,
      owner: owner,
      isNotifier: true,
      providerFactory: (sp) =>
          ChangeNotifierProvider<T>(create: (_) => sp.get<T>()),
    );
  }

  /// 注册已构建的普通实例并暴露为 widget provider（Provider.value）。
  ///
  /// **销毁归属：DI**——实例实现 [Disposable] 时由容器在卸载时关闭。
  void addValue<T>(T instance, {String? owner}) {
    addInstance<T>(
      instance,
      owner: owner,
      providerFactory: (sp) => Provider<T>.value(value: sp.get<T>()),
    );
  }

  /// 注册普通工厂并暴露为 widget provider（Provider(create:)）。
  ///
  /// **销毁归属：DI**——实例实现 [Disposable] 时由容器在卸载时关闭；
  /// widget 树不关闭（Provider(create:) 仅关闭其自有的 Disposable 类型）。
  void addFactory<T>(T Function(ServiceProvider sp) factory, {String? owner}) {
    addSingleton<T>(
      factory,
      owner: owner,
      providerFactory: (sp) => Provider<T>(create: (_) => sp.get<T>()),
    );
  }
}
