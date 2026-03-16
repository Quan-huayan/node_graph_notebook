import 'plugin_metadata.dart';

/// 依赖解析结果
class DependencyResolutionResult {
  /// 构造函数
  ///
  /// [loadOrder] - 插件加载顺序
  /// [errors] - 解析过程中的错误列表，默认空列表
  const DependencyResolutionResult({
    required this.loadOrder,
    this.errors = const [],
  });

  /// 插件加载顺序（按照依赖关系排序）
  final List<String> loadOrder;

  /// 解析过程中的错误列表
  final List<String> errors;

  /// 是否成功（无错误）
  bool get isSuccess => errors.isEmpty;
}

/// 依赖解析器
///
/// 使用拓扑排序解析插件依赖关系
class DependencyResolver {
  /// 解析插件依赖关系
  ///
  /// [plugins] 所有插件的元数据映射（pluginId -> metadata）
  /// 返回解析结果，包含加载顺序和错误
  DependencyResolutionResult resolve(Map<String, PluginMetadata> plugins) {
    final loadOrder = <String>[];
    final errors = <String>[];
    final visited = <String>{};
    final temp = <String>{};

    void visit(String pluginId) {
      // 检查循环依赖
      if (temp.contains(pluginId)) {
        errors.add('Circular dependency detected involving plugin: $pluginId');
        return;
      }

      // 已访问过
      if (visited.contains(pluginId)) return;

      temp.add(pluginId);

      // 获取插件元数据
      final plugin = plugins[pluginId];
      if (plugin == null) {
        errors.add('Plugin not found: $pluginId');
        temp.remove(pluginId);
        return;
      }

      // 递归访问依赖
      for (final depId in plugin.dependencies) {
        // 检查依赖是否存在
        if (!plugins.containsKey(depId)) {
          errors.add(
            'Plugin "$pluginId" requires missing dependency: "$depId"',
          );
          continue;
        }

        visit(depId);
      }

      temp.remove(pluginId);
      visited.add(pluginId);
      loadOrder.add(pluginId);
    }

    // 访问所有插件
    plugins.keys.forEach(visit);

    return DependencyResolutionResult(loadOrder: loadOrder, errors: errors);
  }

  /// 验证插件版本兼容性
  ///
  /// [plugins] 所有插件的元数据映射
  /// [appVersion] 当前应用版本
  /// 返回不兼容的插件 ID 列表
  List<String> checkCompatibility(
    Map<String, PluginMetadata> plugins,
    String appVersion,
  ) {
    final incompatible = <String>[];

    for (final entry in plugins.entries) {
      if (!entry.value.isCompatibleWith(appVersion)) {
        incompatible.add(entry.key);
      }
    }

    return incompatible;
  }

  /// 检测循环依赖
  ///
  /// [plugins] 所有插件的元数据映射
  /// 返回所有循环依赖路径
  List<List<String>> detectCycles(Map<String, PluginMetadata> plugins) {
    final cycles = <List<String>>[];
    final visited = <String>{};
    final recStack = <String>[];

    void visit(String pluginId, Map<String, List<String>> graph) {
      visited.add(pluginId);
      recStack.add(pluginId);

      for (final dep in graph[pluginId] ?? []) {
        if (recStack.contains(dep)) {
          // 找到循环
          final cycleStart = recStack.indexOf(dep);
          final cycle = <String>[...recStack.sublist(cycleStart), dep];
          cycles.add(cycle);
        } else if (!visited.contains(dep)) {
          visit(dep, graph);
        }
      }

      recStack.removeLast();
    }

    // 构建依赖图
    final graph = <String, List<String>>{};
    for (final entry in plugins.entries) {
      graph[entry.key] = entry.value.dependencies;
    }

    // 访问所有节点
    for (final pluginId in plugins.keys) {
      if (!visited.contains(pluginId)) {
        visit(pluginId, graph);
      }
    }

    return cycles;
  }

  /// 获取插件的传递依赖
  ///
  /// [pluginId] 插件 ID
  /// [plugins] 所有插件的元数据映射
  /// 返回该插件的所有传递依赖（包括间接依赖）
  Set<String> getTransitiveDependencies(
    String pluginId,
    Map<String, PluginMetadata> plugins,
  ) {
    final deps = <String>{};
    final queue = <String>[pluginId];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final plugin = plugins[current];

      if (plugin == null) continue;

      for (final dep in plugin.dependencies) {
        if (!deps.contains(dep)) {
          deps.add(dep);
          queue.add(dep);
        }
      }
    }

    // 移除自己
    deps.remove(pluginId);

    return deps;
  }

  /// 获取依赖某插件的所有插件
  ///
  /// [pluginId] 插件 ID
  /// [plugins] 所有插件的元数据映射
  /// 返回所有直接或间接依赖该插件的其他插件
  Set<String> getDependents(
    String pluginId,
    Map<String, PluginMetadata> plugins,
  ) {
    final dependents = <String>{};

    for (final entry in plugins.entries) {
      if (entry.value.dependencies.contains(pluginId)) {
        dependents..add(entry.key)
        // 递归查找依赖该插件的插件
        ..addAll(getDependents(entry.key, plugins));
      }
    }

    return dependents;
  }
}
