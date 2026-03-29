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
import '../utils/logger.dart';
import 'api/api_registry.dart';
import 'plugin.dart';
import 'ui_hooks/hook_base.dart';
import 'ui_hooks/hook_context.dart';
import 'ui_hooks/hook_lifecycle.dart';
import 'ui_hooks/hook_registry.dart';

/// 插件管理器日志记录器
const _log = AppLogger('PluginManager');

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

  /// 跟踪每个插件注册的 Hook 点
  ///
  /// Key: Plugin ID
  /// Value: 该插件注册的所有 Hook 点 ID 列表
  final Map<String, List<String>> _pluginHookPoints = {};

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
    final allPlugins = _registry.getAllPlugins();

    for (final wrapper in allPlugins) {
      final pluginBlocs = wrapper.plugin.registerBlocs();
      blocs.addAll(pluginBlocs);
    }

    _log.info('Generated ${blocs.length} BLoC providers from ${allPlugins.length} plugins');
    return blocs;
  }

  /// 应用版本（用于插件兼容性检查）
  String appVersion = '1.0.0';

  @override
  Future<void> loadPlugin(String pluginId) async {
    _log.info('Loading plugin: $pluginId');

    try {
      // 1. 验证插件
      final plugin = await _validateAndDiscoverPlugin(pluginId);

      // 2. 创建插件包装器和上下文
      final (wrapper, context) = _createPluginWrapper(plugin, pluginId);

      // 3. 注册到注册表
      await _registerPluginWrapper(wrapper);

      // 4. 初始化插件
      await _initializePlugin(plugin, wrapper, context, pluginId);

      _log.info('Plugin loaded successfully: $pluginId (state: ${wrapper.state})');

      // 发布插件加载事件
      _commandBus.publishEvent(PluginLoadedEvent(pluginId: pluginId));
    } catch (e) {
      // 加载失败，清理资源
      await _cleanupFailedPlugin(pluginId, e);
      // 重新抛出原始异常，保持异常类型
      rethrow;
    }
  }

  /// 验证插件并发现插件实例
  ///
  /// [pluginId] 插件 ID
  ///
  /// 返回发现的插件实例
  ///
  /// 抛出 [PluginAlreadyExistsException] 如果插件已加载
  /// 抛出 [PluginNotFoundException] 如果插件未找到
  /// 抛出 [PluginVersionException] 如果版本不兼容
  Future<Plugin> _validateAndDiscoverPlugin(String pluginId) async {
    // 检查是否已加载
    if (_registry.isRegistered(pluginId)) {
      _log.warning('Plugin already exists: $pluginId');
      throw PluginAlreadyExistsException(pluginId);
    }

    // 发现插件
    final plugin = await _discoverer.discoverPlugin(pluginId);
    if (plugin == null) {
      _log.error('Plugin not found: $pluginId');
      throw PluginNotFoundException(pluginId);
    }

    _log.debug('Discovered plugin: ${plugin.metadata.name} v${plugin.metadata.version}');

    // 检查版本兼容性
    if (!plugin.metadata.isCompatibleWith(appVersion)) {
      _log.warning('Version incompatibility: plugin ${plugin.metadata.version}, app $appVersion');
      throw PluginVersionException(
        pluginId,
        plugin.metadata.version,
        appVersion,
      );
    }

    return plugin;
  }

  /// 创建插件包装器和上下文
  ///
  /// [plugin] 插件实例
  /// [pluginId] 插件 ID
  ///
  /// 返回元组：(PluginWrapper, PluginContext)
  (PluginWrapper, PluginContext) _createPluginWrapper(
    Plugin plugin,
    String pluginId,
  ) {
    // 创建插件上下文（包含所有依赖）
    final context = PluginContext(
      pluginId: pluginId,
      commandBus: _commandBus,
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

    // 创建生命周期管理器
    final lifecycle = PluginLifecycleManager(plugin);

    // 创建包装器
    final wrapper = PluginWrapper(plugin, context, lifecycle);

    return (wrapper, context);
  }

  /// 注册插件包装器到注册表
  ///
  /// [wrapper] 插件包装器
  ///
  /// 抛出异常如果 API 依赖验证失败
  Future<void> _registerPluginWrapper(PluginWrapper wrapper) async {
    // 在注册之前验证 API 依赖
    _log.info('验证 API 依赖');
    await _validateAPIDependencies(wrapper.plugin);
    _log.info('[PluginManager] ✓ API 依赖验证通过');

    // 注册到注册表
    _registry.register(wrapper);
    _log.info('[PluginManager] ✓ 插件已注册到注册表');
  }

  /// 初始化插件（注册服务、调用 onLoad、注册 API、Hook 点和 Hooks）
  ///
  /// [plugin] 插件实例
  /// [wrapper] 插件包装器
  /// [context] 插件上下文
  /// [pluginId] 插件 ID
  Future<void> _initializePlugin(
    Plugin plugin,
    PluginWrapper wrapper,
    PluginContext context,
    String pluginId,
  ) async {

    _log.info('开始插件加载流程');

    final lifecycle = wrapper.lifecycle;

    // 1. 注册插件提供的 Service
    await _registerPluginServices(plugin, pluginId);

    // 2. 调用插件的 onLoad 方法
    await _callPluginOnLoad(plugin, lifecycle, context);

    // 3. 注册插件导出的 API
    _registerPluginAPIs(plugin, pluginId);

    // 4. 注册插件提供的 Hook 点
    await _registerPluginHookPoints(plugin, pluginId);

    // 5. 注册插件提供的 UI Hooks
    await _registerPluginUIHooks(wrapper);


  }

  /// 注册插件服务
  Future<void> _registerPluginServices(
    Plugin plugin,
    String pluginId,
  ) async {
    final serviceBindings = plugin.registerServices();
    if (serviceBindings.isNotEmpty) {


      _serviceRegistry.registerServices(pluginId, serviceBindings);
      _log.info('  ✓ 插件服务注册完成');
    } else {

    }
  }

  /// 调用插件的 onLoad 方法
  Future<void> _callPluginOnLoad(
    Plugin plugin,
    PluginLifecycleManager lifecycle,
    PluginContext context,
  ) async {

    await lifecycle.transitionTo(
      PluginState.loaded,
      () => plugin.onLoad(context),
    );
    _log.info('  ✓ onLoad 方法执行完成');
  }

  /// 注册插件导出的 API
  void _registerPluginAPIs(Plugin plugin, String pluginId) {
    final exportedAPIs = plugin.exportAPIs();
    if (exportedAPIs.isNotEmpty) {


      for (final entry in exportedAPIs.entries) {
        _apiRegistry.registerAPI(
          pluginId,
          entry.key,
          plugin.metadata.version,
          entry.value,
        );

      }
      _log.info('  ✓ API 注册完成');
    } else {

    }
  }

  /// 注册插件 Hook 点
  Future<void> _registerPluginHookPoints(Plugin plugin, String pluginId) async {
    if (_hookRegistry == null) {

      return;
    }

    final hookPoints = plugin.registerHookPoints();
    if (hookPoints.isEmpty) {

      return;
    }




    // 初始化该插件的 Hook 点列表
    _pluginHookPoints[pluginId] = [];

    for (final point in hookPoints) {
      try {
        _hookRegistry.registerHookPoint(point);
        _pluginHookPoints[pluginId]!.add(point.id);

      } catch (e) {

        // 继续注册其他 Hook 点，不中断整个流程
      }
    }

    _log.info('  ✓ Hook 点注册完成');
  }

  /// 注册插件 UI Hooks
  Future<void> _registerPluginUIHooks(PluginWrapper wrapper) async {
    if (_hookRegistry != null) {

      await _registerPluginHooks(wrapper);
      _log.info('  ✓ UI Hooks 注册完成');
    } else {

    }
  }

  /// 清理加载失败的插件
  ///
  /// [pluginId] 插件 ID
  /// [error] 加载失败的错误
  Future<void> _cleanupFailedPlugin(String pluginId, Object error) async {
    _log..warning('PluginManager ✗ 插件加载失败: $error')
    ..info('正在清理已注册的资源...');

    // 加载失败，清理已注册的 Hook 点、Service、API、Hook 并从注册表移除
    _unregisterPluginHookPoints(pluginId);
    _serviceRegistry.unregisterPluginServices(pluginId);
    _apiRegistry.unregisterPluginAPIs(pluginId);
    if (_hookRegistry != null) {
      _hookRegistry.unregisterPluginHooks(pluginId);
    }
    // 只有在插件已注册的情况下才注销
    if (_registry.isRegistered(pluginId)) {
      _registry.unregister(pluginId);
    }

    _log.info('[PluginManager] ✓ 资源清理完成');

  }

  @override
  Future<void> unloadPlugin(String pluginId) async {

    _log.info('开始卸载插件');



    final wrapper = _registry.getPlugin(pluginId);
    if (wrapper == null) {
      _log.warning('PluginManager ✗ 卸载失败: 插件未找到');
      throw PluginNotFoundException(pluginId);
    }

    _log.info('[PluginManager] ✓ 插件找到');



    // 如果插件已启用，先禁用
    if (wrapper.isEnabled) {
      _log.info('插件当前已启用，先禁用...');
      await disablePlugin(pluginId);
      _log.info('[PluginManager] ✓ 插件已禁用');
    }

    _log.info('开始清理插件资源...');

    // 销毁插件提供的所有 Hook 点
    _unregisterPluginHookPoints(pluginId);

    // 销毁插件提供的所有 UI Hooks
    await _disposePluginHooks(wrapper);

    // 注销插件的所有 API
    _apiRegistry.unregisterPluginAPIs(pluginId);

    // 注销插件的所有 Service
    _serviceRegistry.unregisterPluginServices(pluginId);

    _log.info('[PluginManager] ✓ 插件资源清理完成');

    // 调用 onUnload
    try {
      _log.info('调用插件 onUnload 方法...');
      await wrapper.lifecycle.transitionTo(
        PluginState.unloaded,
        wrapper.plugin.onUnload,
      );
      _log.info('[PluginManager] ✓ onUnload 方法执行完成');
    } catch (e) {
      _log.warning('PluginManager ✗ onUnload 执行失败: $e');
      throw PluginUnloadException(pluginId, e);
    } finally {
      // 从注册表移除
      _registry.unregister(pluginId);
      _log.info('[PluginManager] ✓ 插件已从注册表移除');
    }

    _log.info('[PluginManager] ✓ 插件卸载成功');

  }

  @override
  Future<void> enablePlugin(String pluginId) async {

    _log.info('开始启用插件');


    
    final wrapper = _registry.getPlugin(pluginId);
    if (wrapper == null) {
      _log.warning('PluginManager ✗ 启用失败: 插件未找到');
      throw PluginNotFoundException(pluginId);
    }

    _log.info('[PluginManager] ✓ 插件找到');



    if (wrapper.isEnabled) {
      _log.info('ℹ 插件已启用，跳过');
      return; // 已启用
    }

    // 检查依赖
    _log.info('检查插件依赖...');

    await _ensureDependencies(wrapper);
    _log.info('[PluginManager] ✓ 依赖检查通过');

    // 调用 onEnable
    try {
      _log.info('调用插件 onEnable 方法...');
      await wrapper.lifecycle.transitionTo(
        PluginState.enabled,
        wrapper.plugin.onEnable,
      );

      // 启用插件提供的所有 UI Hooks
      await _enablePluginHooks(wrapper);

      _log.info('[PluginManager] ✓ 插件启用成功');

      // 发布插件启用事件
      _commandBus.publishEvent(PluginEnabledEvent(pluginId: pluginId));
    } catch (e) {
      _log.warning('PluginManager ✗ 插件启用失败: $e');


      throw PluginEnableException(pluginId, e);
    }
  }

  @override
  Future<void> disablePlugin(String pluginId) async {

    _log.info('开始禁用插件');



    final wrapper = _registry.getPlugin(pluginId);
    if (wrapper == null) {
      _log.warning('PluginManager ✗ 禁用失败: 插件未找到');
      throw PluginNotFoundException(pluginId);
    }

    _log.info('[PluginManager] ✓ 插件找到');



    if (!wrapper.isEnabled) {
      _log.info('ℹ 插件已禁用，跳过');

      return; // 已禁用
    }

    // 调用 onDisable
    try {
      _log.info('调用插件 onDisable 方法...');
      
      // 禁用插件提供的所有 UI Hooks
      await _disablePluginHooks(wrapper);

      await wrapper.lifecycle.transitionTo(
        PluginState.disabled,
        wrapper.plugin.onDisable,
      );
      
      _log.info('[PluginManager] ✓ 插件禁用成功');


    } catch (e) {
      _log.warning('PluginManager ✗ 插件禁用失败: $e');

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
        _log.error('Failed to load plugin $pluginId', error: e);
      }
    }
  }

  /// 确保插件的依赖已加载并启用
  Future<void> _ensureDependencies(PluginWrapper wrapper) async {
    final dependencies = wrapper.metadata.dependencies;
    
    if (dependencies.isEmpty) {
      _log.info('  插件无依赖');
      return;
    }
    
    _log.info('  开始检查依赖...');
    
    for (final depId in dependencies) {

      
      final dep = _registry.getPlugin(depId);

      if (dep == null) {
        _log.info('    ✗ 依赖未找到');
        throw MissingDependencyException(wrapper.metadata.id, depId);
      }

      _log.info('    ✓ 依赖已找到');



      if (!dep.isEnabled) {
        _log.info('    依赖未启用，正在启用...');
        await enablePlugin(depId);
        _log.info('    ✓ 依赖已启用');
      } else {
        _log.info('    ✓ 依赖已启用');
      }
    }
    
    _log.info('  ✓ 所有依赖检查完成');
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
      _log.info('HookRegistry is null, skipping hook registration');
      return;
    }

    final plugin = wrapper.plugin;
    final pluginId = plugin.metadata.id;
    final hookFactories = plugin.registerHooks();

    if (hookFactories.isEmpty) {
      _log.info('Plugin $pluginId provides no hooks');
      return;
    }

    _log.info('Registering hooks for plugin: $pluginId');

    // 初始化该插件的 Hook 列表
    _pluginHooks[pluginId] = [];

    for (final factory in hookFactories) {
      // 在 try 块外部声明变量，确保 catch 块可以访问
      UIHookBase? hook;
      try {
        // 创建 Hook 实例
        hook = factory();

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
          () => hook!.onInit(hookContext),
        );

        _log.info('Registered hook: ${hook.metadata.id} (point: ${hook.hookPointId}, priority: ${hook.priority})');
      } catch (e) {
        _log.warning('Error registering hook: ${hook?.metadata.id ?? 'unknown'}', error: e);
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
      _log.info('No hooks to enable for plugin: $pluginId');
      return;
    }

    _log.info('Enabling hooks for plugin: $pluginId');

    for (final hookWrapper in hooks) {
      try {
        await hookWrapper.lifecycle.transitionTo(
          HookState.enabled,
          hookWrapper.hook.onEnable,
        );
        _log.info('[PluginManager] ✓ Enabled hook: ${hookWrapper.hook.metadata.id}');
      } catch (e) {
        _log.warning('PluginManager ✗ Error enabling hook: $e');
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
      _log.info('No hooks to disable for plugin: $pluginId');
      return;
    }

    _log.info('Disabling hooks for plugin: $pluginId');

    for (final hookWrapper in hooks) {
      try {
        await hookWrapper.lifecycle.transitionTo(
          HookState.disabled,
          hookWrapper.hook.onDisable,
        );
        _log.info('[PluginManager] ✓ Disabled hook: ${hookWrapper.hook.metadata.id}');
      } catch (e) {
        _log.warning('PluginManager ✗ Error disabling hook: $e');
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
      _log.info('No hooks to dispose for plugin: $pluginId');
      return;
    }

    _log.info('Disposing hooks for plugin: $pluginId');

    for (final hookWrapper in hooks) {
      try {
        await hookWrapper.lifecycle.transitionTo(
          HookState.disposed,
          hookWrapper.hook.onDispose,
        );
        _log.info('[PluginManager] ✓ Disposed hook: ${hookWrapper.hook.metadata.id}');
      } catch (e) {
        _log.warning('PluginManager ✗ Error disposing hook: $e');
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

  /// 注销插件的所有 Hook 点
  ///
  /// [pluginId] 插件 ID
  void _unregisterPluginHookPoints(String pluginId) {
    final hookPointIds = _pluginHookPoints[pluginId];
    if (hookPointIds == null || hookPointIds.isEmpty) {
      _log.info('插件 $pluginId 没有注册 Hook 点');
      return;
    }

    _log.info('开始注销插件 Hook 点');



    if (_hookRegistry != null) {
      hookPointIds.forEach(_hookRegistry.unregisterHookPoint);
    }

    // 从本地跟踪中移除
    _pluginHookPoints.remove(pluginId);

    _log.info('[PluginManager] ✓ 插件 Hook 点注销完成');
  }

  /// 释放资源
  Future<void> dispose() async {
    // 卸载所有插件
    final plugins = _registry.getAllPlugins();
    for (final plugin in plugins) {
      try {
        await unloadPlugin(plugin.metadata.id);
      } catch (e) {
        _log.error('Error unloading plugin ${plugin.metadata.id}', error: e);
      }
    }
  }
}
