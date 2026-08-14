import 'package:flutter/material.dart';

import 'hook_context.dart';

/// Hook 工厂函数类型。
typedef HookFactory = HookRoleBase Function();

/// Hook 优先级。
enum HookPriority {
  /// 关键优先级。
  critical(0),
  /// 最高优先级。
  highest(10),
  /// 高优先级。
  high(100),
  /// 自定义优先级 50。
  custom50(50),
  /// 自定义优先级 60。
  custom60(60),
  /// 自定义优先级 70。
  custom70(70),
  /// 自定义优先级 80。
  custom80(80),
  /// 自定义优先级 150。
  custom150(150),
  /// 自定义优先级 200。
  custom200(200),
  /// 自定义优先级 250。
  custom250(250),
  /// 自定义优先级 300。
  custom300(300),
  /// 中等优先级。
  medium(500),
  /// 低优先级。
  low(900),
  /// 最低优先级。
  lowest(1000);

  const HookPriority(this.value);

  /// 优先级数值（越小越优先）。
  final int value;
}

/// Hook 元数据。
class HookMetadata {
  /// 创建 Hook 元数据。
  const HookMetadata({
    required this.id,
    this.name = '',
    this.description = '',
    this.version = '1.0.0',
  });

  /// Hook 唯一标识。
  final String id;

  /// Hook 名称。
  final String name;

  /// Hook 描述。
  final String description;

  /// Hook 版本号。
  final String version;
}

/// Hook 基础类。
///
/// 生命周期：构造 → onInit(context) → onEnable() → onDisable() → onDispose()
abstract class HookRoleBase {
  /// 获取 Hook 元数据。
  HookMetadata get metadata;

  /// Hook 注册到的 Hook 点 ID。
  String get hookPointId;

  /// 优先级（排序用）。
  HookPriority get priority => HookPriority.medium;

  /// 渲染 Hook 内容。
  Widget render(HookContext context);

  /// 是否可见。
  bool isVisible(HookContext context) => true;

  /// 初始化（仅一次）。
  Future<void> onInit(HookContext context) async {}

  /// 启用（可多次）。
  Future<void> onEnable() async {}

  /// 禁用（可多次）。
  Future<void> onDisable() async {}

  /// 销毁（仅一次）。
  Future<void> onDispose() async {}

  /// 导出 Hook API（供其他 Hook 使用）。
  Map<String, dynamic> exportAPIs() => {};

  @override
  String toString() =>
      'HookRoleBase(${metadata.id}, point: $hookPointId, priority: $priority)';
}
