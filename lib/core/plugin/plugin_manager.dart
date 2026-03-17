import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../commands/command_bus.dart';
import '../events/app_events.dart';
import '../execution/execution_engine.dart';
import '../execution/task_registry.dart';
import '../repositories/graph_repository.dart';
import '../repositories/node_repository.dart';
import '../services/infrastructure/settings_registry.dart';
import '../services/infrastructure/storage_path_service.dart';
import '../services/infrastructure/theme_registry.dart';
import 'api/api_registry.dart';
import 'plugin.dart';
import 'ui_hooks/hook_context.dart';
import 'ui_hooks/hook_lifecycle.dart';
import 'ui_hooks/hook_registry.dart';

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
/// 支持 API 导出/导入系统，允许插件间通信
/// 统一管理插件提供的 Service 依赖注入
class PluginManager implements IPluginManager {
  /// 创建一个新的插件管理器实例。
  ///
  /// [commandBus] 命令总线，用于执行写操作
  /// [eventBus] 事件总线，用于订阅数据变化
  /// [nodeRepository] 节点仓库，用于读取节点数据
  /// [graphRepository] 图仓库，用于读取图数据
  /// [executionEngine] 执行引擎，用于 CPU 密集型任务
  /// [discoverer] 插件发现器，用于发现和实例化插件
  /// [serviceRegistry] 服务注册表，用于管理插件提供的服务
  /// [taskRegistry] 任务注册表，用于管理插件注册的任务类型
  /// [settingsRegistry] 设置注册表，用于管理插件注册的设置项
  /// [themeRegistry] 主题注册表，用于管理插件注册的主题扩展
  /// [sharedPreferencesAsync] SharedPreferencesAsync，用于异步存储访问
  /// [storagePathService] 存储路径服务，用于获取文件存储路径
  /// [hookRegistry] Hook 注册表，用于管理 UI Hook（可选）
  PluginManager({
    required CommandBus commandBus,
    AppEventBus? eventBus,
    NodeRepository? nodeRepository,
    GraphRepository? graphRepository,
    ExecutionEngine? executionEngine,
    PluginDiscoverer? discoverer,
    ServiceRegistry? serviceRegistry,
    TaskRegistry? taskRegistry,
    SettingsRegistry? settingsRegistry,
    ThemeRegistry? themeRegistry,
    SharedPreferencesAsync? sharedPreferencesAsync,
    StoragePathService? storagePathService,
    HookRegistry? hookRegistry,
  }) : _commandBus = commandBus,
       _eventBus = eventBus,
       _nodeRepository = nodeRepository,
       _graphRepository = graphRepository,
       _executionEngine = executionEngine,
       _apiRegistry = APIRegistry(),
       _discoverer = discoverer ?? PluginDiscoverer(),
       _serviceRegistry = serviceRegistry ?? ServiceRegistry(),
       _taskRegistry = taskRegistry ?? TaskRegistry(),
       _settingsRegistry = settingsRegistry,
       _themeRegistry = themeRegistry ?? ThemeRegistry(),
       _sharedPreferencesAsync = sharedPreferencesAsync,
       _storagePathService = storagePathService,
       _hookRegistry = hookRegistry;

  final CommandBus _commandBus;
  final AppEventBus? _eventBus;
  final NodeRepository? _nodeRepository;
  final GraphRepository? _graphRepository;
  final ExecutionEngine? _executionEngine;
  final APIRegistry _apiRegistry;
  final PluginDiscoverer _discoverer;
  final PluginRegistry _registry = PluginRegistry();
  final ServiceRegistry _serviceRegistry;
  final TaskRegistry _taskRegistry;
  final SettingsRegistry? _settingsRegistry;
  final ThemeRegistry _themeRegistry;
  final SharedPreferencesAsync? _sharedPreferencesAsync;
  final StoragePathService? _storagePathService;
  final HookRegistry? _hookRegistry;

  /// 跟踪每个插件注册的 Hook 包装器
  ///
  /// Key: Plugin ID
  /// Value: 该插件注册的所有 Hook 包装器列表
  final Map<String, List<HookWrapper>> _pluginHooks = {};

  /// API 注册表（只读访问）
  ///
  /// 用于高级插件间通信
  APIRegistry get apiRegistry => _apiRegistry;

  /// 插件注册表（只读访问）
  PluginRegistry get registry => _registry;

  /// 插件发现器（只读访问）
  ///
  /// 用于注册和发现插件
  PluginDiscoverer get discoverer => _discoverer;

  /// Service 注册表（只读访问）
  ///
  /// 管理所有插件提供的 Service
  ServiceRegistry get serviceRegistry => _serviceRegistry;

  /// 任务注册表（只读访问）
  ///
  /// 管理插件注册的任务类型
  TaskRegistry get taskRegistry => _taskRegistry;

  /// 设置注册表（只读访问）
  ///
  /// 管理插件注册的设置项
  SettingsRegistry? get settingsRegistry => _settingsRegistry;

  /// 主题注册表（只读访问）
  ///
  /// 管理插件注册的主题扩展
  ThemeRegistry get themeRegistry => _themeRegistry;

  /// Hook 注册表（只读访问）
  ///
  /// 管理 UI Hook 的注册和生命周期
  HookRegistry? get hookRegistry => _hookRegistry;

  /// 生成所有插件的 BlocProvider 列表
  ///
  /// 返回 BlocProvider 列表，可直接用于 MultiProvider
  List<SingleChildWidget> generateBlocProviders() {
    final blocs = <SingleChildWidget>[];

    for (final wrapper in _registry.getAllPlugins()) {
      final pluginBlocs = wrapper.plugin.registerBlocs();
      blocs.addAll(pluginBlocs);
    }

    return blocs;
  }

  /// 应用版本（用于插件兼容性检查）
  String appVersion = '1.0.0';

  @override
  Future<void> loadPlugin(String pluginId) async {
    debugPrint('[PluginManager] =========================================');
    debugPrint('[PluginManager] 开始加载插件');
    debugPrint('[PluginManager]   插件 ID: $pluginId');
    debugPrint('[PluginManager] =========================================');

    // 检查是否已加载
    if (_registry.isRegistered(pluginId)) {
      debugPrint('[PluginManager] ✗ 加载失败: 插件已存在');
      throw PluginAlreadyExistsException(pluginId);
    }

    debugPrint('[PluginManager] 正在发现插件...');
    // 发现插件
    final plugin = await _discoverer.discoverPlugin(pluginId);
    if (plugin == null) {
      debugPrint('[PluginManager] ✗ 发现失败: 插件未找到');
      throw PluginNotFoundException(pluginId);
    }

    debugPrint('[PluginManager] ✓ 插件发现成功');
    debugPrint('[PluginManager]   插件名称: ${plugin.metadata.name}');
    debugPrint('[PluginManager]   插件版本: ${plugin.metadata.version}');
    debugPrint('[PluginManager]   插件作者: ${plugin.metadata.author}');

    // 检查版本兼容性
    if (!plugin.metadata.isCompatibleWith(appVersion)) {
      debugPrint('[PluginManager] ✗ 版本不兼容');
      debugPrint('[PluginManager]   插件版本: ${plugin.metadata.version}');
      debugPrint('[PluginManager]   应用版本: $appVersion');
      throw PluginVersionException(
        pluginId,
        plugin.metadata.version,
        appVersion,
      );
    }

    debugPrint('[PluginManager] ✓ 版本兼容性检查通过');

    // 创建插件上下文（包含所有依赖）
    final context = PluginContext(
      pluginId: pluginId,
      commandBus: _commandBus,
      eventBus: _eventBus,
      logger: PluginLogger(pluginId),
      apiRegistry: _apiRegistry,
      nodeRepository: _nodeRepository,
      graphRepository: _graphRepository,
      executionEngine: _executionEngine,
      taskRegistry: _taskRegistry,
      settingsRegistry: _settingsRegistry,
      themeRegistry: _themeRegistry,
      serviceRegistry: _serviceRegistry,
      storagePathService: _storagePathService,
      sharedPreferencesAsync: _sharedPreferencesAsync,
    );

    debugPrint('[PluginManager] ✓ 插件上下文创建完成');

    // 创建生命周期管理器
    final lifecycle = PluginLifecycleManager(plugin);

    // 创建包装器
    final wrapper = PluginWrapper(plugin, context, lifecycle);

    // 注册到注册表
    _registry.register(wrapper);
    debugPrint('[PluginManager] ✓ 插件已注册到注册表');

    // 调用 onLoad
    try {
      debugPrint('[PluginManager] -----------------------------------------');
      debugPrint('[PluginManager] 开始插件加载流程');

      // 1. 注册插件提供的 Service
      final serviceBindings = plugin.registerServices();
      if (serviceBindings.isNotEmpty) {
        debugPrint('[PluginManager]   步骤 1: 注册插件服务');
        debugPrint('[PluginManager]   服务数量: ${serviceBindings.length}');
        _serviceRegistry.registerServices(pluginId, serviceBindings);
        debugPrint('[PluginManager]   ✓ 插件服务注册完成');
      } else {
        debugPrint('[PluginManager]   步骤 1: 插件不提供服务');
      }

      // 2. 调用插件的 onLoad 方法
      debugPrint('[PluginManager]   步骤 2: 调用插件 onLoad 方法');
      await lifecycle.transitionTo(
        PluginState.loaded,
        () => plugin.onLoad(context),
      );
      debugPrint('[PluginManager]   ✓ onLoad 方法执行完成');

      // 3. 注册插件导出的 API
      final exportedAPIs = plugin.exportAPIs();
      if (exportedAPIs.isNotEmpty) {
        debugPrint('[PluginManager]   步骤 3: 注册插件导出的 API');
        debugPrint('[PluginManager]   API 数量: ${exportedAPIs.length}');
        for (final entry in exportedAPIs.entries) {
          _apiRegistry.registerAPI(
            pluginId,
            entry.key,
            plugin.metadata.version,
            entry.value,
          );
          debugPrint('[PluginManager]     ✓ 已注册 API: ${entry.key}');
        }
        debugPrint('[PluginManager]   ✓ API 注册完成');
      } else {
        debugPrint('[PluginManager]   步骤 3: 插件不导出 API');
      }

      // 4. 注册插件提供的 UI Hooks（新系统）
      if (_hookRegistry != null) {
        debugPrint('[PluginManager]   步骤 4: 注册插件 UI Hooks');
        await _registerPluginHooks(wrapper);
        debugPrint('[PluginManager]   ✓ UI Hooks 注册完成');
      } else {
        debugPrint('[PluginManager]   步骤 4: HookRegistry 为空，跳过');
      }

      // 5. 验证 API 依赖
      debugPrint('[PluginManager]   步骤 5: 验证 API 依赖');
      await _validateAPIDependencies(plugin);
      debugPrint('[PluginManager]   ✓ API 依赖验证通过');

      debugPrint('[PluginManager] -----------------------------------------');
      debugPrint('[PluginManager] ✓ 插件加载成功');
      debugPrint('[PluginManager]   插件状态: ${wrapper.state}');
      debugPrint('[PluginManager] =========================================');
    } catch (e) {
      debugPrint('[PluginManager] ✗ 插件加载失败: $e');
      debugPrint('[PluginManager] 正在清理已注册的资源...');

      // 加载失败，清理已注册的 Service、API、Hook 并从注册表移除
      _serviceRegistry.unregisterPluginServices(pluginId);
      _apiRegistry.unregisterPluginAPIs(pluginId);
      if (_hookRegistry != null) {
        _hookRegistry.unregisterPluginHooks(pluginId);
      }
      _registry.unregister(pluginId);

      debugPrint('[PluginManager] ✓ 资源清理完成');
      debugPrint('[PluginManager] =========================================');

      throw PluginLoadException(pluginId, e);
    }
  }

  @override
  Future<void> unloadPlugin(String pluginId) async {
    debugPrint('[PluginManager] =========================================');
    debugPrint('[PluginManager] 开始卸载插件');
    debugPrint('[PluginManager]   插件 ID: $pluginId');
    debugPrint('[PluginManager] =========================================');

    final wrapper = _registry.getPlugin(pluginId);
    if (wrapper == null) {
      debugPrint('[PluginManager] ✗ 卸载失败: 插件未找到');
      throw PluginNotFoundException(pluginId);
    }

    debugPrint('[PluginManager] ✓ 插件找到');
    debugPrint('[PluginManager]   当前状态: ${wrapper.state}');
    debugPrint('[PluginManager]   是否已启用: ${wrapper.isEnabled}');

    // 如果插件已启用，先禁用
    if (wrapper.isEnabled) {
      debugPrint('[PluginManager] 插件当前已启用，先禁用...');
      await disablePlugin(pluginId);
      debugPrint('[PluginManager] ✓ 插件已禁用');
    }

    debugPrint('[PluginManager] 开始清理插件资源...');

    // 销毁插件提供的所有 UI Hooks
    await _disposePluginHooks(wrapper);

    // 注销插件的所有 API
    _apiRegistry.unregisterPluginAPIs(pluginId);

    // 注销插件的所有 Service
    _serviceRegistry.unregisterPluginServices(pluginId);

    debugPrint('[PluginManager] ✓ 插件资源清理完成');

    // 调用 onUnload
    try {
      debugPrint('[PluginManager] 调用插件 onUnload 方法...');
      await wrapper.lifecycle.transitionTo(
        PluginState.unloaded,
        wrapper.plugin.onUnload,
      );
      debugPrint('[PluginManager] ✓ onUnload 方法执行完成');
    } catch (e) {
      debugPrint('[PluginManager] ✗ onUnload 执行失败: $e');
      throw PluginUnloadException(pluginId, e);
    } finally {
      // 从注册表移除
      _registry.unregister(pluginId);
      debugPrint('[PluginManager] ✓ 插件已从注册表移除');
    }

    debugPrint('[PluginManager] ✓ 插件卸载成功');
    debugPrint('[PluginManager] =========================================');
  }

  @override
  Future<void> enablePlugin(String pluginId) async {
    debugPrint('[PluginManager] =========================================');
    debugPrint('[PluginManager] 开始启用插件');
    debugPrint('[PluginManager]   插件 ID: $pluginId');
    debugPrint('[PluginManager] =========================================');
    
    final wrapper = _registry.getPlugin(pluginId);
    if (wrapper == null) {
      debugPrint('[PluginManager] ✗ 启用失败: 插件未找到');
      throw PluginNotFoundException(pluginId);
    }

    debugPrint('[PluginManager] ✓ 插件找到');
    debugPrint('[PluginManager]   当前状态: ${wrapper.state}');
    debugPrint('[PluginManager]   是否已启用: ${wrapper.isEnabled}');

    if (wrapper.isEnabled) {
      debugPrint('[PluginManager] ℹ 插件已启用，跳过');
      return; // 已启用
    }

    // 检查依赖
    debugPrint('[PluginManager] 检查插件依赖...');
    debugPrint('[PluginManager]   依赖列表: ${wrapper.metadata.dependencies}');
    await _ensureDependencies(wrapper);
    debugPrint('[PluginManager] ✓ 依赖检查通过');

    // 调用 onEnable
    try {
      debugPrint('[PluginManager] 调用插件 onEnable 方法...');
      await wrapper.lifecycle.transitionTo(
        PluginState.enabled,
        wrapper.plugin.onEnable,
      );

      // 启用插件提供的所有 UI Hooks
      await _enablePluginHooks(wrapper);

      debugPrint('[PluginManager] ✓ 插件启用成功');
      debugPrint('[PluginManager]   新状态: ${wrapper.state}');
      debugPrint('[PluginManager] =========================================');
    } catch (e) {
      debugPrint('[PluginManager] ✗ 插件启用失败: $e');
      debugPrint('[PluginManager]   当前状态: ${wrapper.state}');
      debugPrint('[PluginManager] =========================================');
      throw PluginEnableException(pluginId, e);
    }
  }

  @override
  Future<void> disablePlugin(String pluginId) async {
    debugPrint('[PluginManager] =========================================');
    debugPrint('[PluginManager] 开始禁用插件');
    debugPrint('[PluginManager]   插件 ID: $pluginId');
    debugPrint('[PluginManager] =========================================');

    final wrapper = _registry.getPlugin(pluginId);
    if (wrapper == null) {
      debugPrint('[PluginManager] ✗ 禁用失败: 插件未找到');
      throw PluginNotFoundException(pluginId);
    }

    debugPrint('[PluginManager] ✓ 插件找到');
    debugPrint('[PluginManager]   当前状态: ${wrapper.state}');
    debugPrint('[PluginManager]   是否已启用: ${wrapper.isEnabled}');

    if (!wrapper.isEnabled) {
      debugPrint('[PluginManager] ℹ 插件已禁用，跳过');
      debugPrint('[PluginManager] =========================================');
      return; // 已禁用
    }

    // 调用 onDisable
    try {
      debugPrint('[PluginManager] 调用插件 onDisable 方法...');
      
      // 禁用插件提供的所有 UI Hooks
      await _disablePluginHooks(wrapper);

      await wrapper.lifecycle.transitionTo(
        PluginState.disabled,
        wrapper.plugin.onDisable,
      );
      
      debugPrint('[PluginManager] ✓ 插件禁用成功');
      debugPrint('[PluginManager]   新状态: ${wrapper.state}');
      debugPrint('[PluginManager] =========================================');
    } catch (e) {
      debugPrint('[PluginManager] ✗ 插件禁用失败: $e');
      debugPrint('[PluginManager] =========================================');
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
    final dependencies = wrapper.metadata.dependencies;
    
    if (dependencies.isEmpty) {
      debugPrint('[PluginManager]   插件无依赖');
      return;
    }
    
    debugPrint('[PluginManager]   开始检查依赖...');
    
    for (final depId in dependencies) {
      debugPrint('[PluginManager]     检查依赖: $depId');
      
      final dep = _registry.getPlugin(depId);

      if (dep == null) {
        debugPrint('[PluginManager]     ✗ 依赖未找到');
        throw MissingDependencyException(wrapper.metadata.id, depId);
      }

      debugPrint('[PluginManager]     ✓ 依赖已找到');
      debugPrint('[PluginManager]       状态: ${dep.state}');
      debugPrint('[PluginManager]       是否已启用: ${dep.isEnabled}');

      if (!dep.isEnabled) {
        debugPrint('[PluginManager]     依赖未启用，正在启用...');
        await enablePlugin(depId);
        debugPrint('[PluginManager]     ✓ 依赖已启用');
      } else {
        debugPrint('[PluginManager]     ✓ 依赖已启用');
      }
    }
    
    debugPrint('[PluginManager]   ✓ 所有依赖检查完成');
  }

  /// 验证 API 依赖
  ///
  /// 检查插件依赖的 API 是否已被其他插件导出，且版本满足要求
  /// 注册插件提供的 UI Hooks
  ///
  /// [wrapper] Plugin 包装器
  ///
  /// 注册插件通过 registerHooks() 返回的所有 Hook 工厂
  /// Hook 的生命周期与 Plugin 自动同步
  Future<void> _registerPluginHooks(PluginWrapper wrapper) async {
    if (_hookRegistry == null) {
      debugPrint('[PluginManager] HookRegistry is null, skipping hook registration');
      return;
    }

    final plugin = wrapper.plugin;
    final pluginId = plugin.metadata.id;
    final hookFactories = plugin.registerHooks();

    if (hookFactories.isEmpty) {
      debugPrint('[PluginManager] Plugin $pluginId provides no hooks');
      return;
    }

    debugPrint('[PluginManager] Registering hooks for plugin: $pluginId');

    // 初始化该插件的 Hook 列表
    _pluginHooks[pluginId] = [];

    for (final factory in hookFactories) {
      try {
        // 创建 Hook 实例
        final hook = factory();

        // 创建 Hook 上下文
        final hookContext = BasicHookContext(
          data: {},
          pluginContext: wrapper.context,
          hookAPIRegistry: _hookRegistry.apiRegistry,
        );

        // 注册 Hook 到 HookRegistry
        _hookRegistry.registerHook(hook, parentPlugin: wrapper);

        // 获取 Hook 包装器（从 HookRegistry 中）
        // 注意：需要使用 includeDisabled: true，因为新注册的 Hook 还未启用
        final hookWrappers = _hookRegistry.getHookWrappers(
          hook.hookPointId,
          includeDisabled: true,
        );
        final hookWrapper = hookWrappers.firstWhere(
          (hw) => hw.hook == hook,
          orElse: () => throw Exception('Hook wrapper not found'),
        );

        // 添加到本地跟踪
        _pluginHooks[pluginId]!.add(hookWrapper);

        // 初始化 Hook
        await hookWrapper.lifecycle.transitionTo(
          HookState.initialized,
          () => hook.onInit(hookContext),
        );

        debugPrint('[PluginManager] ✓ Registered hook: ${hook.metadata.id}');
        debugPrint('    - Hook point: ${hook.hookPointId}');
        debugPrint('    - Priority: ${hook.priority}');
        debugPrint('    - Synced with plugin: $pluginId');
      } catch (e) {
        debugPrint('[PluginManager] ✗ Error registering hook: $e');
        // 继续注册其他 Hook，不中断整个流程
      }
    }

    // 如果插件已启用，自动启用所有 Hook
    if (wrapper.isEnabled) {
      await _enablePluginHooks(wrapper);
    }
  }

  /// 启用插件的所有 Hook
  ///
  /// [wrapper] Plugin 包装器
  Future<void> _enablePluginHooks(PluginWrapper wrapper) async {
    if (_hookRegistry == null) return;

    final pluginId = wrapper.plugin.metadata.id;
    final hooks = _pluginHooks[pluginId];

    if (hooks == null || hooks.isEmpty) {
      debugPrint('[PluginManager] No hooks to enable for plugin: $pluginId');
      return;
    }

    debugPrint('[PluginManager] Enabling hooks for plugin: $pluginId');

    for (final hookWrapper in hooks) {
      try {
        await hookWrapper.lifecycle.transitionTo(
          HookState.enabled,
          hookWrapper.hook.onEnable,
        );
        debugPrint('[PluginManager] ✓ Enabled hook: ${hookWrapper.hook.metadata.id}');
      } catch (e) {
        debugPrint('[PluginManager] ✗ Error enabling hook: $e');
      }
    }
  }

  /// 禁用插件的所有 Hook
  ///
  /// [wrapper] Plugin 包装器
  Future<void> _disablePluginHooks(PluginWrapper wrapper) async {
    if (_hookRegistry == null) return;

    final pluginId = wrapper.plugin.metadata.id;
    final hooks = _pluginHooks[pluginId];

    if (hooks == null || hooks.isEmpty) {
      debugPrint('[PluginManager] No hooks to disable for plugin: $pluginId');
      return;
    }

    debugPrint('[PluginManager] Disabling hooks for plugin: $pluginId');

    for (final hookWrapper in hooks) {
      try {
        await hookWrapper.lifecycle.transitionTo(
          HookState.disabled,
          hookWrapper.hook.onDisable,
        );
        debugPrint('[PluginManager] ✓ Disabled hook: ${hookWrapper.hook.metadata.id}');
      } catch (e) {
        debugPrint('[PluginManager] ✗ Error disabling hook: $e');
      }
    }
  }

  /// 销毁插件的所有 Hook
  ///
  /// [wrapper] Plugin 包装器
  Future<void> _disposePluginHooks(PluginWrapper wrapper) async {
    if (_hookRegistry == null) return;

    final pluginId = wrapper.plugin.metadata.id;
    final hooks = _pluginHooks[pluginId];

    if (hooks == null || hooks.isEmpty) {
      debugPrint('[PluginManager] No hooks to dispose for plugin: $pluginId');
      return;
    }

    debugPrint('[PluginManager] Disposing hooks for plugin: $pluginId');

    for (final hookWrapper in hooks) {
      try {
        await hookWrapper.lifecycle.transitionTo(
          HookState.disposed,
          hookWrapper.hook.onDispose,
        );
        debugPrint('[PluginManager] ✓ Disposed hook: ${hookWrapper.hook.metadata.id}');
      } catch (e) {
        debugPrint('[PluginManager] ✗ Error disposing hook: $e');
      }
    }

    // 从 HookRegistry 中移除所有 Hook
    _hookRegistry.unregisterPluginHooks(pluginId);

    // 从本地跟踪中移除
    _pluginHooks.remove(pluginId);
  }

  /// 验证 API 依赖
  Future<void> _validateAPIDependencies(Plugin plugin) async {
    for (final dep in plugin.metadata.apiDependencies) {
      if (!_apiRegistry.hasAPI(dep.apiName)) {
        throw MissingAPIDependencyException(plugin.metadata.id, dep.apiName);
      }

      final version = _apiRegistry.getAPIVersion(dep.apiName);
      if (version != null && !dep.isSatisfiedBy(version)) {
        throw APIVersionException(
          plugin.metadata.id,
          dep.apiName,
          dep.minimumVersion ?? 'any',
          version,
        );
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
