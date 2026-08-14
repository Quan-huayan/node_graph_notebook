import 'package:flutter/material.dart';
import 'package:provider/single_child_widget.dart';

import 'hooks/hook_registry.dart';
import 'plugin_base.dart';
import 'plugin_context.dart';
import 'plugin_metadata.dart';
import 'service_registry.dart';

/// 插件状态枚举。
enum PluginState {
  /// 未加载。
  unloaded,
  /// 已加载但未启用。
  loaded,
  /// 已启用。
  enabled,
  /// 已禁用。
  disabled,
  /// 加载失败。
  error,
}

/// 插件包装器 —— 持有插件实例及其运行时状态。
class PluginWrapper {
  /// 创建插件包装器。
  PluginWrapper({
    required this.plugin,
    required this.context,
  });

  /// 插件实例。
  final Plugin plugin;

  /// 插件上下文。
  final PluginContext context;

  /// 当前状态。
  PluginState state = PluginState.unloaded;

  /// 是否已启用。
  bool get isEnabled => state == PluginState.enabled;
}

/// 插件管理器 —— 管理插件的完整生命周期。
///
/// 职责：
/// - 加载/卸载插件
/// - 按依赖顺序初始化
/// - 注册插件的服务到 ServiceRegistry
/// - 注册插件的 Bloc 和 Hook
/// - 插件卸载时清理资源
class PluginManager {
  /// 创建插件管理器。
  PluginManager({
    required ServiceRegistry serviceRegistry,
    HookRoleRegistry? hookRegistry,
  }) : _serviceRegistry = serviceRegistry,
       _hookRegistry = hookRegistry;

  final ServiceRegistry _serviceRegistry;
  final HookRoleRegistry? _hookRegistry;

  /// 已加载的插件（按加载顺序）。
  final Map<String, PluginWrapper> _plugins = {};

  /// 获取已加载的插件列表。
  List<PluginWrapper> get loadedPlugins => _plugins.values.toList();

  /// 获取指定插件。
  PluginWrapper? getPlugin(String pluginId) => _plugins[pluginId];

  /// 加载一个插件。
  ///
  /// 按以下步骤执行：
  /// 1. 注册插件声明的服务到 ServiceRegistry
  /// 2. 调用 plugin.onLoad(context)
  /// 3. 注册插件声明的 Hook
  /// 4. 如果默认启用，自动启用
  Future<void> loadPlugin(Plugin plugin) async {
    final pluginId = plugin.metadata.id;

    if (_plugins.containsKey(pluginId)) {
      debugPrint('[PluginManager] Plugin already loaded: $pluginId');
      return;
    }

    debugPrint('[PluginManager] Loading plugin: $pluginId');

    // 1. 创建上下文和包装器
    final context = PluginContext(
      pluginId: pluginId,
      serviceRegistry: _serviceRegistry,
      metadata: plugin.metadata,
    );
    final wrapper = PluginWrapper(plugin: plugin, context: context);
    wrapper.state = PluginState.loaded;

    // 2. 注册服务
    _registerServices(plugin);

    // 3. 调用 onLoad
    await plugin.onLoad(context);

    // 4. 注册 Hook
    _registerHooks(plugin, wrapper);

    // 5. 加入已加载列表
    _plugins[pluginId] = wrapper;

    // 6. 如果默认启用，自动启用
    if (plugin.metadata.enabledByDefault) {
      await enablePlugin(pluginId);
    }

    debugPrint('[PluginManager] ✓ Plugin loaded: $pluginId');
  }

  /// 启用插件。
  Future<void> enablePlugin(String pluginId) async {
    final wrapper = _plugins[pluginId];
    if (wrapper == null) return;
    if (wrapper.isEnabled) return;

    // 确保依赖已启用
    await _ensureDependencies(wrapper.plugin.metadata);

    await wrapper.plugin.onEnable();
    wrapper.state = PluginState.enabled;

    debugPrint('[PluginManager] ✓ Plugin enabled: $pluginId');
  }

  /// 禁用插件。
  Future<void> disablePlugin(String pluginId) async {
    final wrapper = _plugins[pluginId];
    if (wrapper == null) return;
    if (!wrapper.isEnabled) return;

    await wrapper.plugin.onDisable();
    wrapper.state = PluginState.disabled;

    debugPrint('[PluginManager] ✓ Plugin disabled: $pluginId');
  }

  /// 卸载插件（清理服务、Hook、资源）。
  Future<void> unloadPlugin(String pluginId) async {
    final wrapper = _plugins.remove(pluginId);
    if (wrapper == null) return;

    // 先禁用
    if (wrapper.isEnabled) {
      await disablePlugin(pluginId);
    }

    // 调用 onUnload
    await wrapper.plugin.onUnload();

    // 清理服务
    _serviceRegistry.removeByOwner(pluginId);

    // 清理 Hook
    _hookRegistry?.unregisterPluginHooks(pluginId);

    wrapper.state = PluginState.unloaded;

    debugPrint('[PluginManager] ✓ Plugin unloaded: $pluginId');
  }

  /// 生成所有已加载插件的 BlocProvider 列表。
  List<SingleChildWidget> generateBlocProviders() {
    final blocs = <SingleChildWidget>[];
    for (final wrapper in _plugins.values) {
      if (wrapper.state != PluginState.unloaded &&
          wrapper.state != PluginState.error) {
        blocs.addAll(wrapper.plugin.registerBlocs());
      }
    }
    return blocs;
  }

  /// 注册插件的服务到 ServiceRegistry。
  ///
  /// 使用 ServiceRegistration.registerWith 闭包，
  /// 确保泛型类型在注册时正确传递。
  void _registerServices(Plugin plugin) {
    final registrations = plugin.registerServices();
    for (final reg in registrations) {
      reg.registerWith(_serviceRegistry, plugin.metadata.id);
    }

    debugPrint('[PluginManager]   Registered ${registrations.length} services');
  }

  /// 注册插件的 Hook。
  void _registerHooks(Plugin plugin, PluginWrapper wrapper) {
    if (_hookRegistry == null) return;

    final factories = plugin.registerHooks();
    var count = 0;

    for (final factory in factories) {
      final hook = factory();
      _hookRegistry.registerHook(hook, parentPlugin: wrapper);
      count++;
    }

    if (count > 0) {
      debugPrint('[PluginManager]   Registered $count hooks');
    }
  }

  /// 确保插件的依赖已加载并启用。
  Future<void> _ensureDependencies(PluginMetadata metadata) async {
    for (final depId in metadata.dependencies) {
      final dep = _plugins[depId];
      if (dep == null) {
        throw StateError(
          'Dependency "$depId" not loaded for plugin "${metadata.id}"',
        );
      }
      if (!dep.isEnabled) {
        await enablePlugin(depId);
      }
    }
  }

  /// 释放所有资源。
  Future<void> dispose() async {
    final pluginIds = _plugins.keys.toList();
    for (final id in pluginIds) {
      await unloadPlugin(id);
    }
  }
}
