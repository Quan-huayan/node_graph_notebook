/// PluginConceptRegistry —— 从 plugon 扩展点实时派生的归属查询器。
///
/// 注册/注销归 plugon（removeOwner 自动清理）；本实现只做查询侧：
/// findFor 每次从 `extensions.getActive(conceptPoint)` 实时派生——
/// 插件禁用 → 活跃贡献排除 → 无命中 → 兜底。**零同步**：无需
/// 重建注册表，降级自动生效（04 §1.5 / 00 不变量 4.3-3）。
library;

import 'package:core_data/core_data.dart';
import 'package:plugon/plugon.dart';

import '../fallback/fallback_concept.dart';
import '../matching/specificity_priority.dart';
import 'concept_registry.dart';
import 'extension_points.dart';

/// 从扩展点派生的 ConceptRegistry（04 §1.4 查询侧）。
class PluginConceptRegistry implements ConceptRegistry {
  /// 注入扩展注册表与兜底（缺省内置 FallbackConcept）。
  PluginConceptRegistry({required this.extensions, Concept? fallback})
    : _fallback = fallback ?? const FallbackConcept();

  /// plugon 扩展注册表（活跃贡献实时派生）。
  final ExtensionRegistry extensions;

  final Concept _fallback;

  @override
  Concept findFor(Node node) {
    final matched = extensions
        .getActive(conceptPoint)
        .where((c) => c.validate(node))
        .toList();
    if (matched.isEmpty) {
      return _fallback;
    }
    matched.sort(compareConceptsBySpecificity);
    return matched.first;
  }

  @override
  List<Concept> findByMetadata(String key, dynamic value) => extensions
      .getActive(conceptPoint)
      .where((c) => c.metadataSchema.containsKey(key))
      .toList();

  @override
  Concept get fallback => _fallback;
}
