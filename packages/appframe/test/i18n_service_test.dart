/// I18nService 测试（P1-1：语言持久化——重启保持，00 §4.2 判据）。
library;

import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('语言持久化：setLanguage 保存 → 新实例 attach 恢复', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    final first = I18nService()..attach(prefs);
    expect(first.language, AppLanguage.zh);
    first.setLanguage(AppLanguage.en);
    expect(prefs.getString('settings.language'), 'en');

    // 模拟重启：新实例 + 同一 prefs → 恢复上次语言。
    final second = I18nService()..attach(prefs);
    expect(second.language, AppLanguage.en);
    expect(second.t('dialog.save'), 'Save');
  });

  test('持久化：损坏值 → 回退缺省中文（容错）', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.language': 'klingon',
    });
    final prefs = await SharedPreferences.getInstance();
    final service = I18nService()..attach(prefs);
    expect(service.language, AppLanguage.zh);
  });

  test('未绑定（null）→ 纯内存切换，不落盘', () {
    final service = I18nService()..attach(null);
    service.setLanguage(AppLanguage.en);
    expect(service.language, AppLanguage.en);
  });
}
