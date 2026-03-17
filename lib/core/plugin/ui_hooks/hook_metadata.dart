/// Hook 元数据
///
/// 定义 UI Hook 的元数据信息，包括 ID、名称、版本等
///
/// 架构说明：
/// - HookMetadata 与 PluginMetadata 分离，避免 Hook 继承 Plugin 的重量级生命周期
/// - 提供可选的依赖声明，支持 Hook 之间的依赖关系
/// - 包含扩展信息字段，支持未来扩展
class HookMetadata {
  /// 创建一个新的 Hook 元数据实例。
  ///
  /// [id] Hook 唯一标识符（建议使用反向域名格式，如 'com.example.myHook'）
  /// [name] Hook 显示名称
  /// [version] Hook 版本号（遵循语义化版本规范）
  /// [description] Hook 描述信息
  /// [author] Hook 作者
  /// [dependencies] Hook 依赖的其他 Hook ID 列表
  const HookMetadata({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    this.author,
    this.dependencies = const [],
  });

  /// Hook 唯一标识符
  ///
  /// 建议格式：'com.example.plugin_name.hook_name'
  /// 示例：'com.example.graph.create_node_toolbar'
  final String id;

  /// Hook 显示名称
  ///
  /// 示例：'Create Node Toolbar Hook'
  final String name;

  /// Hook 版本号
  ///
  /// 遵循语义化版本规范：major.minor.patch
  /// 示例：'1.0.0'
  final String version;

  /// Hook 描述信息
  ///
  /// 可选，用于描述 Hook 的功能和用途
  final String? description;

  /// Hook 作者
  ///
  /// 可选，用于标识 Hook 的作者或维护者
  final String? author;

  /// Hook 依赖的其他 Hook ID 列表
  ///
  /// 可选，声明此 Hook 依赖的其他 Hook
  /// 系统将确保依赖的 Hook 先于此 Hook 加载
  ///
  /// 示例：['com.example.search.search_sidebar_hook']
  final List<String> dependencies;

  @override
  String toString() =>
      'HookMetadata($id, $name, v$version${dependencies.isEmpty ? '' : ', depends on: $dependencies'})';
}
