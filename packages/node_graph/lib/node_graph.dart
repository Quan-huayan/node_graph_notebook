/// node_graph —— 画布插件（rewrite 架构，00-04 / architecture.md）。
///
/// M6 试金石（04 里程碑）：画布容器 Concept（UIMove 判据② 判定）、
/// 定位卡片渲染、相机持久化、可见性管理对话框、视口空间索引。
/// 依赖方向：core_data ← core ← appframe ← plugins/*（04 §三）。
library;

export 'graph_plugin.dart';
export 'src/canvas_concept.dart';
export 'src/canvas_widget.dart';
export 'src/connection_concept.dart';
export 'src/global_graph_dialog.dart';
export 'src/graph_nodes_dialog.dart';
export 'src/layout/layout_algorithms.dart';
export 'src/layout/layout_commands.dart';
export 'src/layout/layout_dialog.dart';
export 'src/layout/layout_engine.dart';
export 'src/node_card.dart';
export 'src/node_commands.dart';
export 'src/node_dialogs.dart';
export 'src/node_style_dialog.dart';
