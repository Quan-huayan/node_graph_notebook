import '../di/service_provider.dart';
import '../extensions/extension_registry.dart';
import 'plugin_metadata.dart';

/// 插件运行时窗口：服务解析 + 元数据 + 扩展注册表。
///
/// 由 PluginManager 在加载时创建并注入 Plugin.onLoad。
class PluginContext {
  /// 构造：上下文不可变。
  PluginContext({
    required this.pluginId,
    required this.metadata,
    required this.services,
    required this.extensions,
  });

  /// 插件 id（与 metadata.id 一致）。
  final String pluginId;

  /// 插件元数据。
  final PluginMetadata metadata;

  /// 全局服务容器（懒构建）；插件间互访服务均通过它。
  final ServiceProvider services;

  /// 全局扩展注册表。
  final ExtensionRegistry extensions;

  /// 解析服务；未注册抛 ServiceNotFoundException。
  T get<T>() => services.get<T>();

  /// 解析服务；未注册返回 null。
  T? tryGet<T>() => services.tryGet<T>();
}
