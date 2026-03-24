import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/services/i18n.dart';

/// I18n 重构验证测试
///
/// 验证 i18n 重构后的功能是否正常工作
void main() {
  group('I18n 重构验证', () {
    late I18n i18n;

    setUp(() {
      i18n = I18n();
    });

    test('应该能从生成的翻译数据加载翻译', () {
      // 测试基本翻译
      expect(i18n.t('Home'), equals('Home')); // 英文默认
      expect(i18n.t('Settings'), equals('Settings'));
      expect(i18n.t('Delete'), equals('Delete'));
    });

    test('应该能正确切换语言', () async {
      // 切换到中文
      await i18n.switchLanguage('zh');

      expect(i18n.currentLanguage, equals('zh'));
      expect(i18n.t('Home'), equals('主页'));
      expect(i18n.t('Settings'), equals('设置'));
      expect(i18n.t('Delete'), equals('删除'));

      // 切换回英文
      await i18n.switchLanguage('en');

      expect(i18n.currentLanguage, equals('en'));
      expect(i18n.t('Home'), equals('Home'));
    });

    test('应该能优雅降级（找不到翻译时返回原文）', () {
      // 切换到中文
      i18n.switchLanguage('zh');

      // 测试不存在的翻译键
      expect(i18n.t('NonExistentKey'), equals('NonExistentKey'));
      expect(i18n.t('Random Text'), equals('Random Text'));
    });

    test('应该能支持动态添加翻译', () {
      // 添加动态翻译
      i18n.addTranslation('zh', 'DynamicKey', '动态翻译');
      i18n.addTranslation('en', 'DynamicKey', 'Dynamic Translation');

      // 验证动态翻译
      expect(i18n.t('DynamicKey'), equals('Dynamic Translation')); // 英文

      i18n.switchLanguage('zh');
      expect(i18n.t('DynamicKey'), equals('动态翻译')); // 中文
    });

    test('应该能批量添加翻译', () {
      // 批量添加翻译
      i18n.addTranslations('zh', {
        'Key1': '翻译1',
        'Key2': '翻译2',
      });

      i18n.addTranslations('en', {
        'Key1': 'Translation1',
        'Key2': 'Translation2',
      });

      // 验证批量翻译
      expect(i18n.t('Key1'), equals('Translation1')); // 英文
      expect(i18n.t('Key2'), equals('Translation2'));

      i18n.switchLanguage('zh');
      expect(i18n.t('Key1'), equals('翻译1')); // 中文
      expect(i18n.t('Key2'), equals('翻译2'));
    });

    test('应该能检查语言支持', () {
      expect(i18n.supportsLanguage('en'), isTrue);
      expect(i18n.supportsLanguage('zh'), isTrue);
      expect(i18n.supportsLanguage('fr'), isFalse);
      expect(i18n.supportsLanguage('de'), isFalse);
    });

    test('应该能获取支持的语言列表', () {
      final languages = i18n.supportedLanguages;

      expect(languages, contains('en'));
      expect(languages, contains('zh'));
      expect(languages.length, greaterThanOrEqualTo(2));
    });

    test('应该能正确处理特殊字符翻译', () {
      i18n.switchLanguage('zh');

      // 测试包含特殊字符的翻译
      expect(i18n.t('AI Configuration'), equals('AI 配置'));
      expect(i18n.t('API Key'), equals('API 密钥'));
      expect(i18n.t('Ctrl+N: Create new node'), equals('Ctrl+N：创建新节点'));
    });

    test('应该能获取翻译统计信息', () {
      final stats = i18n.getTranslationStats();

      expect(stats, isNotEmpty);
      expect(stats.containsKey('en'), isTrue);
      expect(stats.containsKey('zh'), isTrue);
      expect(stats['en']! > 0, isTrue);
      expect(stats['zh']! > 0, isTrue);
    });

    test('动态翻译应该优先于静态翻译', () {
      // 添加覆盖静态翻译的动态翻译
      i18n.addTranslation('zh', 'Home', '主页（覆盖）');

      i18n.switchLanguage('zh');

      // 应该返回动态翻译
      expect(i18n.t('Home'), equals('主页（覆盖）'));
    });
  });
}
