import 'package:flutter/widgets.dart';
import '../commands/command_bus.dart';
import '../events/app_events.dart';
import '../repositories/node_repository.dart';
import '../repositories/graph_repository.dart';
import 'api/api_registry.dart';
import 'dependency_container.dart';
import 'plugin_communication.dart';
import 'plugin_exception.dart';

/// 插件上下文
///
/// 提供插件与主系统交互的受限 API
/// 插件通过此上下文访问系统功能，但不能直接访问内部实现
class PluginContext {
  PluginContext({
    required this.pluginId,
    required this.commandBus,
    this.eventBus,
    this.logger,
    this.apiRegistry,
    this.nodeRepository,
    this.graphRepository,
    this.dependencyContainer,
    this.communication,
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

  /// 依赖注入容器
  final DependencyContainer? dependencyContainer;

  /// 插件通信接口
  final PluginCommunication? communication;

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
  T? getAPI<T>(String apiName) {
    return apiRegistry?.getAPI<T>(apiName);
  }

  /// 检查 API 是否存在
  ///
  /// [apiName] API 名称
  /// 返回 true 如果 API 已被其他插件导出
  bool hasAPI(String apiName) {
    return apiRegistry?.hasAPI(apiName) ?? false;
  }

  /// 获取 API 版本
  ///
  /// [apiName] API 名称
  /// 返回 API 版本，如果不存在则返回 null
  String? getAPIVersion(String apiName) {
    return apiRegistry?.getAPIVersion(apiName);
  }

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
    if (dependencyContainer != null && dependencyContainer!.contains<T>()) {
      return dependencyContainer!.get<T>();
    }

    // 向后兼容
    if (T == NodeRepository) {
      if (nodeRepository == null) {
        throw PluginStateException('plugin', 'uninitialized', 'NodeRepository available');
      }
      return nodeRepository as T;
    }
    if (T == GraphRepository) {
      if (graphRepository == null) {
        throw PluginStateException('plugin', 'uninitialized', 'GraphRepository available');
      }
      return graphRepository as T;
    }
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
    if (dependencyContainer != null && dependencyContainer!.contains<T>()) {
      return true;
    }

    // 向后兼容
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
  bool hasRepository<T>() {
    return hasDependency<T>();
  }

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
}

/// 插件日志记录器
///
/// 为插件提供日志记录功能
class PluginLogger {
  PluginLogger(this.pluginId, [this.level = LogLevel.info]);

  final String pluginId;
  LogLevel level;

  void _log(LogLevel level, String message) {
    if (this.level.index > level.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.toString().split('.').last.toUpperCase();
    debugPrint('[$timestamp] [$levelStr] [$pluginId] $message');
  }

  void info(String message) => _log(LogLevel.info, message);

  void warning(String message) => _log(LogLevel.warning, message);

  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message);
    if (error != null) {
      debugPrint('  Error: $error');
      if (stackTrace != null) {
        debugPrint('  Stack trace:\n$stackTrace');
      }
    }
  }

  void debug(String message) => _log(LogLevel.debug, message);
}

/// 日志级别
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// 插件 API 提供者
///
/// 为插件提供额外的 API 访问
class PluginAPIProvider {
  PluginAPIProvider({
    this.storageAPI,
    this.uiAPI,
  });

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
  MenuItem({
    required this.id,
    required this.label,
    this.icon,
    this.shortcut,
    this.onPressed,
  });

  final String id;
  final String label;
  final String? icon;
  final String? shortcut;
  final VoidCallback? onPressed;
}

/// Widget 类型别名
typedef WidgetBuilder = Widget Function(BuildContext);
