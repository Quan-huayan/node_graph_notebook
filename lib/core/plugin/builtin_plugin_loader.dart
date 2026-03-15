import 'package:flutter/foundation.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/sidebarNode/sidebar_plugin.dart';
import 'plugin.dart';
import 'ui_hooks/hook_registry.dart';
import 'ui_hooks/ui_hook.dart';
import '../../plugins/builtin_plugins/delete/delete_plugin.dart';
import '../../plugins/builtin_plugins/layout/layout_plugin.dart';
import '../../plugins/builtin_plugins/folder/folder_plugin.dart';
import '../../plugins/builtin_plugins/ai/ai_integration_plugin.dart';

/// 内置插件加载器
///
/// 负责扫描和加载所有内置插件，并将它们注册到 HookRegistry
class BuiltinPluginLoader {
  BuiltinPluginLoader({
    required PluginManager pluginManager,
    HookRegistry? hookRegistry,
  })  : _pluginManager = pluginManager,
       _hookRegistry = hookRegistry;

  final PluginManager _pluginManager;
  final HookRegistry? _hookRegistry;

  /// 已加载的插件列表
  final List<String> _loadedPlugins = [];

  /// 加载所有内置插件
  ///
  /// 返回成功加载的插件数量
  Future<int> loadAllBuiltinPlugins() async {
    int loadedCount = 0;

    try {
      // 定义所有内置插件
      final builtinPlugins = <UIHook>[
        // 删除功能插件
        DeletePlugin(),

        // 布局功能插件
        LayoutPlugin(),

        // AI 集成插件
        AIIntegrationPlugin(),

        // 侧边栏插件
        SidebarPlugin(),
      ];

      // 定义普通插件
      final builtinRegularPlugins = <dynamic>[
        // 文件夹插件
        FolderPlugin(),
      ];

      // 加载 UI Hook 插件
      for (final plugin in builtinPlugins) {
        try {
          await _loadBuiltinPlugin(plugin);
          _loadedPlugins.add(plugin.metadata.id);
          loadedCount++;

          debugPrint('[BuiltinPluginLoader] ✓ Loaded plugin: ${plugin.metadata.id} v${plugin.metadata.version}');
        } catch (e) {
          debugPrint('[BuiltinPluginLoader] ✗ Failed to load plugin ${plugin.metadata.id}: $e');
          // 继续加载其他插件
        }
      }

      // 普通插件通过插件发现机制加载，这里暂时跳过
      // 注意：普通插件需要通过 PluginDiscoverer 注册后才能加载

      debugPrint('[BuiltinPluginLoader] Summary: Loaded $loadedCount/${builtinPlugins.length + builtinRegularPlugins.length} builtin plugins');
      debugPrint('[BuiltinPluginLoader] - UI Hook plugins: ${builtinPlugins.length}');
      debugPrint('[BuiltinPluginLoader] - Regular plugins: ${builtinRegularPlugins.length}');

      // 如果有 HookRegistry，直接注册 UI Hooks
      if (_hookRegistry != null) {
        _registerUIHooks(builtinPlugins);
      }

    } catch (e) {
      debugPrint('[BuiltinPluginLoader] Error loading builtin plugins: $e');
    }

    return loadedCount;
  }

  /// 加载单个内置插件
  Future<void> _loadBuiltinPlugin(UIHook plugin) async {
    final pluginId = plugin.metadata.id;

    // 检查是否已经加载
    if (_loadedPlugins.contains(pluginId)) {
      debugPrint('[BuiltinPluginLoader] Plugin $pluginId already loaded, skipping');
      return;
    }

    // 初始化插件
    try {
      await plugin.onInit();
      // state 由 Plugin 管理器维护，这里不需要手动设置
    } catch (e) {
      debugPrint('[BuiltinPluginLoader] Error initializing plugin $pluginId: $e');
      rethrow;
    }
  }

  /// 将 UI Hooks 注册到 HookRegistry
  void _registerUIHooks(List<UIHook> plugins) {
    if (_hookRegistry == null) {
      debugPrint('[BuiltinPluginLoader] HookRegistry is null, skipping UI Hook registration');
      return;
    }

    for (final plugin in plugins) {
      try {
        _hookRegistry.registerHook(plugin);
        debugPrint('[BuiltinPluginLoader] ✓ Registered UI Hook: ${plugin.metadata.id} to ${plugin.hookPoint}');
      } catch (e) {
        debugPrint('[BuiltinPluginLoader] ✗ Failed to register UI Hook ${plugin.metadata.id}: $e');
      }
    }
  }

  /// 卸载所有内置插件
  Future<void> unloadAllBuiltinPlugins() async {
    for (final pluginId in _loadedPlugins) {
      try {
        await _pluginManager.unloadPlugin(pluginId);
        debugPrint('[BuiltinPluginLoader] ✓ Unloaded plugin: $pluginId');
      } catch (e) {
        debugPrint('[BuiltinPluginLoader] ✗ Failed to unload plugin $pluginId: $e');
      }
    }

    _loadedPlugins.clear();
  }

  /// 获取已加载的插件列表
  List<String> get loadedPlugins => List.unmodifiable(_loadedPlugins);
}
