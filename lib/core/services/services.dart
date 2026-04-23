/// 服务层导出
///
/// 提供应用的服务层组件
library;

// 数据恢复服务（将转换为插件）
export 'infrastructure/settings_registry.dart';
// 基础设施服务
export 'infrastructure/storage_path_service.dart';
export 'infrastructure/theme_registry.dart';
// 设置服务（保留向后兼容）
export 'settings_service.dart';
export 'shortcut_manager.dart';
export 'theme/app_theme.dart';
// 主题服务（保留向后兼容）
export 'theme_service.dart';
