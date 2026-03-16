import 'package:flutter/foundation.dart';

import '../../plugins/ai/ai_plugin.dart';
import '../../plugins/ai/ai_settings_hook.dart';
import '../../plugins/ai/ai_toolbar_hook.dart';
import '../../plugins/converter/converter_plugin.dart';
import '../../plugins/converter/converter_toolbar_hook.dart';
import '../../plugins/data_recovery/data_recovery.dart';
import '../../plugins/delete/delete_plugin.dart';
import '../../plugins/folder/folder_plugin.dart';
import '../../plugins/graph/create_node_toolbar_hook.dart';
import '../../plugins/graph/graph_nodes_toolbar_hook.dart';
import '../../plugins/graph/graph_plugin.dart';
import '../../plugins/i18n/i18n_plugin.dart';
import '../../plugins/layout/layout_plugin.dart';
import '../../plugins/layout/layout_toolbar_hook.dart';
import '../../plugins/market/market_toolbar_hook.dart';
import '../../plugins/search/search_plugin.dart';
import '../../plugins/search/search_sidebar_hook.dart';
import '../../plugins/settings/settings_toolbar_hook.dart';
import '../../plugins/sidebarNode/sidebar_plugin.dart';
import 'dependency_resolver.dart';
import 'plugin_discoverer.dart';
import 'plugin_manager.dart';
import 'ui_hooks/hook_registry.dart';
import 'ui_hooks/ui_hook.dart';

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

  /// 所有内置 UI Hook 插件
  final List<UIHookFactory> _builtinUIHookFactories = [
    // 删除功能插件
    DeletePlugin.new,
    // 侧边栏插件
    SidebarPlugin.new,
    // 国际化插件
    I18nPlugin.new,
    // AI工具栏钩子
    AIToolbarHook.new,
    // AI设置钩子
    AISettingsHook.new,
    // 转换器工具栏钩子
    ConverterToolbarHook.new,
    // 图节点工具栏钩子
    GraphNodesToolbarHook.new,
    // 创建节点工具栏钩子
    CreateNodeToolbarHook.new,
    // 布局工具栏钩子
    LayoutToolbarHook.new,
    // 插件市场工具栏钩子
    MarketToolbarHook.new,
    // 搜索侧边栏钩子
    SearchSidebarHook.new,
    // 设置工具栏钩子
    SettingsToolbarHook.new,
  ];

  /// 所有内置普通插件工厂
  final List<PluginFactory> _builtinPluginFactories = [
    // 文件夹插件
    FolderPlugin.new,
    // 图插件
    GraphPlugin.new,
    // 布局插件
    LayoutPlugin.new,
    // 搜索插件
    SearchPlugin.new,
    // 转换器插件
    ConverterPlugin.new,
    // 数据恢复插件
    DataRecoveryPlugin.new,
    // AI 集成插件
    AIIntegrationPlugin.new,
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
    var loadedCount = 0;

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

      debugPrint(
        '[BuiltinPluginLoader] Plugin load order: ${resolution.loadOrder}',
      );

      // 步骤 4：按顺序加载插件
      for (final pluginId in resolution.loadOrder) {
        try {
          await _pluginManager.loadPlugin(pluginId);
          _loadedPlugins.add(pluginId);
          loadedCount++;

          debugPrint('[BuiltinPluginLoader] ✓ Loaded plugin: $pluginId');

          // 如果插件默认启用，自动启用
          final plugin = _pluginManager.getPlugin(pluginId);
          if (plugin != null) {
            debugPrint('[BuiltinPluginLoader] Checking plugin $pluginId:');
            debugPrint('  - enabledByDefault: ${plugin.metadata.enabledByDefault}');
            debugPrint('  - Current state: ${plugin.state}');
            
            if (plugin.metadata.enabledByDefault) {
              try {
                debugPrint('[BuiltinPluginLoader] Attempting to enable plugin: $pluginId');
                await _pluginManager.enablePlugin(pluginId);
                debugPrint('[BuiltinPluginLoader] ✓ Enabled plugin: $pluginId');
                debugPrint('  - New state: ${plugin.state}');
              } catch (e) {
                debugPrint(
                  '[BuiltinPluginLoader] ✗ Failed to enable plugin $pluginId: $e',
                );
                debugPrint('  - Current state after failure: ${plugin.state}');
              }
            } else {
              debugPrint('[BuiltinPluginLoader] Plugin $pluginId is not enabled by default');
            }
          } else {
            debugPrint('[BuiltinPluginLoader] ✗ Plugin $pluginId not found after loading');
          }
        } catch (e) {
          debugPrint(
            '[BuiltinPluginLoader] ✗ Failed to load plugin $pluginId: $e',
          );
          // 继续加载其他插件
        }
      }

      debugPrint(
        '[BuiltinPluginLoader] Summary: Loaded $loadedCount/${allPluginMetadata.length} builtin plugins',
      );

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

    debugPrint(
      '[BuiltinPluginLoader] Registered ${_builtinUIHookFactories.length} UI Hook factories',
    );
    debugPrint(
      '[BuiltinPluginLoader] Registered ${_builtinPluginFactories.length} regular plugin factories',
    );
  }

  /// 将 UI Hooks 注册到 HookRegistry
  void _registerUIHooks() {
    if (_hookRegistry == null) {
      debugPrint(
        '[BuiltinPluginLoader] HookRegistry is null, skipping UI Hook registration',
      );
      return;
    }

    final allPlugins = _pluginManager.getAllPlugins();
    var uiHookCount = 0;
    var enabledHookCount = 0;

    debugPrint('[BuiltinPluginLoader] ===== Starting UI Hook Registration =====');
    debugPrint('[BuiltinPluginLoader] Total plugins loaded: ${allPlugins.length}');

    for (final wrapper in allPlugins) {
      if (wrapper.plugin is UIHook) {
        final uiHook = wrapper.plugin as UIHook;
        try {
          _hookRegistry.registerHook(uiHook);
          uiHookCount++;
          debugPrint(
            '[BuiltinPluginLoader] ✓ Registered UI Hook: ${uiHook.metadata.id} to ${uiHook.hookPoint}',
          );
          debugPrint('    - State: ${uiHook.state}');
          debugPrint('    - Is Enabled: ${uiHook.isEnabled}');
          debugPrint('    - Priority: ${uiHook.priority}');
          
          if (uiHook.isEnabled) {
            enabledHookCount++;
          }
        } catch (e) {
          debugPrint(
            '[BuiltinPluginLoader] ✗ Failed to register UI Hook ${uiHook.metadata.id}: $e',
          );
        }
      }
    }

    debugPrint('[BuiltinPluginLoader] ===== UI Hook Registration Summary =====');
    debugPrint('[BuiltinPluginLoader] Total UI Hooks registered: $uiHookCount');
    debugPrint('[BuiltinPluginLoader] UI Hooks in enabled state: $enabledHookCount');
    debugPrint('[BuiltinPluginLoader] UI Hooks NOT in enabled state: ${uiHookCount - enabledHookCount}');
    debugPrint('[BuiltinPluginLoader] ========================================');
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
        debugPrint(
          '[BuiltinPluginLoader] ✗ Failed to unload plugin $pluginId: $e',
        );
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
