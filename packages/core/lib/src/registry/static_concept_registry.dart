/// StaticConceptRegistry —— 注入列表的 ConceptRegistry（测试/宿主直装）。
///
/// 插件化场景请用 PluginConceptRegistry（扩展点实时派生，零同步）；
/// 本实现用于测试与静态装配（M5 重构前 ConceptRegistry 原实现）。
library;

import 'package:core_data/core_data.dart';

import '../fallback/fallback_concept.dart';
import '../matching/specificity_priority.dart';
import 'concept_registry.dart';

/// 构造注入的 Concept 匹配器。
class StaticConceptRegistry implements ConceptRegistry {
  /// 注册序注入 + 兜底注入（缺省为内置 FallbackConcept）。
  StaticConceptRegistry({
    required Iterable<Concept> concepts,
    Concept? fallback,
  }) : _concepts = List<Concept>.of(concepts),
       _fallback = fallback ?? const FallbackConcept();

  /// 注册序（先注册者胜）。
  final List<Concept> _concepts;

  /// 兜底 Concept：无 schema 命中时的降级渲染（00 不变量 4.3-3）。
  final Concept _fallback;

  @override
  Concept findFor(Node node) {
    final matched = _concepts.where((c) => c.validate(node)).toList();
    if (matched.isEmpty) {
      return _fallback;
    }
    matched.sort(compareConceptsBySpecificity);
    return matched.first;
  }

  @override
  List<Concept> findByMetadata(String key, dynamic value) =>
      _concepts.where((c) => c.metadataSchema.containsKey(key)).toList();

  @override
  Concept get fallback => _fallback;
}
