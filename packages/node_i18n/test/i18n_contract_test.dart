/// i18n 契约测试（P2-5）：
///
/// 1. 翻译表契约：zh/en 键集一致、无空值（新 key 缺译 = 违约）。
/// 2. t() 回退链：缺失键 → 键本身（翻译永不空洞，02 §2.3 同款
///    语义）；语言切换即时生效。
/// 3. I18nSettingsConcept 匹配契约：kind == 'settings-i18n' +
///    references.settings（设置容器反查聚合，04 §三 约束 3 落地）。
library;

import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_i18n/node_i18n.dart';

void main() {
  test('翻译表契约：zh/en 键集一致且无空值', () {
    expect(
      zhTranslations.keys.toSet(),
      enTranslations.keys.toSet(),
      reason: 'zh/en 必须同键（新文案缺任一语言 = 违约，05 纪律 7）',
    );
    for (final entry in zhTranslations.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: 'zh 空值: ${entry.key}');
    }
    for (final entry in enTranslations.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: 'en 空值: ${entry.key}');
    }
  });

  test('t() 回退链：缺失键 → 键本身；语言切换即时生效', () {
    final service = I18nService();
    expect(service.t('settings.language'), zhTranslations['settings.language']);
    expect(service.t('missing.key'), 'missing.key'); // 永不空洞。
    service.setLanguage(AppLanguage.en);
    expect(service.t('settings.language'), enTranslations['settings.language']);
    expect(service.language, AppLanguage.en);
  });

  test('I18nSettingsConcept 匹配契约：kind + settings 引用', () {
    const concept = I18nSettingsConcept();
    final now = DateTime.now();
    final valid = StoredNode(
      id: 's1',
      title: '语言',
      metadata: const <String, dynamic>{'kind': 'settings-i18n'},
      references: const <String, String>{'settings': 'settings-root'},
      createdAt: now,
      updatedAt: now,
    );
    expect(concept.validate(valid), isTrue);

    final noKind = StoredNode(
      id: 's2',
      title: '语言',
      metadata: const <String, dynamic>{},
      references: const <String, String>{'settings': 'settings-root'},
      createdAt: now,
      updatedAt: now,
    );
    expect(concept.validate(noKind), isFalse);

    final noRef = StoredNode(
      id: 's3',
      title: '语言',
      metadata: const <String, dynamic>{'kind': 'settings-i18n'},
      references: const <String, String>{},
      createdAt: now,
      updatedAt: now,
    );
    expect(concept.validate(noRef), isFalse);
  });
}
