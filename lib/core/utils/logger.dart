import 'package:flutter/foundation.dart';

/// 日志级别枚举
///
/// 定义了四个日志级别，从低到高依次为：
/// - debug: 调试信息，仅在开发阶段有用
/// - info: 一般信息，用于追踪程序流程
/// - warning: 警告信息，表示潜在问题
/// - error: 错误信息，表示发生了错误
/// 
enum LogLevel {
  /// 调试级别
  debug(500),

  /// 信息级别
  info(800),

  /// 警告级别
  warning(900),

  /// 错误级别
  error(1000),

  /// 无日志
  none(1200);

  const LogLevel(this.value);

  /// 日志级别值
  ///
  /// 对应 Dart 的 log 函数的 level 参数
  final int value;

  /// 比较两个日志级别
  /// 返回 true 如果当前级别大于或等于其他级别
  bool operator >=(LogLevel other) => value >= other.value;
  
  /// 比较两个日志级别
  /// 返回 true 如果当前级别小于或等于其他级别
  bool operator <=(LogLevel other) => value <= other.value;
}

/// 应用程序统一日志系统
///
/// 提供带日志级别的日志输出功能，支持运行时和编译时控制：
///
/// **特性：**
/// - 支持四种日志级别：debug、info、warning、error
/// - 可在运行时动态调整日志级别
/// - Release模式下自动提升最低日志级别到warning
/// - 使用标签（tag）组织日志，便于过滤和查找
/// - 性能优化：低于当前级别的日志不会执行字符串插值
///
/// **使用示例：**
/// ```dart
/// // 设置全局日志级别（默认为 info）
/// AppLogger.level = LogLevel.debug;
///
/// // 使用静态方法记录日志
/// AppLogger.debug('PluginManager', 'Loading plugin: $pluginId');
/// AppLogger.info('ServiceRegistry', 'Service registered: $serviceType');
/// AppLogger.warning('PluginManager', 'Dependency not found: $depId');
/// AppLogger.error('PluginManager', 'Failed to load plugin', error: e);
///
/// // 或使用带标签的Logger实例
/// final logger = AppLogger('PluginManager');
/// logger.debug('Loading plugin: $pluginId');
/// logger.info('Plugin loaded successfully');
/// ```
class AppLogger {

  /// 创建一个新的带标签的Logger实例
  ///
  /// [tag] 日志标签，用于标识日志来源
  ///
  /// 使用示例：
  /// ```dart
  /// final logger = AppLogger('PluginManager');
  /// logger.debug('Loading plugin...');
  /// logger.error('Failed to load', error: e);
  /// ```
  const AppLogger(this.tag);
  /// 当前日志级别
  ///
  /// 只有等于或高于此级别的日志才会输出
  /// 默认为 info，release模式下默认为 warning
  static LogLevel level = _getDefaultLevel();

  /// 全局启用/禁用日志
  ///
  /// 设置为 false 可完全关闭所有日志输出（包括错误日志）
  /// 默认为 true（kDebugMode 为 true 时）或 false（release 模式）
  static bool enabled = kDebugMode;

  /// 获取默认日志级别
  ///
  /// Debug模式：info级别
  /// Release模式：warning级别
  static LogLevel _getDefaultLevel() => kDebugMode ? LogLevel.info : LogLevel.warning;

  /// 日志标签
  final String tag;

  /// 记录调试级别日志
  ///
  /// [message] 日志消息
  /// [error] 关联的错误对象（可选）
  ///
  /// 调试日志仅在开发阶段有用，生产环境通常不输出
  void debug(String message, {Object? error}) {
    _log(LogLevel.debug, tag, message, error);
  }

  /// 记录信息级别日志
  ///
  /// [message] 日志消息
  /// [error] 关联的错误对象（可选）
  ///
  /// 信息日志用于追踪程序正常流程
  void info(String message, {Object? error}) {
    _log(LogLevel.info, tag, message, error);
  }

  /// 记录警告级别日志
  ///
  /// [message] 日志消息
  /// [error] 关联的错误对象（可选）
  ///
  /// 警告日志表示潜在问题，但不影响程序继续运行
  void warning(String message, {Object? error}) {
    _log(LogLevel.warning, tag, message, error);
  }

  /// 记录错误级别日志
  ///
  /// [message] 日志消息
  /// [error] 关联的错误对象（可选）
  ///
  /// 错误日志表示发生了错误，可能影响程序运行
  void error(String message, {Object? error}) {
    _log(LogLevel.error, tag, message, error);
  }

  /// 静态方法：记录调试级别日志
  ///
  /// [tag] 日志标签
  /// [message] 日志消息
  /// [error] 关联的错误对象（可选）
  static void debugTag(String tag, String message, {Object? error}) {
    _log(LogLevel.debug, tag, message, error);
  }

  /// 静态方法：记录信息级别日志
  ///
  /// [tag] 日志标签
  /// [message] 日志消息
  /// [error] 关联的错误对象（可选）
  static void infoTag(String tag, String message, {Object? error}) {
    _log(LogLevel.info, tag, message, error);
  }

  /// 静态方法：记录警告级别日志
  ///
  /// [tag] 日志标签
  /// [message] 日志消息
  /// [error] 关联的错误对象（可选）
  static void warningTag(String tag, String message, {Object? error}) {
    _log(LogLevel.warning, tag, message, error);
  }

  /// 静态方法：记录错误级别日志
  ///
  /// [tag] 日志标签
  /// [message] 日志消息
  /// [error] 关联的错误对象（可选）
  static void errorTag(String tag, String message, {Object? error}) {
    _log(LogLevel.error, tag, message, error);
  }

  /// 内部日志输出方法
  ///
  /// [level] 日志级别
  /// [tag] 日志标签
  /// [message] 日志消息
  /// [error] 关联的错误对象（可选）
  static void _log(LogLevel level, String tag, String message, [Object? error]) {
    // 性能优化：先检查级别，避免不必要的字符串操作
    if (!enabled || level.value < AppLogger.level.value) {
      return;
    }

    // 格式化日志消息
    final levelStr = _getLevelString(level);
    final formattedMessage = '[$levelStr] [$tag] $message';

    // 输出日志
    if (error != null) {
      debugPrint('$formattedMessage\n  Error: $error');
    } else {
      debugPrint(formattedMessage);
    }
  }

  /// 获取日志级别字符串
  static String _getLevelString(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.none:
        return 'NONE';
    }
  }

  /// 静态便捷方法：记录错误级别日志
  ///
  /// [tag] 日志标签
  /// [message] 日志消息
  /// [error] 关联的错误对象（可选）
  static void errorTagStatic(String tag, String message, {Object? error}) =>
      errorTag(tag, message, error: error);
}
