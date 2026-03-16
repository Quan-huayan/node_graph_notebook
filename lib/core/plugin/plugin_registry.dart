import 'plugin.dart';

/// 插件注册表
///
/// 管理所有已加载的插件
class PluginRegistry {
  /// 创建一个新的插件注册表实例。
  PluginRegistry();

  /// 所有已注册的插件
  final Map<String, PluginWrapper> _plugins = {};

  /// 插件 ID 到包装器的映射
  Map<String, PluginWrapper> get plugins => Map.unmodifiable(_plugins);

  /// 检查插件是否已注册
  bool isRegistered(String pluginId) => _plugins.containsKey(pluginId);

  /// 获取插件
  ///
  /// [pluginId] 插件 ID
  /// 如果插件不存在，返回 null
  PluginWrapper? getPlugin(String pluginId) => _plugins[pluginId];

  /// 获取所有插件
  List<PluginWrapper> getAllPlugins() => _plugins.values.toList();

  /// 获取已启用的插件
  List<PluginWrapper> getEnabledPlugins() => _plugins.values.where((p) => p.isEnabled).toList();

  /// 获取已加载但未启用的插件
  List<PluginWrapper> getLoadedPlugins() => _plugins.values
        .where((p) => p.lifecycle.state == PluginState.loaded)
        .toList();

  /// 注册插件
  ///
  /// [wrapper] 插件包装器
  /// 如果插件 ID 已存在，抛出 [PluginAlreadyExistsException]
  void register(PluginWrapper wrapper) {
    final id = wrapper.metadata.id;
    if (_plugins.containsKey(id)) {
      throw PluginAlreadyExistsException(id);
    }
    _plugins[id] = wrapper;
  }

  /// 注销插件
  ///
  /// [pluginId] 插件 ID
  /// 如果插件不存在，抛出 [PluginNotFoundException]
  void unregister(String pluginId) {
    if (!_plugins.containsKey(pluginId)) {
      throw PluginNotFoundException(pluginId);
    }
    _plugins.remove(pluginId);
  }

  /// 按依赖顺序获取插件
  ///
  /// 返回按照依赖关系排序的插件列表
  /// 依赖的插件排在前面
  List<PluginWrapper> getPluginsInDependencyOrder() {
    final visited = <String>{};
    final temp = <String>{};
    final result = <PluginWrapper>[];

    void visit(String pluginId) {
      if (visited.contains(pluginId)) return;
      if (temp.contains(pluginId)) {
        throw CircularDependencyException([...temp, pluginId]);
      }

      temp.add(pluginId);
      final plugin = _plugins[pluginId];
      if (plugin == null) return;

      // 先访问依赖
      plugin.metadata.dependencies.forEach(visit);

      temp.remove(pluginId);
      visited.add(pluginId);
      result.add(plugin);
    }

    _plugins.keys.forEach(visit);

    return result;
  }

  /// 清空所有插件
  void clear() {
    _plugins.clear();
  }

  /// 插件数量
  int get count => _plugins.length;

  /// 已启用插件数量
  int get enabledCount => getEnabledPlugins().length;
}
