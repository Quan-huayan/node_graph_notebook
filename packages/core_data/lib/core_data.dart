/// core_data —— 纯数据模型契约（rewrite 架构，00-04 / architecture.md）。
///
/// 零平台依赖：不 import dart:ui / flutter（04 §三 约束）。
/// 所有接口的实现者与消费方见 architecture.md §3。
library;

export 'src/models/concept.dart';
export 'src/models/drop_semantics.dart';
export 'src/models/graph.dart';
export 'src/models/hook.dart';
export 'src/models/node.dart';
export 'src/models/ui_state_store.dart';
