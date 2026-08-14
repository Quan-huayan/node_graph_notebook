/// appframe —— Flutter 壳（rewrite 架构，00-04 / architecture.md）。
///
/// M2：存储实现（文件层 + sidecar + FSTGraph + UIStateStore）。
/// M3：FlutterRenderContext（位置无关渲染目标）。
/// M4：DragController（拖拽事务）+ FlightShell（过渡渲染层）。
/// M6：QuadTree 空间索引 + QuadTreeViewportQuery（视口查询，资产带走）。
/// 依赖方向：core_data ← core ← appframe（04 §三）。
library;

export 'src/command/create_toolbar_button.dart';
export 'src/host/host_runtime.dart';
export 'src/host/vault_manager.dart';
export 'src/i18n/i18n_service.dart';
export 'src/i18n/translations.dart';
export 'src/interaction/drag_controller.dart';
export 'src/interaction/flight_shell.dart';
export 'src/render/flutter_render_context.dart';
export 'src/spatial/quad_tree.dart';
export 'src/spatial/quad_tree_viewport_query.dart';
export 'src/store/file_layer.dart';
export 'src/store/fs_graph.dart';
export 'src/store/fs_ui_state_store.dart';
export 'src/store/sidecar_store.dart';
export 'src/store/stored_node.dart';
export 'src/ui/app_shell.dart';
export 'src/ui/confirm_dialogs.dart';
export 'src/ui/hook_view.dart';
export 'src/ui/node_style.dart';
export 'src/ui/notebook_app.dart';
export 'src/ui/shell_signals.dart';
export 'src/ui/theme_controller.dart';
export 'src/ui/toolbar_actions_row.dart';
export 'src/ui/toolbar_concept.dart';
export 'src/ui/toolbar_container_concept.dart';
