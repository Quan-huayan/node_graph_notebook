/// 设置插件契约测试（P2-5）：
///
/// 1. ThemeSettingsConcept / AppearanceSettingsConcept 匹配契约
///    （kind + references.settings——设置容器反查聚合）。
/// 2. 主题表单 → ThemeController.mode 变化 + prefs 持久化回读
///    （P1-1 验收样式：重启后保持——新控制器 attach 同一 prefs
///    恢复同值）。
library;

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_settings/node_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

StoredNode _settingsNode(
  String id, {
  required String kind,
  bool withRef = true,
}) {
  final now = DateTime.now();
  return StoredNode(
    id: id,
    title: '条目',
    metadata: <String, dynamic>{'kind': kind},
    references: withRef
        ? const <String, String>{'settings': 'settings-root'}
        : const <String, String>{},
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('ThemeSettingsConcept 匹配契约：kind == settings-theme + settings 引用', () {
    const concept = ThemeSettingsConcept();
    expect(concept.validate(_settingsNode('t1', kind: 'settings-theme')), isTrue);
    expect(
      concept.validate(_settingsNode('t2', kind: 'settings-theme', withRef: false)),
      isFalse,
    );
    expect(concept.validate(_settingsNode('t3', kind: 'settings-other')), isFalse);
  });

  test('AppearanceSettingsConcept 匹配契约：kind == settings-appearance', () {
    const concept = AppearanceSettingsConcept();
    expect(
      concept.validate(_settingsNode('a1', kind: 'settings-appearance')),
      isTrue,
    );
    expect(
      concept.validate(_settingsNode('a2', kind: 'settings-appearance', withRef: false)),
      isFalse,
    );
  });

  testWidgets('主题表单切换 → ThemeController 变化 + 重启回读', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final theme = ThemeController()..attach(prefs);
    final i18n = I18nService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ThemeSettingsForm(theme: theme, i18n: i18n)),
      ),
    );
    await tester.tap(find.text(i18n.t('theme.dark')));
    await tester.pump();
    expect(theme.mode, AppThemeMode.dark);
    expect(prefs.getString('settings.themeMode'), 'dark');

    // 重启回读（P1-1 验收样式）：新控制器 attach 同一 prefs。
    final restarted = ThemeController()..attach(prefs);
    expect(restarted.mode, AppThemeMode.dark);
  });
}
