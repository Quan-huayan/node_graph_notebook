import 'package:flutter/foundation.dart';

/// Hook API 注册表
///
/// 管理 Hook 导出的 API，支持 Hook 之间的 API 通信
///
/// 架构说明：
/// - 允许 Hook 导出 API 供其他 Hook 使用
/// - 解决旧系统中 UIHook 无法导出 API 的问题
/// - 支持命名空间，避免 API 名称冲突
/// - 提供类型安全的 API 访问
class HookAPIRegistry {
  /// 创建一个新的 Hook API 注册表实例
  HookAPIRegistry();

  /// 已注册的 API
  ///
  /// Key: API 名称（格式：'hook_id.api_name' 或 'api_name'）
  /// Value: API 实例
  final Map<String, dynamic> _apis = {};

  /// 注册 API
  ///
  /// [hookId] Hook 的唯一标识符
  /// [apiName] API 名称
  /// [api] API 实例
  ///
  /// 注意：API 会以 'hook_id.api_name' 的格式注册
  void registerAPI(String hookId, String apiName, dynamic api) {
    final qualifiedName = '$hookId.$apiName';

    if (_apis.containsKey(qualifiedName)) {
      debugPrint('[HookAPIRegistry] Warning: API already registered, '
          'overwriting: $qualifiedName');
    }

    _apis[qualifiedName] = api;
    debugPrint('[HookAPIRegistry] Registered API: $qualifiedName '
        '(type: ${api.runtimeType})');
  }

  /// 批量注册 API
  ///
  /// [hookId] Hook 的唯一标识符
  /// [apis] API Map（key: API 名称，value: API 实例）
  void registerAPIs(String hookId, Map<String, dynamic> apis) {
    for (final entry in apis.entries) {
      registerAPI(hookId, entry.key, entry.value);
    }
  }

  /// 注销 Hook 的所有 API
  ///
  /// [hookId] Hook 的唯一标识符
  ///
  /// 移除该 Hook 注册的所有 API
  void unregisterHookAPIs(String hookId) {
    final prefix = '$hookId.';
    final keysToRemove =
        _apis.keys.where((key) => key.startsWith(prefix)).toList();

    for (final key in keysToRemove) {
      _apis.remove(key);
      debugPrint('[HookAPIRegistry] Unregistered API: $key');
    }
  }

  /// 获取指定类型的 API
  ///
  /// [hookId] Hook 的唯一标识符
  /// [apiName] API 名称
  /// 返回指定类型的 API 实例，如果不存在或类型不匹配则返回 null
  T? getAPI<T>(String hookId, String apiName) {
    final api = getAPI(hookId, apiName);
    return api is T ? api : null;
  }

  /// 检查 API 是否存在
  ///
  /// [hookId] Hook 的唯一标识符
  /// [apiName] API 名称
  /// 返回 true 如果 API 存在
  bool hasAPI(String hookId, String apiName) {
    final qualifiedName = '$hookId.$apiName';
    return _apis.containsKey(qualifiedName);
  }

  /// 获取 Hook 导出的所有 API
  ///
  /// [hookId] Hook 的唯一标识符
  /// 返回该 Hook 导出的所有 API（不含前缀）
  Map<String, dynamic> getHookAPIs(String hookId) {
    final prefix = '$hookId.';
    final result = <String, dynamic>{};

    for (final entry in _apis.entries) {
      if (entry.key.startsWith(prefix)) {
        final apiName = entry.key.substring(prefix.length);
        result[apiName] = entry.value;
      }
    }

    return result;
  }

  /// 获取所有已注册的 API 名称
  ///
  /// 返回所有已注册的 API 的完整名称（包含 hook_id 前缀）
  List<String> getAllAPINames() => _apis.keys.toList();

  /// 清空所有 API
  ///
  /// 主要用于测试
  void clear() {
    _apis.clear();
  }

  /// 获取已注册的 API 总数
  int get count => _apis.length;

  @override
  String toString() =>
      'HookAPIRegistry(count: $count, apis: ${_apis.keys.join(", ")})';
}
