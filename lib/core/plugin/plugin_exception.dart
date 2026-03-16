/// 插件异常基类
///
/// 所有插件相关异常的基类
abstract class PluginException implements Exception {
  /// 创建一个新的插件异常实例。
  ///
  /// [message] 错误消息
  /// [cause] 原始异常（如果有）
  PluginException(this.message, [this.cause]);

  /// 错误消息
  final String message;

  /// 原始异常（如果有）
  final dynamic cause;

  @override
  String toString() {
    if (cause != null) {
      return '$message: $cause';
    }
    return message;
  }
}

/// 插件未找到异常
class PluginNotFoundException extends PluginException {
  /// 创建一个新的插件未找到异常实例。
  ///
  /// [pluginId] 插件 ID
  PluginNotFoundException(String pluginId)
    : super('Plugin not found: $pluginId');
}

/// 插件已存在异常
class PluginAlreadyExistsException extends PluginException {
  /// 创建一个新的插件已存在异常实例。
  ///
  /// [pluginId] 插件 ID
  PluginAlreadyExistsException(String pluginId)
    : super('Plugin already exists: $pluginId');
}

/// 插件加载失败异常
class PluginLoadException extends PluginException {
  /// 创建一个新的插件加载失败异常实例。
  ///
  /// [pluginId] 插件 ID
  /// [cause] 原始异常
  PluginLoadException(String pluginId, [dynamic cause])
    : super('Failed to load plugin: $pluginId', cause);
}

/// 插件启用失败异常
class PluginEnableException extends PluginException {
  /// 创建一个新的插件启用失败异常实例。
  ///
  /// [pluginId] 插件 ID
  /// [cause] 原始异常
  PluginEnableException(String pluginId, [dynamic cause])
    : super('Failed to enable plugin: $pluginId', cause);
}

/// 插件禁用失败异常
class PluginDisableException extends PluginException {
  /// 创建一个新的插件禁用失败异常实例。
  ///
  /// [pluginId] 插件 ID
  /// [cause] 原始异常
  PluginDisableException(String pluginId, [dynamic cause])
    : super('Failed to disable plugin: $pluginId', cause);
}

/// 插件卸载失败异常
class PluginUnloadException extends PluginException {
  /// 创建一个新的插件卸载失败异常实例。
  ///
  /// [pluginId] 插件 ID
  /// [cause] 原始异常
  PluginUnloadException(String pluginId, [dynamic cause])
    : super('Failed to unload plugin: $pluginId', cause);
}

/// 插件依赖异常
class PluginDependencyException extends PluginException {
  /// 创建一个新的插件依赖异常实例。
  ///
  /// [message] 错误消息
  PluginDependencyException(super.message);
}

/// 循环依赖异常
class CircularDependencyException extends PluginDependencyException {
  /// 创建一个新的循环依赖异常实例。
  ///
  /// [cycle] 依赖循环
  CircularDependencyException(List<String> cycle)
    : super('Circular dependency detected: ${cycle.join(' -> ')}');
}

/// 缺失依赖异常
class MissingDependencyException extends PluginDependencyException {
  /// 创建一个新的缺失依赖异常实例。
  ///
  /// [pluginId] 插件 ID
  /// [missingDependency] 缺失的依赖
  MissingDependencyException(String pluginId, String missingDependency)
    : super(
        'Plugin "$pluginId" requires missing dependency: "$missingDependency"',
      );
}

/// 依赖版本不兼容异常
class DependencyVersionException extends PluginDependencyException {
  /// 创建一个新的依赖版本不兼容异常实例。
  ///
  /// [pluginId] 插件 ID
  /// [dependency] 依赖名称
  /// [requiredVersion] 所需版本
  /// [availableVersion] 可用版本
  DependencyVersionException(
    String pluginId,
    String dependency,
    String requiredVersion,
    String availableVersion,
  ) : super(
        'Plugin "$pluginId" requires "$dependency" version $requiredVersion, but $availableVersion is available',
      );
}

/// 插件权限异常
class PluginPermissionException extends PluginException {
  /// 创建一个新的插件权限异常实例。
  ///
  /// [pluginId] 插件 ID
  /// [permission] 缺少的权限
  PluginPermissionException(String pluginId, String permission)
    : super('Plugin "$pluginId" does not have permission: $permission');
}

/// 插件状态异常
class PluginStateException extends PluginException {
  /// 创建一个新的插件状态异常实例。
  ///
  /// [pluginId] 插件 ID
  /// [currentState] 当前状态
  /// [requiredState] 所需状态
  PluginStateException(
    String pluginId,
    String currentState,
    String requiredState,
  ) : super(
        'Plugin "$pluginId" is in state "$currentState", but required state is "$requiredState"',
      );
}

/// 插件配置异常
class PluginConfigurationException extends PluginException {
  /// 创建一个新的插件配置异常实例。
  ///
  /// [pluginId] 插件 ID
  /// [configError] 配置错误
  PluginConfigurationException(String pluginId, String configError)
    : super('Plugin "$pluginId" has invalid configuration: $configError');
}

/// 插件版本不兼容异常
class PluginVersionException extends PluginException {
  /// 创建一个新的插件版本不兼容异常实例。
  ///
  /// [pluginId] 插件 ID
  /// [pluginVersion] 插件版本
  /// [appVersion] 应用版本
  PluginVersionException(
    String pluginId,
    String pluginVersion,
    String appVersion,
  ) : super(
        'Plugin "$pluginId" version $pluginVersion is not compatible with app version $appVersion',
      );
}

/// 插件 API 变更异常
class PluginApiException implements Exception {
  /// 创建一个新的插件 API 异常实例。
  ///
  /// [message] 错误消息
  PluginApiException(this.message);

  /// 错误消息
  final String message;

  @override
  String toString() => 'Plugin API Error: $message';
}
