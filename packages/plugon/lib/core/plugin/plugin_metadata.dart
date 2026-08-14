/// 插件声明式元数据（不可变）。
class PluginMetadata {
  /// 构造：声明式元数据。
  const PluginMetadata({
    required this.id,
    required this.name,
    required this.version,
    this.dependencies = const [],
    this.enabledByDefault = true,
  });

  /// 插件唯一 id（插件间依赖、服务 owner、扩展贡献者均以此为键）。
  final String id;

  /// 展示名。
  final String name;

  /// 版本号。
  final String version;

  /// 依赖的插件 id 列表（启用时按拓扑序先启用依赖）。
  final List<String> dependencies;

  /// 加载后是否立即启用。
  final bool enabledByDefault;
}
