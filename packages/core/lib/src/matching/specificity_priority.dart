/// 匹配优先序：全序（00 不变量 4.3-2/4）。
///
/// 命中多个 Concept 时按特异性排序：
/// requiredSlots ∪ requiredMetadataKeys 数量多者胜（特异性）；
/// 平局 → 注册序（先注册者胜）。
///
/// 全序优先序 + 纯结构匹配 ⇒ 结构确定性**与插件加载顺序无关、
/// 与 UIStateStore 无关**（00 不变量 4.3-4）。
library;

import 'package:core_data/core_data.dart';

/// 比较两个 Concept 的优先序。
///
/// 返回负值表示 [a] 特异性更高（应排在 [b] 前）；
/// 返回 0 表示特异性相同（由注册序平局）。
int compareConceptsBySpecificity(Concept a, Concept b) =>
    specificityScore(b) - specificityScore(a);

/// 特异性分数 = requiredSlots ∪ requiredMetadataKeys 的数量（02 §1.3）。
int specificityScore(Concept concept) =>
    concept.requiredSlots.length + concept.requiredMetadataKeys.length;
