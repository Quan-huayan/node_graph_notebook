/// core —— 机制层（rewrite 架构，00-04 / architecture.md）。
///
/// 纯 Dart，零 Flutter import（04 §三 约束 2）：Lua 与测试可在
/// core 层直接使用机制。DI / ExtensionRegistry / PluginManager /
/// Plugin 契约依赖 package:plugon（architecture.md §2）。
library;

export 'src/command/command.dart';
export 'src/command/command_bus.dart';
export 'src/command/exceptions.dart';
export 'src/command/move_references.dart';
export 'src/command/node_commands.dart';
export 'src/command/plugin_command_bus.dart';
export 'src/command/undo_manager.dart';
export 'src/cycle/acyclic_checker.dart';
export 'src/fallback/fallback_concept.dart';
export 'src/invalidation/hook_index.dart';
export 'src/invalidation/router.dart';
export 'src/matching/specificity_priority.dart';
export 'src/registry/concept_registry.dart';
export 'src/registry/extension_points.dart';
export 'src/registry/plugin_concept_registry.dart';
export 'src/registry/static_concept_registry.dart';
export 'src/ui_manager/materializer.dart';
export 'src/ui_manager/materializer_impl.dart';
export 'src/ui_manager/ui_manager.dart';
export 'src/ui_manager/value_rect.dart';
export 'src/ui_manager/viewport_query.dart';
export 'src/ui_manager/window.dart';
export 'src/ui_manager/window_manager_impl.dart';
export 'src/ui_manager/windowed_ui_manager.dart';
