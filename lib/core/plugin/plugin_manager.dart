import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:provider/single_child_widget.dart';

import '../commands/command_bus.dart';
import '../events/app_events.dart';
import '../execution/execution_engine.dart';
import '../execution/task_registry.dart';
import '../repositories/graph_repository.dart';
import '../repositories/node_repository.dart';
import '../services/infrastructure/settings_registry.dart';
import '../services/infrastructure/theme_registry.dart';
import 'api/api_registry.dart';
import 'plugin.dart';
import 'ui_hooks/ui_hook.dart';

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
       _themeRegistry = themeRegistry ?? ThemeRegistry();

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
    );

    // 创建生命周期管理器
    final lifecycle = PluginLifecycleManager(plugin);

    // 创建包装器
    final wrapper = PluginWrapper(plugin, context, lifecycle);

    // 注册到注册表
    _registry.register(wrapper);

    // 如果是 UIHook，设置 pluginContext 引用
    if (plugin is UIHook) {
      plugin.pluginContext = context;
    }

    // 调用 onLoad
    try {
      // 1. 注册插件提供的 Service
      final serviceBindings = plugin.registerServices();
      if (serviceBindings.isNotEmpty) {
        _serviceRegistry.registerServices(pluginId, serviceBindings);
      }

      // 2. 调用插件的 onLoad 方法
      await lifecycle.transitionTo(
        PluginState.loaded,
        () => plugin.onLoad(context),
      );

      // 3. 注册插件导出的 API
      final exportedAPIs = plugin.exportAPIs();
      for (final entry in exportedAPIs.entries) {
        _apiRegistry.registerAPI(
          pluginId,
          entry.key,
          plugin.metadata.version,
          entry.value,
        );
      }

      // 4. 验证 API 依赖
      await _validateAPIDependencies(plugin);
    } catch (e) {
      // 加载失败，清理已注册的 Service、API 并从注册表移除
      _serviceRegistry.unregisterPluginServices(pluginId);
      _apiRegistry.unregisterPluginAPIs(pluginId);
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

    // 注销插件的所有 API
    _apiRegistry.unregisterPluginAPIs(pluginId);

    // 注销插件的所有 Service
    _serviceRegistry.unregisterPluginServices(pluginId);

    // 调用 onUnload
    try {
      await wrapper.lifecycle.transitionTo(
        PluginState.unloaded,
        wrapper.plugin.onUnload,
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
        wrapper.plugin.onEnable,
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
        wrapper.plugin.onDisable,
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

  /// 验证 API 依赖
  ///
  /// 检查插件依赖的 API 是否已被其他插件导出，且版本满足要求
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
