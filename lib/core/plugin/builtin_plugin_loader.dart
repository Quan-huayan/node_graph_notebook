import 'package:flutter/foundation.dart';
import 'plugin_manager.dart';
import 'plugin_discoverer.dart';
import 'dependency_resolver.dart';
import 'ui_hooks/hook_registry.dart';
import 'ui_hooks/ui_hook.dart';
import '../../plugins/builtin_plugins/delete/delete_plugin.dart';
import '../../plugins/builtin_plugins/layout/layout_plugin.dart';
import '../../plugins/builtin_plugins/folder/folder_plugin.dart';
import '../../plugins/builtin_plugins/ai/ai_integration_plugin.dart';
import '../../plugins/builtin_plugins/sidebarNode/sidebar_plugin.dart';
import '../../plugins/builtin_plugins/graph/graph_plugin.dart';
import '../../plugins/builtin_plugins/search/search_plugin.dart';
import '../../plugins/builtin_plugins/converter/converter_plugin.dart';

/// 内置插件加载器
///
/// 负责注册和加载所有内置插件
///
/// **加载流程：**
/// 1. 将所有内置插件工厂注册到 PluginDiscoverer
/// 2. 使用 DependencyResolver 解析插件依赖关系
/// 3. 按照依赖顺序通过 PluginManager 加载插件
/// 4. 自动启用默认启用的插件
/// 5. 将 UI Hook 插件注册到 HookRegistry
class BuiltinPluginLoader {
  BuiltinPluginLoader({
    required PluginManager pluginManager,
    HookRegistry? hookRegistry,
  })  : _pluginManager = pluginManager,
       _hookRegistry = hookRegistry,
       _discoverer = pluginManager.discoverer,
       _dependencyResolver = DependencyResolver();

  final PluginManager _pluginManager;
  final HookRegistry? _hookRegistry;
  final PluginDiscoverer _discoverer;
  final DependencyResolver _dependencyResolver;

  /// 所有内置 UI Hook 插件
  final List<UIHookFactory> _builtinUIHookFactories = [
    // 删除功能插件
    () => DeletePlugin(),

    // AI 集成插件
    () => AIIntegrationPlugin(),

    // 侧边栏插件
    () => SidebarPlugin(),
  ];

  /// 所有内置普通插件工厂
  final List<PluginFactory> _builtinPluginFactories = [
    // 文件夹插件
    () => FolderPlugin(),
    // 图插件
    () => GraphPlugin(),
    // 布局插件
    () => LayoutPlugin(),
    // 搜索插件
    () => SearchPlugin(),
    // 转换器插件
    () => ConverterPlugin(),
  ];

  /// 已加载的插件列表
  final List<String> _loadedPlugins = [];

  /// 加载所有内置插件
  ///
  /// 返回成功加载的插件数量
  ///
  /// **加载顺序：**
  /// 1. 先注册所有插件工厂到 PluginDiscoverer
  /// 2. 解析依赖关系，确定加载顺序
  /// 3. 按顺序加载并启用插件
  /// 4. 注册 UI Hook 到 HookRegistry
  Future<int> loadAllBuiltinPlugins() async {
    int loadedCount = 0;

    try {
      // 步骤 1：注册所有内置插件工厂
      _registerBuiltinPluginFactories();

      // 步骤 2：获取所有插件的元数据
      final allPluginMetadata = _discoverer.getAllPluginMetadata();

      // 步骤 3：解析依赖关系，确定加载顺序
      final resolution = _dependencyResolver.resolve(allPluginMetadata);

      if (!resolution.isSuccess) {
        debugPrint('[BuiltinPluginLoader] Dependency resolution failed:');
        for (final error in resolution.errors) {
          debugPrint('[BuiltinPluginLoader]   - $error');
        }
        // 继续加载，但可能会失败
      }

      debugPrint('[BuiltinPluginLoader] Plugin load order: ${resolution.loadOrder}');

      // 步骤 4：按顺序加载插件
      for (final pluginId in resolution.loadOrder) {
        try {
          await _pluginManager.loadPlugin(pluginId);
          _loadedPlugins.add(pluginId);
          loadedCount++;

          debugPrint('[BuiltinPluginLoader] ✓ Loaded plugin: $pluginId');

          // 如果插件默认启用，自动启用
          final plugin = _pluginManager.getPlugin(pluginId);
          if (plugin != null && plugin.metadata.enabledByDefault) {
            try {
              await _pluginManager.enablePlugin(pluginId);
              debugPrint('[BuiltinPluginLoader] ✓ Enabled plugin: $pluginId');
            } catch (e) {
              debugPrint('[BuiltinPluginLoader] ✗ Failed to enable plugin $pluginId: $e');
            }
          }
        } catch (e) {
          debugPrint('[BuiltinPluginLoader] ✗ Failed to load plugin $pluginId: $e');
          // 继续加载其他插件
        }
      }

      debugPrint('[BuiltinPluginLoader] Summary: Loaded $loadedCount/${allPluginMetadata.length} builtin plugins');

      // 步骤 5：将 UI Hook 插件注册到 HookRegistry
      if (_hookRegistry != null) {
        _registerUIHooks();
      }

    } catch (e) {
      debugPrint('[BuiltinPluginLoader] Error loading builtin plugins: $e');
    }

    return loadedCount;
  }

  /// 注册所有内置插件工厂
  void _registerBuiltinPluginFactories() {
    // 注册 UI Hook 插件
    for (final factory in _builtinUIHookFactories) {
      final plugin = factory();
      _discoverer.registerFactory(plugin.metadata.id, factory);
    }

    // 注册普通插件
    for (final factory in _builtinPluginFactories) {
      final plugin = factory();
      _discoverer.registerFactory(plugin.metadata.id, factory);
    }

    debugPrint('[BuiltinPluginLoader] Registered ${_builtinUIHookFactories.length} UI Hook factories');
    debugPrint('[BuiltinPluginLoader] Registered ${_builtinPluginFactories.length} regular plugin factories');
  }

  /// 将 UI Hooks 注册到 HookRegistry
  void _registerUIHooks() {
    if (_hookRegistry == null) {
      debugPrint('[BuiltinPluginLoader] HookRegistry is null, skipping UI Hook registration');
      return;
    }

    final allPlugins = _pluginManager.getAllPlugins();
    int uiHookCount = 0;

    for (final wrapper in allPlugins) {
      if (wrapper.plugin is UIHook) {
        final uiHook = wrapper.plugin as UIHook;
        try {
          _hookRegistry.registerHook(uiHook);
          uiHookCount++;
          debugPrint('[BuiltinPluginLoader] ✓ Registered UI Hook: ${uiHook.metadata.id} to ${uiHook.hookPoint}');
        } catch (e) {
          debugPrint('[BuiltinPluginLoader] ✗ Failed to register UI Hook ${uiHook.metadata.id}: $e');
        }
      }
    }

    debugPrint('[BuiltinPluginLoader] Registered $uiHookCount UI Hooks to HookRegistry');
  }

  /// 卸载所有内置插件
  ///
  /// 按照依赖关系的逆序卸载插件（先卸载依赖者，再卸载被依赖者）
  Future<void> unloadAllBuiltinPlugins() async {
    // 按照依赖关系的逆序卸载
    final plugins = _pluginManager.getAllPlugins();
    final loadOrder = plugins.map((p) => p.metadata.id).toList();

    // 逆序卸载
    for (final pluginId in loadOrder.reversed) {
      try {
        await _pluginManager.unloadPlugin(pluginId);
        debugPrint('[BuiltinPluginLoader] ✓ Unloaded plugin: $pluginId');
      } catch (e) {
        debugPrint('[BuiltinPluginLoader] ✗ Failed to unload plugin $pluginId: $e');
      }
    }

    // 清除已注册的插件工厂
    for (final factory in _builtinUIHookFactories) {
      final plugin = factory();
      _discoverer.unregisterFactory(plugin.metadata.id);
    }

    for (final factory in _builtinPluginFactories) {
      final plugin = factory();
      _discoverer.unregisterFactory(plugin.metadata.id);
    }

    _loadedPlugins.clear();
  }

  /// 获取已加载的插件列表
  List<String> get loadedPlugins => List.unmodifiable(_loadedPlugins);
}

/// UI Hook 插件工厂函数类型
///
/// 用于创建 UI Hook 插件实例
typedef UIHookFactory = UIHook Function();
