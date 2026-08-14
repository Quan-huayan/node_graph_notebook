import 'package:core/core.dart';
import 'package:flutter/material.dart';

/// 设置 Hook 上下文
class SettingsHookContext extends HookContext {
  /// 创建一个新的设置 Hook 上下文实例。
  ///
  /// [currentSettings] 当前设置
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表
  /// [enableTypeValidation] 是否启用类型验证
  SettingsHookContext({
    Map<String, dynamic>? currentSettings,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
    bool enableTypeValidation = false,
  }) : super(
         data ?? {}
           ..['currentSettings'] = currentSettings,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
         enableTypeValidation: enableTypeValidation,
       );

  /// 当前设置
  Map<String, dynamic> get currentSettings =>
      get<Map<String, dynamic>>('currentSettings') ?? {};
}


/// 设置 Hook 基类
abstract class SettingsHookBase extends HookRoleBase {
  @override
  String get hookPointId => 'settings';

  @override
  Widget render(HookContext context) {
    final settingsContext = SettingsHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderSettings(settingsContext);
  }

  /// 渲染设置内容
  ///
  /// [context] 设置上下文
  /// 返回要渲染的 Widget
  Widget renderSettings(SettingsHookContext context);
}