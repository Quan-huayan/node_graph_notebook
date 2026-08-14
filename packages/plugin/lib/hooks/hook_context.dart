import '../plugin_context.dart';
import 'hook_api_registry.dart';

/// Hook 数据 Schema。
class HookDataSchema {
  /// 创建数据 Schema 定义。
  const HookDataSchema({
    required this.type,
    this.required = false,
    this.defaultValue,
    this.description,
  });

  /// 数据类型。
  final Type type;

  /// 是否必需。
  final bool required;

  /// 默认值。
  final dynamic defaultValue;

  /// 描述信息。
  final String? description;

  /// 验证值是否符合 Schema 定义。
  String? validate(dynamic value) {
    if (required && value == null) return 'Required value is missing';
    if (value == null) return null;
    if (value.runtimeType != type) return 'Expected type $type, got ${value.runtimeType}';
    return null;
  }
}

/// Hook 数据上下文异常。
class HookDataContextException implements Exception {
  /// 创建异常实例。
  const HookDataContextException(this.message);

  /// 错误消息。
  final String message;
  @override
  String toString() => 'HookDataContextException: $message';
}

/// Hook 上下文基础类。
abstract class HookContext {
  /// 创建 Hook 上下文。
  HookContext(
    this.data, {
    this.pluginContext,
    this.hookAPIRegistry,
    this.enableTypeValidation = false,
  }) : _dataSchemas = {};

  /// 上下文数据（Map-based，向后兼容）。
  final Map<String, dynamic> data;

  /// 插件上下文。
  final PluginContext? pluginContext;

  /// Hook API 注册表。
  final HookAPIRegistry? hookAPIRegistry;

  /// 是否启用类型验证。
  final bool enableTypeValidation;

  final Map<String, HookDataSchema> _dataSchemas;

  /// 注册数据 Schema。
  void registerSchema(String key, HookDataSchema schema) {
    _dataSchemas[key] = schema;
  }

  /// 获取数据。
  T? get<T>(String key) {
    final value = data[key];
    return value is T ? value : null;
  }

  /// 设置数据。
  void set(String key, dynamic value) {
    if (enableTypeValidation) {
      final schema = _dataSchemas[key];
      if (schema != null) {
        final error = schema.validate(value);
        if (error != null) {
          throw HookDataContextException('Data "$key" validation failed: $error');
        }
      }
    }
    data[key] = value;
  }

  /// 检查是否有数据。
  bool contains(String key) => data.containsKey(key);

  /// 获取其他 Hook 导出的 API。
  T? getHookAPI<T>(String hookId, String apiName) =>
      hookAPIRegistry?.getAPI<T>(hookId, apiName);

  /// 检查其他 Hook 是否导出了指定的 API。
  bool hasHookAPI(String hookId, String apiName) =>
      hookAPIRegistry?.hasAPI(hookId, apiName) ?? false;
}

/// 基础 Hook 上下文实现。
class BasicHookContext extends HookContext {
  /// 创建基础 Hook 上下文。
  BasicHookContext({
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
    bool enableTypeValidation = false,
  }) : super(
          data ?? {},
          pluginContext: pluginContext,
          hookAPIRegistry: hookAPIRegistry,
          enableTypeValidation: enableTypeValidation,
        );
}
