import 'plugin.dart';

/// 插件发现器
///
/// 负责发现和实例化插件
class PluginDiscoverer {
  /// 已注册的插件工厂
  final Map<String, PluginFactory> _factories = {};

  /// 注册插件工厂
  ///
  /// [pluginId] 插件 ID
  /// [factory] 插件工厂函数
  void registerFactory(String pluginId, PluginFactory factory) {
    _factories[pluginId] = factory;
  }

  /// 批量注册插件工厂
  void registerFactories(Map<String, PluginFactory> factories) {
    _factories.addAll(factories);
  }

  /// 发现可用插件
  ///
  /// 返回所有已注册工厂的插件 ID
  Future<List<String>> discoverAvailablePlugins() async {
    return _factories.keys.toList();
  }

  /// 发现并实例化插件
  ///
  /// [pluginId] 插件 ID
  /// 返回插件实例，如果未找到返回 null
  Future<Plugin?> discoverPlugin(String pluginId) async {
    final factory = _factories[pluginId];
    if (factory == null) return null;

    try {
      return factory();
    } catch (e) {
      throw PluginLoadException(pluginId, e);
    }
  }

  /// 检查插件是否可用
  bool isAvailable(String pluginId) => _factories.containsKey(pluginId);
}

/// 插件工厂函数
///
/// 用于创建插件实例
typedef PluginFactory = Plugin Function();
