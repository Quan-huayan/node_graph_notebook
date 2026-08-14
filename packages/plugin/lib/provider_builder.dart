import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'service_registry.dart';

/// 从 [ServiceRegistry] 构建 Provider Tree。
///
/// 将 ServiceRegistry 中所有已注册的服务和 Bloc 转换为
/// Flutter Provider Widget，嵌入到 Widget Tree 中。
///
/// 类型安全：每个 Provider 的泛型由注册时的闭包保证，不存在类型擦除。
///
/// 使用方式：
/// ```dart
/// PluginProviderTree(
///   serviceRegistry: registry,
///   blocProviders: pluginManager.generateBlocProviders(),
///   child: MaterialApp(home: HomePage()),
/// )
/// ```
class PluginProviderTree extends StatelessWidget {
  /// 从 ServiceRegistry 和 Bloc 列表构建 Provider Tree。
  const PluginProviderTree({
    super.key,
    required this.serviceRegistry,
    this.blocProviders = const [],
    this.extraProviders = const [],
    required this.child,
  });

  /// 服务注册表。
  final ServiceRegistry serviceRegistry;

  /// Bloc Provider 列表（由 PluginManager.generateBlocProviders() 生成）。
  final List<SingleChildWidget> blocProviders;

  /// 额外的 Provider（如 PluginManager 自身、全局状态等）。
  final List<SingleChildWidget> extraProviders;

  /// 子 Widget。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final serviceProviders = serviceRegistry.generateProviders();

    final allProviders = <SingleChildWidget>[
      ...serviceProviders,
      ...blocProviders,
      ...extraProviders,
    ];

    if (allProviders.isEmpty) {
      return child;
    }

    return MultiProvider(
      providers: allProviders,
      child: child,
    );
  }
}
