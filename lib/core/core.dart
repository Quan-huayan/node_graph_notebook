/// 核心模块导出
///
/// 提供应用程序的核心功能和框架抽象
library;

// 命令系统
export 'commands/command_bus.dart';
export 'commands/models/command_context.dart';
export 'commands/models/command_handler.dart';
export 'commands/models/middleware.dart';
// 配置
export 'config/feature_flags.dart';
// 事件系统
export 'events/app_events.dart';
// 执行系统
export 'execution/cpu_task.dart';
export 'execution/execution_engine.dart';
export 'execution/gpu_executor.dart';
export 'execution/task_registry.dart';
// 核心模型
export 'models/models.dart';
// 插件系统
export 'plugin/plugin.dart';
export 'plugin/plugin_context.dart';
export 'plugin/plugin_manager.dart';
export 'plugin/ui_hooks/hook_registry.dart';
// 数据访问
export 'repositories/repositories.dart';
export 'services/infrastructure/settings_registry.dart';
// 基础设施服务
export 'services/infrastructure/storage_path_service.dart';
export 'services/infrastructure/theme_registry.dart';
export 'services/shortcut_manager.dart';
