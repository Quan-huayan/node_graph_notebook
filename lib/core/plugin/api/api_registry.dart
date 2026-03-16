/// API 注册表
///
/// 管理插件导出的 API，支持插件间通信
///
/// 核心功能：
/// - 注册插件导出的 API
/// - 获取其他插件导出的 API
/// - 版本管理和依赖验证
/// - 插件卸载时自动清理
///
/// 使用示例：
/// ```dart
/// final registry = APIRegistry();
///
/// // 插件导出 API
/// registry.registerAPI('my_plugin', 'search_api', '1.0.0', SearchAPI());
///
/// // 其他插件获取 API
/// final searchAPI = registry.getAPI<SearchAPI>('search_api');
/// ```
class APIRegistry {
  /// 已注册的 API
  ///
  /// Key: API 名称
  /// Value: API 注册信息
  final Map<String, APIRegistration> _apis = {};

  /// 注册 API
  ///
  /// [pluginId] 插件 ID
  /// [apiName] API 名称（建议使用反向域名表示法，如 'com.example.search'）
  /// [version] API 版本（语义化版本）
  /// [api] API 实例
  ///
  /// 抛出 [APIAlreadyExistsException] 如果 API 已存在
  void registerAPI(
    String pluginId,
    String apiName,
    String version,
    dynamic api,
  ) {
    if (_apis.containsKey(apiName)) {
      throw APIAlreadyExistsException(
        apiName,
        _apis[apiName]!.pluginId,
        pluginId,
      );
    }

    _apis[apiName] = APIRegistration(
      pluginId: pluginId,
      apiName: apiName,
      version: version,
      api: api,
    );
  }

  /// 获取 API
  ///
  /// [apiName] API 名称
  /// 返回 API 实例，如果不存在则返回 null
  T? getAPI<T>(String apiName) {
    final registration = _apis[apiName];
    if (registration == null) return null;
    return registration.api as T?;
  }

  /// 检查 API 是否存在
  ///
  /// [apiName] API 名称
  /// 返回 true 如果 API 已注册
  bool hasAPI(String apiName) => _apis.containsKey(apiName);

  /// 获取 API 版本
  ///
  /// [apiName] API 名称
  /// 返回 API 版本，如果不存在则返回 null
  String? getAPIVersion(String apiName) => _apis[apiName]?.version;

  /// 注销插件的所有 API
  ///
  /// [pluginId] 插件 ID
  ///
  /// 插件卸载时调用，自动清理该插件导出的所有 API
  void unregisterPluginAPIs(String pluginId) {
    _apis.removeWhere((key, value) => value.pluginId == pluginId);
  }

  /// 获取所有已注册的 API
  ///
  /// 返回 API 名称列表
  List<String> getAllAPINames() => _apis.keys.toList();

  /// 获取插件导出的所有 API
  ///
  /// [pluginId] 插件 ID
  /// 返回该插件导出的 API 名称列表
  List<String> getPluginAPIs(String pluginId) => _apis.entries
        .where((entry) => entry.value.pluginId == pluginId)
        .map((entry) => entry.key)
        .toList();
}

/// API 注册信息
///
/// 记录已注册 API 的元数据
class APIRegistration {
  /// 创建一个 API 注册信息
  ///
  /// [pluginId] - 插件 ID
  /// [apiName] - API 名称
  /// [version] - API 版本
  /// [api] - API 实例
  APIRegistration({
    required this.pluginId,
    required this.apiName,
    required this.version,
    required this.api,
  });

  /// 插件 ID
  final String pluginId;

  /// API 名称
  final String apiName;

  /// API 版本
  final String version;

  /// API 实例
  final dynamic api;

  @override
  String toString() =>
      'APIRegistration(api: $apiName, version: $version, plugin: $pluginId)';
}

/// API 已存在异常
///
/// 当尝试注册已存在的 API 时抛出
class APIAlreadyExistsException implements Exception {
  /// 创建一个 API 已存在异常
  ///
  /// [apiName] - API 名称
  /// [existingPluginId] - 已注册该 API 的插件 ID
  /// [newPluginId] - 尝试注册该 API 的插件 ID
  APIAlreadyExistsException(
    this.apiName,
    this.existingPluginId,
    this.newPluginId,
  );

  /// API 名称
  final String apiName;

  /// 已注册该 API 的插件 ID
  final String existingPluginId;

  /// 尝试注册该 API 的插件 ID
  final String newPluginId;

  @override
  String toString() =>
      'API "$apiName" already registered by plugin "$existingPluginId", '
      'cannot register again by plugin "$newPluginId"';
}

/// 缺失 API 依赖异常
///
/// 当插件依赖的 API 未注册时抛出
class MissingAPIDependencyException implements Exception {
  /// 创建一个缺失 API 依赖异常
  ///
  /// [pluginId] - 插件 ID
  /// [missingAPI] - 缺失的 API 名称
  MissingAPIDependencyException(this.pluginId, this.missingAPI);

  /// 插件 ID
  final String pluginId;

  /// 缺失的 API 名称
  final String missingAPI;

  @override
  String toString() =>
      'Plugin "$pluginId" requires missing API dependency: "$missingAPI"';
}

/// API 版本异常
///
/// 当 API 版本不满足依赖要求时抛出
class APIVersionException implements Exception {
  /// 创建一个 API 版本异常
  ///
  /// [pluginId] - 插件 ID
  /// [apiName] - API 名称
  /// [requiredVersion] - 要求的版本
  /// [availableVersion] - 可用的版本
  APIVersionException(
    this.pluginId,
    this.apiName,
    this.requiredVersion,
    this.availableVersion,
  );

  /// 插件 ID
  final String pluginId;

  /// API 名称
  final String apiName;

  /// 要求的版本
  final String requiredVersion;

  /// 可用的版本
  final String availableVersion;

  @override
  String toString() =>
      'Plugin "$pluginId" requires API "$apiName" version $requiredVersion, '
      'but $availableVersion is available';
}
