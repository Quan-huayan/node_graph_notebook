/// Hook 点定义 —— 描述一个可以被 Hook 扩展的位置。
///
/// 插件可以注册自定义 Hook 点，其他插件可以在该点挂载 Hook。
class HookPointDefinition {
  /// 创建 Hook 点定义。
  const HookPointDefinition({
    required this.id,
    required this.name,
    this.description = '',
    this.category = '',
    this.contextType,
  });

  /// Hook 点唯一标识。
  final String id;

  /// Hook 点显示名称。
  final String name;

  /// Hook 点描述。
  final String description;

  /// Hook 点分类。
  final String category;

  /// 上下文类型（用于文档/验证）。
  final Type? contextType;
}
