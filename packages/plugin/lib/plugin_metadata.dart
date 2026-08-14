/// 插件元数据。
///
/// 描述插件的基本信息：ID、名称、版本、依赖等。
class PluginMetadata {
  /// 创建插件元数据。
  const PluginMetadata({
    required this.id,
    required this.name,
    required this.version,
    this.description = '',
    this.author = '',
    this.dependencies = const [],
    this.enabledByDefault = true,
  });

  /// 插件唯一标识符（如 'com.example.myPlugin'）。
  final String id;

  /// 插件名称。
  final String name;

  /// 版本号（语义化版本）。
  final String version;

  /// 插件描述。
  final String description;

  /// 作者。
  final String author;

  /// 依赖的其他插件 ID 列表。
  final List<String> dependencies;

  /// 是否默认启用。
  final bool enabledByDefault;

  /// 检查插件是否与给定的应用版本兼容。
  bool isCompatibleWith(String appVersion) {
    // 简化版本兼容性检查：比较主版本号
    final pluginParts = version.split('.');
    final appParts = appVersion.split('.');
    if (pluginParts.isEmpty || appParts.isEmpty) return true;
    return pluginParts[0] == appParts[0];
  }
}
