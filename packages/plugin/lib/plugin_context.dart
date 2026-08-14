import 'plugin.dart' show Plugin;
import 'plugin_base.dart' show Plugin;
import 'plugin_metadata.dart';
import 'service_registry.dart';

/// 插件上下文。
///
/// 在 [Plugin.onLoad] 时传入，提供对 ServiceRegistry 的访问。
class PluginContext {
  /// 创建插件上下文。
  PluginContext({
    required this.pluginId,
    required ServiceRegistry serviceRegistry,
    required PluginMetadata metadata,
  }) : _serviceRegistry = serviceRegistry,
       _metadata = metadata;

  /// 当前插件 ID。
  final String pluginId;

  final PluginMetadata _metadata;

  /// 当前插件元数据（只读）。
  PluginMetadata get metadata => _metadata;

  final ServiceRegistry _serviceRegistry;

  /// 获取服务（类型安全）。
  T get<T>() => _serviceRegistry.get<T>();

  /// 尝试获取服务。
  T? tryGet<T>() => _serviceRegistry.tryGet<T>();
}
