/// Hook API 注册表。
///
/// 管理 Hook 导出的 API，支持 Hook 之间的 API 通信。
class HookAPIRegistry {
  /// 创建 Hook API 注册表。
  HookAPIRegistry();

  final Map<String, dynamic> _apis = {};

  /// 注册 API。
  void registerAPI(String hookId, String apiName, dynamic api) {
    final qualifiedName = '$hookId.$apiName';
    _apis[qualifiedName] = api;
  }

  /// 批量注册 API。
  void registerAPIs(String hookId, Map<String, dynamic> apis) {
    for (final entry in apis.entries) {
      registerAPI(hookId, entry.key, entry.value);
    }
  }

  /// 注销 Hook 的所有 API。
  void unregisterHookAPIs(String hookId) {
    final prefix = '$hookId.';
    _apis.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// 获取指定类型的 API。
  T? getAPI<T>(String hookId, String apiName) {
    final api = _apis['$hookId.$apiName'];
    return api is T ? api : null;
  }

  /// 检查 API 是否存在。
  bool hasAPI(String hookId, String apiName) =>
      _apis.containsKey('$hookId.$apiName');

  /// 获取 Hook 导出的所有 API。
  Map<String, dynamic> getHookAPIs(String hookId) {
    final prefix = '$hookId.';
    final result = <String, dynamic>{};
    for (final entry in _apis.entries) {
      if (entry.key.startsWith(prefix)) {
        result[entry.key.substring(prefix.length)] = entry.value;
      }
    }
    return result;
  }

  /// 清空所有 API。
  void clear() => _apis.clear();

  /// 已注册 API 总数。
  int get count => _apis.length;
}
