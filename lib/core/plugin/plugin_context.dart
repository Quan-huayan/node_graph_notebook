import 'package:flutter/widgets.dart';

import '../commands/command_bus.dart';
import '../events/app_events.dart';
import '../execution/cpu_task.dart';
import '../execution/execution_engine.dart';
import '../execution/task_registry.dart';
import '../repositories/graph_repository.dart';
import '../repositories/node_repository.dart';
import '../services/infrastructure/settings_registry.dart';
import '../services/infrastructure/theme_registry.dart';
import 'api/api_registry.dart';
import 'dependency_container.dart';
import 'plugin_communication.dart';
import 'plugin_exception.dart';
import 'service_registry.dart';

/// 插件上下文
///
/// 提供插件与主系统交互的受限 API
/// 插件通过此上下文访问系统功能，但不能直接访问内部实现
class PluginContext {
  /// 创建一个新的插件上下文实例。
  ///
  /// [pluginId] 插件的唯一标识符
  /// [commandBus] 命令总线，用于执行写操作
  /// [eventBus] 事件总线，用于订阅数据变化
  /// [logger] 插件日志记录器
  /// [apiRegistry] API 注册表，用于获取其他插件导出的 API
  /// [nodeRepository] 节点仓库，用于读取节点数据
  /// [graphRepository] 图仓库，用于读取图数据
  /// [executionEngine] 执行引擎，用于 CPU 密集型任务
  /// [dependencyContainer] 依赖注入容器
  /// [communication] 插件通信接口
  /// [taskRegistry] 任务注册表，用于注册自定义任务类型
  /// [settingsRegistry] 设置注册表，用于注册插件设置
  /// [themeRegistry] 主题注册表，用于注册主题扩展
  /// [config] 插件配置
  PluginContext({
    required this.pluginId,
    required this.commandBus,
    this.eventBus,
    this.logger,
    this.apiRegistry,
    this.nodeRepository,
    this.graphRepository,
    this.executionEngine,
    this.dependencyContainer,
    this.communication,
    this.taskRegistry,
    this.settingsRegistry,
    this.themeRegistry,
    this.serviceRegistry,
    Map<String, dynamic>? config,
  }) : _config = config ?? {} {
    // 注册默认依赖
    _registerDefaultDependencies();
  }

  /// 插件 ID
  final String pluginId;

  /// Command Bus（执行写操作）
  final CommandBus commandBus;

  /// Event Bus（订阅数据变化）
  final AppEventBus? eventBus;

  /// 插件日志记录器
  final PluginLogger? logger;

  /// API 注册表（用于获取其他插件导出的 API）
  final APIRegistry? apiRegistry;

  /// 节点仓库（用于读取节点数据）
  final NodeRepository? nodeRepository;

  /// 图仓库（用于读取图数据）
  final GraphRepository? graphRepository;

  /// 执行引擎（用于 CPU 密集型任务）
  final ExecutionEngine? executionEngine;

  /// 任务注册表（用于注册自定义任务类型）
  final TaskRegistry? taskRegistry;

  /// 设置注册表（用于注册插件设置）
  final SettingsRegistry? settingsRegistry;

  /// 主题注册表（用于注册主题扩展）
  final ThemeRegistry? themeRegistry;

  /// 依赖注入容器
  final DependencyContainer? dependencyContainer;

  /// 插件通信接口
  final PluginCommunication? communication;

  /// Service 注册表（用于获取插件提供的 Service）
  final ServiceRegistry? serviceRegistry;

  /// 插件配置（只读）
  final Map<String, dynamic> _config;

  /// 注册默认依赖
  void _registerDefaultDependencies() {
    if (dependencyContainer != null) {
      if (nodeRepository != null) {
        dependencyContainer!.register<NodeRepository>(nodeRepository!);
      }
      if (graphRepository != null) {
        dependencyContainer!.register<GraphRepository>(graphRepository!);
      }
      // commandBus 是必填参数，不需要检查
      dependencyContainer!.register<CommandBus>(commandBus);
      if (eventBus != null) {
        dependencyContainer!.register<AppEventBus>(eventBus!);
      }
      if (apiRegistry != null) {
        dependencyContainer!.register<APIRegistry>(apiRegistry!);
      }
      if (executionEngine != null) {
        dependencyContainer!.register<ExecutionEngine>(executionEngine!);
      }
      if (taskRegistry != null) {
        dependencyContainer!.register<TaskRegistry>(taskRegistry!);
      }
      if (settingsRegistry != null) {
        dependencyContainer!.register<SettingsRegistry>(settingsRegistry!);
      }
      if (themeRegistry != null) {
        dependencyContainer!.register<ThemeRegistry>(themeRegistry!);
      }
      if (communication != null) {
        dependencyContainer!.register<PluginCommunication>(communication!);
      }
    }
  }

  /// 获取配置值
  ///
  /// [key] 配置键
  /// [defaultValue] 默认值（如果配置不存在）
  T? getConfig<T>(String key, {T? defaultValue}) {
    if (!_config.containsKey(key)) return defaultValue;
    return _config[key] as T?;
  }

  /// 检查配置键是否存在
  bool hasConfig(String key) => _config.containsKey(key);

  /// 获取所有配置
  Map<String, dynamic> get config => Map.unmodifiable(_config);

  /// 获取其他插件导出的 API
  ///
  /// [apiName] API 名称
  /// 返回 API 实例，如果不存在则返回 null
  ///
  /// 使用示例：
  /// ```dart
  /// final searchAPI = context.getAPI<SearchAPI>('search_api');
  /// if (searchAPI != null) {
  ///   searchAPI.search(query);
  /// }
  /// ```
  T? getAPI<T>(String apiName) => apiRegistry?.getAPI<T>(apiName);

  /// 检查 API 是否存在
  ///
  /// [apiName] API 名称
  /// 返回 true 如果 API 已被其他插件导出
  bool hasAPI(String apiName) => apiRegistry?.hasAPI(apiName) ?? false;

  /// 获取 API 版本
  ///
  /// [apiName] API 名称
  /// 返回 API 版本，如果不存在则返回 null
  String? getAPIVersion(String apiName) => apiRegistry?.getAPIVersion(apiName);

  /// 类型安全的依赖访问
  ///
  /// 类似 CommandContext.read<T>()，提供类型安全的服务访问
  ///
  /// 使用示例：
  /// ```dart
  /// final nodeRepo = context.read<NodeRepository>();
  /// final nodes = await nodeRepo.queryAll();
  /// ```
  T read<T>() {
    // 1. 首先尝试从 dependencyContainer 获取
    if (dependencyContainer != null && dependencyContainer!.contains<T>()) {
      return dependencyContainer!.get<T>();
    }

    // 2. 尝试从 ServiceRegistry 获取服务
    if (serviceRegistry != null && serviceRegistry!.isRegistered<T>()) {
      try {
        final service = serviceRegistry!.getService<T>();
        if (service != null) {
          return service;
        }
      } catch (e) {
        debugPrint('[PluginContext] Failed to get service $T from ServiceRegistry: $e');
      }
    }

    // 3. 向后兼容：直接访问 Repository
    if (T == NodeRepository) {
      if (nodeRepository == null) {
        throw PluginStateException(
          'plugin',
          'uninitialized',
          'NodeRepository available',
        );
      }
      return nodeRepository as T;
    }
    if (T == GraphRepository) {
      if (graphRepository == null) {
        throw PluginStateException(
          'plugin',
          'uninitialized',
          'GraphRepository available',
        );
      }
      return graphRepository as T;
    }

    // 4. 特殊处理：CommandBus 和 EventBus
    if (T == CommandBus) {
      return commandBus as T;
    }
    if (T == AppEventBus) {
      if (eventBus == null) {
        throw PluginStateException('plugin', 'uninitialized', 'AppEventBus available');
      }
      return eventBus as T;
    }

    // 5. 如果都找不到，抛出异常
    throw PluginConfigurationException('unknown', 'Unknown service type: $T');
  }

  /// 检查依赖是否可用
  ///
  /// 使用示例：
  /// ```dart
  /// if (context.hasDependency<NodeRepository>()) {
  ///   final repo = context.read<NodeRepository>();
  /// }
  /// ```
  bool hasDependency<T>() {
    // 1. 检查 dependencyContainer
    if (dependencyContainer != null && dependencyContainer!.contains<T>()) {
      return true;
    }

    // 2. 检查 ServiceRegistry
    if (serviceRegistry != null && serviceRegistry!.isRegistered<T>()) {
      return true;
    }

    // 3. 向后兼容：直接检查 Repository
    if (T == NodeRepository) return nodeRepository != null;
    if (T == GraphRepository) return graphRepository != null;

    return false;
  }

  /// 检查 Repository 是否可用（向后兼容）
  ///
  /// 使用示例：
  /// ```dart
  /// if (context.hasRepository<NodeRepository>()) {
  ///   final repo = context.read<NodeRepository>();
  /// }
  /// ```
  bool hasRepository<T>() => hasDependency<T>();

  /// 记录信息日志
  void info(String message) {
    logger?.info(message);
  }

  /// 记录警告日志
  void warning(String message) {
    logger?.warning(message);
  }

  /// 记录错误日志
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    logger?.error(message, error, stackTrace);
  }

  /// 记录调试日志
  void debug(String message) {
    logger?.debug(message);
  }

  /// 执行 CPU 密集型任务
  ///
  /// 便捷方法：通过 ExecutionEngine 在后台 isolate 中执行任务
  ///
  /// [task] 要执行的 CPU 任务
  /// 返回任务执行结果
  ///
  /// 示例：
  /// ```dart
  /// final result = await context.executeCPU(
  ///   TextLayoutTask(text: 'Hello', fontSize: 14.0),
  /// );
  /// ```
  Future<T> executeCPU<T>(CPUTask<T> task) async {
    if (executionEngine == null) {
      throw PluginStateException(
        pluginId,
        'uninitialized',
        'ExecutionEngine not available',
      );
    }
    return executionEngine!.executeCPU(task);
  }
}

/// 插件日志记录器
///
/// 为插件提供日志记录功能
class PluginLogger {
  /// 创建一个新的插件日志记录器实例。
  ///
  /// [pluginId] 插件的唯一标识符
  /// [level] 日志级别，默认为 LogLevel.info
  PluginLogger(this.pluginId, [this.level = LogLevel.info]);

  /// 插件的唯一标识符
  final String pluginId;
  
  /// 日志级别
  LogLevel level;

  void _log(LogLevel level, String message) {
    if (this.level.index > level.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.toString().split('.').last.toUpperCase();
    debugPrint('[$timestamp] [$levelStr] [$pluginId] $message');
  }

  /// 记录信息日志
  ///
  /// [message] 日志消息
  void info(String message) => _log(LogLevel.info, message);

  /// 记录警告日志
  ///
  /// [message] 日志消息
  void warning(String message) => _log(LogLevel.warning, message);

  /// 记录错误日志
  ///
  /// [message] 日志消息
  /// [error] 错误对象
  /// [stackTrace] 堆栈跟踪
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message);
    if (error != null) {
      debugPrint('  Error: $error');
      if (stackTrace != null) {
        debugPrint('  Stack trace:\n$stackTrace');
      }
    }
  }

  /// 记录调试日志
  ///
  /// [message] 日志消息
  void debug(String message) => _log(LogLevel.debug, message);
}

/// 日志级别
enum LogLevel {
  /// 调试级别
  debug,
  
  /// 信息级别
  info,
  
  /// 警告级别
  warning,
  
  /// 错误级别
  error
}

/// 插件 API 提供者
///
/// 为插件提供额外的 API 访问
class PluginAPIProvider {
  /// 创建一个新的插件 API 提供者实例。
  ///
  /// [storageAPI] 存储 API，用于文件读写等操作
  /// [uiAPI] UI API，用于对话框、菜单等操作
  PluginAPIProvider({this.storageAPI, this.uiAPI});

  /// 存储 API（文件读写等）
  final StorageAPI? storageAPI;

  /// UI API（对话框、菜单等）
  final UIAPI? uiAPI;
}

/// 存储 API
///
/// 提供文件存储访问
abstract class StorageAPI {
  /// 读取文件
  Future<String> readFile(String path);

  /// 写入文件
  Future<void> writeFile(String path, String content);

  /// 删除文件
  Future<void> deleteFile(String path);

  /// 检查文件是否存在
  Future<bool> exists(String path);

  /// 列出目录
  Future<List<String>> listDirectory(String path);
}

/// UI API
///
/// 提供 UI 相关功能
abstract class UIAPI {
  /// 显示对话框
  Future<T?> showDialog<T>({
    required String title,
    required WidgetBuilder contentBuilder,
  });

  /// 显示通知
  void showNotification(String message);

  /// 注册菜单项
  void registerMenuItem(String menuId, MenuItem item);

  /// 注销菜单项
  void unregisterMenuItem(String menuId, String itemId);
}

/// 菜单项
class MenuItem {
  /// 创建一个新的菜单项实例。
  ///
  /// [id] 菜单项的唯一标识符
  /// [label] 菜单项的显示文本
  /// [icon] 菜单项的图标
  /// [shortcut] 菜单项的快捷键
  /// [onPressed] 菜单项被点击时的回调函数
  MenuItem({
    required this.id,
    required this.label,
    this.icon,
    this.shortcut,
    this.onPressed,
  });

  /// 菜单项的唯一标识符
  final String id;
  
  /// 菜单项的显示文本
  final String label;
  
  /// 菜单项的图标
  final String? icon;
  
  /// 菜单项的快捷键
  final String? shortcut;
  
  /// 菜单项被点击时的回调函数
  final VoidCallback? onPressed;
}

/// Widget 类型别名
typedef WidgetBuilder = Widget Function(BuildContext);
