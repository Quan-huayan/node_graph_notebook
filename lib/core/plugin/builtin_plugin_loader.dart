import 'package:flutter/foundation.dart';

import '../../plugins/ai/ai_plugin.dart';
import '../../plugins/converter/converter_plugin.dart';
import '../../plugins/data_recovery/data_recovery.dart';
import '../../plugins/folder/folder_plugin.dart';
import '../../plugins/graph/graph_plugin.dart';
import '../../plugins/i18n/i18n_plugin.dart';
import '../../plugins/layout/layout_plugin.dart';
import '../../plugins/lua/lua_plugin.dart';
import '../../plugins/market/market_plugin.dart';
import '../../plugins/search/search_plugin.dart';
import '../../plugins/settings/settings_plugin.dart';
import 'dependency_resolver.dart';
import 'plugin_base.dart';
import 'plugin_discoverer.dart';
import 'plugin_manager.dart';
import 'ui_hooks/hook_registry.dart';

/// 内置插件加载器
///
/// 负责注册和加载所有内置插件
///
/// **加载流程：**
/// 1. 将所有内置插件工厂注册到 PluginDiscoverer
/// 2. 使用 DependencyResolver 解析插件依赖关系
/// 3. 按照依赖顺序通过 PluginManager 加载插件
/// 4. 自动启用默认启用的插件
/// 5. Hooks 通过 Plugin 的 registerHooks() 方法自动注册
class BuiltinPluginLoader {
  /// 构造函数
  ///
  /// [pluginManager] - 插件管理器
  /// [hookRegistry] - UI Hook 注册表，可选
  BuiltinPluginLoader({
    required PluginManager pluginManager,
    HookRegistry? hookRegistry,
  }) : _pluginManager = pluginManager,
       _hookRegistry = hookRegistry,
       _discoverer = pluginManager.discoverer,
       _dependencyResolver = DependencyResolver();

  final PluginManager _pluginManager;
  final HookRegistry? _hookRegistry;
  final PluginDiscoverer _discoverer;
  final DependencyResolver _dependencyResolver;

  /// 所有内置插件工厂
  final List<PluginFactory> _builtinPluginFactories = [
    // 核心插件
    I18nPlugin.new, // 国际化插件（优先加载，其他插件可能依赖）
    GraphPlugin.new,
    ConverterPlugin.new,
    LayoutPlugin.new,
    SearchPlugin.new,
    AIPlugin.new,
    DataRecoveryPlugin.new,
    FolderPlugin.new,
    SettingsPlugin.new,
    MarketPlugin.new,
    LuaPlugin.new, // Lua脚本插件
  ];

  /// 加载所有内置插件
  ///
  /// 返回成功加载的插件数量
  Future<int> loadAllBuiltinPlugins() async {
    debugPrint('[BuiltinPluginLoader] ===== Starting Built-in Plugin Load =====');
    var loadedCount = 0;

    try {
      // 步骤 1：注册所有内置插件工厂
      _registerBuiltinPluginFactories();

      // 步骤 2：发现所有可用插件
      final allPluginIds = await _discoverer.discoverAvailablePlugins();
      debugPrint(
        '[BuiltinPluginLoader] Discovered ${allPluginIds.length} plugins: $allPluginIds',
      );

      // 步骤 3：解析插件依赖关系
      final allPluginMetadata = (await Future.wait(
        allPluginIds.map(_discoverer.discoverPlugin),
      ))
          .whereType<Plugin>()
          .toList();

      final loadOrder = _dependencyResolver.resolveLoadOrder(allPluginMetadata);
      debugPrint(
        '[BuiltinPluginLoader] Resolved load order: ${loadOrder.map((p) => p.metadata.id).toList()}',
      );

      // 步骤 4：按顺序加载插件
      for (final plugin in loadOrder) {
        try {
          debugPrint('[BuiltinPluginLoader] Loading plugin: ${plugin.metadata.id}');

          await _pluginManager.loadPlugin(plugin.metadata.id);

          // 如果插件默认启用，自动启用
          if (plugin.metadata.enabledByDefault) {
            await _pluginManager.enablePlugin(plugin.metadata.id);
          }

          loadedCount++;
        } catch (e) {
          debugPrint('[BuiltinPluginLoader] ✗ Failed to load plugin ${plugin.metadata.id}: $e');
          // 继续加载其他插件
        }
      }

      debugPrint(
        '[BuiltinPluginLoader] Summary: Loaded $loadedCount/${allPluginMetadata.length} builtin plugins',
      );

      // 步骤 5：调试信息（Hook 现在通过 Plugin 的 registerHooks() 自动注册）
      if (_hookRegistry != null) {
        _debugPrintHooks();
      }
    } catch (e) {
      debugPrint('[BuiltinPluginLoader] Error loading builtin plugins: $e');
    }

    return loadedCount;
  }

  /// 注册所有内置插件工厂
  void _registerBuiltinPluginFactories() {
    // 注册所有插件工厂
    for (final factory in _builtinPluginFactories) {
      final plugin = factory();
      _discoverer.registerFactory(plugin.metadata.id, factory);
    }

    debugPrint(
      '[BuiltinPluginLoader] Registered ${_builtinPluginFactories.length} plugin factories',
    );
  }

  /// 调试打印 Hook 信息
  void _debugPrintHooks() {
    if (_hookRegistry == null) return;

    final totalHooks = _hookRegistry.totalHooks;
    final hookPoints = _hookRegistry.registeredHookPointIds;

    debugPrint('[BuiltinPluginLoader] ===== Hook Registration Summary =====');
    debugPrint('[BuiltinPluginLoader] Total hooks registered: $totalHooks');
    debugPrint('[BuiltinPluginLoader] Hook points used: ${hookPoints.length}');
    for (final pointId in hookPoints) {
      final hooks = _hookRegistry.getHookWrappers(pointId);
      debugPrint('    - $pointId: ${hooks.length} hooks');
    }
    debugPrint('[BuiltinPluginLoader] ========================================');
  }

  /// 卸载所有内置插件
  ///
  /// 按照依赖关系的逆序卸载插件（先卸载依赖者，再卸载被依赖者）
  Future<void> unloadAllBuiltinPlugins() async {
    final allPluginIds = await _discoverer.discoverAvailablePlugins();
    final allPluginMetadata = (await Future.wait(
      allPluginIds.map(_discoverer.discoverPlugin),
    ))
        .whereType<Plugin>()
        .toList();

    final unloadOrder = _dependencyResolver.resolveUnloadOrder(allPluginMetadata);

    for (final plugin in unloadOrder) {
      try {
        await _pluginManager.unloadPlugin(plugin.metadata.id);
        debugPrint('[BuiltinPluginLoader] Unloaded plugin: ${plugin.metadata.id}');
      } catch (e) {
        debugPrint('[BuiltinPluginLoader] Failed to unload plugin ${plugin.metadata.id}: $e');
      }
    }
  }
}
