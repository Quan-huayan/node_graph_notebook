/// 重复加载同一插件（同 id）时抛出。
class PluginAlreadyLoadedException implements Exception {
  /// 构造：插件 id。
  PluginAlreadyLoadedException(this.pluginId);

  /// 插件 id。
  final String pluginId;

  @override
  String toString() => 'PluginAlreadyLoadedException: 插件 "$pluginId" 已加载';
}

/// 依赖缺失（依赖未加载）时抛出。
class PluginDependencyException implements Exception {
  /// 构造：依赖方与缺失的依赖 id。
  PluginDependencyException(this.pluginId, this.dependencyId);

  /// 依赖方插件 id。
  final String pluginId;

  /// 缺失的依赖插件 id。
  final String dependencyId;

  @override
  String toString() =>
      'PluginDependencyException: 插件 "$pluginId" 的依赖 "$dependencyId" 未加载';
}

/// 检测到依赖循环时抛出（替换曾经的无限递归）。
class PluginDependencyCycleException implements Exception {
  /// 构造：触发检测的插件 id 与检测到的环。
  PluginDependencyCycleException(this.pluginId, this.cycle);

  /// 触发检测的插件 id。
  final String pluginId;

  /// 检测到的依赖环（按遍历顺序）。
  final List<String> cycle;

  @override
  String toString() =>
      'PluginDependencyCycleException: 检测到依赖循环 ${cycle.join(' -> ')}'
      '（起点 "$pluginId"）';
}
