import 'extension_point.dart';

/// 一条贡献：插件（或宿主）向某扩展点提供的值。
class ExtensionContribution<T> {
  /// 构造：不可变贡献记录。
  ExtensionContribution({
    required this.point,
    required this.value,
    required this.priority,
    required this.registrationOrder,
    this.ownerPluginId,
  });

  /// 所属扩展点。
  final ExtensionPoint<T> point;

  /// 贡献的值。
  final T value;

  /// 优先级：值越小越靠前。
  final int priority;

  /// 注册序号：同优先级时的破平依据（注册表实例级计数器）。
  final int registrationOrder;

  /// 贡献者插件 id；null 表示宿主贡献（始终活跃）。
  final String? ownerPluginId;
}
