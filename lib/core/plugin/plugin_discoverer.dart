import 'plugin.dart';

/// 插件发现器
///
/// 负责发现和实例化插件
class PluginDiscoverer {
  /// 已注册的插件工厂
  final Map<String, PluginFactory> _factories = {};

  /// 插件元数据缓存
  final Map<String, PluginMetadata> _metadataCache = {};

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
  Future<List<String>> discoverAvailablePlugins() async => _factories.keys.toList();

  /// 发现并实例化插件
  ///
  /// [pluginId] 插件 ID
  /// 返回插件实例，如果未找到返回 null
  Future<Plugin?> discoverPlugin(String pluginId) async {
    final factory = _factories[pluginId];
    if (factory == null) return null;

    try {
      final plugin = factory();
      // 缓存插件元数据
      _metadataCache[pluginId] = plugin.metadata;
      return plugin;
    } catch (e) {
      throw PluginLoadException(pluginId, e);
    }
  }

  /// 检查插件是否可用
  bool isAvailable(String pluginId) => _factories.containsKey(pluginId);

  /// 获取插件元数据
  ///
  /// [pluginId] 插件 ID
  /// 返回插件元数据，如果未找到返回 null
  PluginMetadata? getPluginMetadata(String pluginId) {
    if (_metadataCache.containsKey(pluginId)) {
      return _metadataCache[pluginId];
    }

    // 尝试实例化插件获取元数据
    try {
      final factory = _factories[pluginId];
      if (factory != null) {
        final plugin = factory();
        _metadataCache[pluginId] = plugin.metadata;
        return plugin.metadata;
      }
    } catch (_) {
      // 忽略实例化错误
    }

    return null;
  }

  /// 获取所有插件的元数据
  Map<String, PluginMetadata> getAllPluginMetadata() {
    final metadataMap = <String, PluginMetadata>{};

    for (final pluginId in _factories.keys) {
      final metadata = getPluginMetadata(pluginId);
      if (metadata != null) {
        metadataMap[pluginId] = metadata;
      }
    }

    return metadataMap;
  }

  /// 清除插件元数据缓存
  void clearMetadataCache() {
    _metadataCache.clear();
  }

  /// 注销插件工厂
  ///
  /// [pluginId] 插件 ID
  void unregisterFactory(String pluginId) {
    _factories.remove(pluginId);
    _metadataCache.remove(pluginId);
  }

  /// 清除所有插件工厂
  void clearFactories() {
    _factories.clear();
    _metadataCache.clear();
  }

  /// 获取已注册的插件工厂数量
  int get factoryCount => _factories.length;
}

/// 插件工厂函数
///
/// 用于创建插件实例
typedef PluginFactory = Plugin Function();
