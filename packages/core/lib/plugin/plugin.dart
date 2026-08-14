// 插件系统核心导出
//
// 旧插件系统已迁至 packages/plugin/ 独立包。
// 此 barrel 只保留向后兼容的 re-export。

export 'package:plugin/plugin.dart';
export 'package:shared_preferences/shared_preferences.dart' show SharedPreferencesAsync;

// 核心基础设施（插件常用类型）
export '../../../cqrs/commands/command_bus.dart' show CommandBus;
export '../../../cqrs/query/query_bus.dart' show QueryBus;
export '../../../execution/execution_engine.dart' show ExecutionEngine;
export '../../../execution/task_registry.dart' show TaskRegistry;
export '../../../infrastructure/settings_registry.dart' show SettingsRegistry;
export '../../../infrastructure/theme_registry.dart' show ThemeRegistry;
