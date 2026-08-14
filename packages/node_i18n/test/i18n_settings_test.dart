/// 语言设置测试（M7.2：i18n 上移壳层——设置表单编辑壳层 I18nService，
/// 语言包全局可达、切换即时生效）。
library;

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_i18n/node_i18n.dart';

void main() {
  testWidgets('语言切换表单 → 壳层 I18nService 即时生效', (tester) async {
    final i18n = I18nService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: I18nSettingsForm(i18n: i18n)),
      ),
    );
    await tester.pump();

    expect(i18n.language, AppLanguage.zh);

    await tester.tap(find.text('English'));
    await tester.pump();

    expect(i18n.language, AppLanguage.en);
    expect(i18n.t('app.title'), 'Node Graph Notebook');
  });
}
