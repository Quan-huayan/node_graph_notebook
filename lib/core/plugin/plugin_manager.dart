import 'dart:async';
import 'package:flutter/foundation.dart';
import 'plugin.dart';
import '../commands/command_bus.dart';
import '../events/app_events.dart';

/// 插件管理器接口
abstract class IPluginManager {
  /// 加载插件
  Future<void> loadPlugin(String pluginId);

  /// 卸载插件
  Future<void> unloadPlugin(String pluginId);

  /// 启用插件
  Future<void> enablePlugin(String pluginId);

  /// 禁用插件
  Future<void> disablePlugin(String pluginId);

  /// 获取插件
  PluginWrapper? getPlugin(String pluginId);

  /// 获取所有插件
  List<PluginWrapper> getAllPlugins();

  /// 发现并加载所有插件
  Future<void> discoverAndLoadPlugins();
}

/// 插件管理器实现
///
/// 管理插件的生命周期、依赖关系和加载顺序
class PluginManager implements IPluginManager {
  PluginManager({
    required CommandBus commandBus,
    AppEventBus? eventBus,
    PluginDiscoverer? discoverer,
  })  : _commandBus = commandBus,
        _eventBus = eventBus,
        _discoverer = discoverer ?? PluginDiscoverer();

  final CommandBus _commandBus;
  final AppEventBus? _eventBus;
  final PluginDiscoverer _discoverer;
  final PluginRegistry _registry = PluginRegistry();

  /// 插件注册表（只读访问）
  PluginRegistry get registry => _registry;

  /// 应用版本（用于插件兼容性检查）
  String appVersion = '1.0.0';

  @override
  Future<void> loadPlugin(String pluginId) async {
    // 检查是否已加载
    if (_registry.isRegistered(pluginId)) {
      throw PluginAlreadyExistsException(pluginId);
    }

    // 发现插件
    final plugin = await _discoverer.discoverPlugin(pluginId);
    if (plugin == null) {
      throw PluginNotFoundException(pluginId);
    }

    // 检查版本兼容性
    if (!plugin.metadata.isCompatibleWith(appVersion)) {
      throw PluginVersionException(
        pluginId,
        plugin.metadata.version,
        appVersion,
      );
    }

    // 创建插件上下文
    final context = PluginContext(
      pluginId: pluginId,
      commandBus: _commandBus,
      eventBus: _eventBus,
      logger: PluginLogger(pluginId),
    );

    // 创建生命周期管理器
    final lifecycle = PluginLifecycleManager(plugin);

    // 创建包装器
    final wrapper = PluginWrapper(plugin, context, lifecycle);

    // 注册到注册表
    _registry.register(wrapper);

    // 调用 onLoad
    try {
      await lifecycle.transitionTo(
        PluginState.loaded,
        () => plugin.onLoad(context),
      );
    } catch (e) {
      // 加载失败，从注册表移除
      _registry.unregister(pluginId);
      throw PluginLoadException(pluginId, e);
    }
  }

  @override
  Future<void> unloadPlugin(String pluginId) async {
    final wrapper = _registry.getPlugin(pluginId);
    if (wrapper == null) {
      throw PluginNotFoundException(pluginId);
    }

    // 如果插件已启用，先禁用
    if (wrapper.isEnabled) {
      await disablePlugin(pluginId);
    }

    // 调用 onUnload
    try {
      await wrapper.lifecycle.transitionTo(
        PluginState.unloaded,
        () => wrapper.plugin.onUnload(),
      );
    } catch (e) {
      throw PluginUnloadException(pluginId, e);
    } finally {
      // 从注册表移除
      _registry.unregister(pluginId);
    }
  }

  @override
  Future<void> enablePlugin(String pluginId) async {
    final wrapper = _registry.getPlugin(pluginId);
    if (wrapper == null) {
      throw PluginNotFoundException(pluginId);
    }

    if (wrapper.isEnabled) {
      return; // 已启用
    }

    // 检查依赖
    await _ensureDependencies(wrapper);

    // 调用 onEnable
    try {
      await wrapper.lifecycle.transitionTo(
        PluginState.enabled,
        () => wrapper.plugin.onEnable(),
      );
    } catch (e) {
      throw PluginEnableException(pluginId, e);
    }
  }

  @override
  Future<void> disablePlugin(String pluginId) async {
    final wrapper = _registry.getPlugin(pluginId);
    if (wrapper == null) {
      throw PluginNotFoundException(pluginId);
    }

    if (!wrapper.isEnabled) {
      return; // 已禁用
    }

    // 调用 onDisable
    try {
      await wrapper.lifecycle.transitionTo(
        PluginState.disabled,
        () => wrapper.plugin.onDisable(),
      );
    } catch (e) {
      throw PluginDisableException(pluginId, e);
    }
  }

  @override
  PluginWrapper? getPlugin(String pluginId) => _registry.getPlugin(pluginId);

  @override
  List<PluginWrapper> getAllPlugins() => _registry.getAllPlugins();

  @override
  Future<void> discoverAndLoadPlugins() async {
    final pluginIds = await _discoverer.discoverAvailablePlugins();
    for (final pluginId in pluginIds) {
      try {
        await loadPlugin(pluginId);
      } catch (e) {
        debugPrint('Failed to load plugin $pluginId: $e');
      }
    }
  }

  /// 确保插件的依赖已加载并启用
  Future<void> _ensureDependencies(PluginWrapper wrapper) async {
    for (final depId in wrapper.metadata.dependencies) {
      final dep = _registry.getPlugin(depId);

      if (dep == null) {
        throw MissingDependencyException(wrapper.metadata.id, depId);
      }

      if (!dep.isEnabled) {
        await enablePlugin(depId);
      }
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    // 卸载所有插件
    final plugins = _registry.getAllPlugins();
    for (final plugin in plugins) {
      try {
        await unloadPlugin(plugin.metadata.id);
      } catch (e) {
        debugPrint('Error unloading plugin ${plugin.metadata.id}: $e');
      }
    }
  }
}
