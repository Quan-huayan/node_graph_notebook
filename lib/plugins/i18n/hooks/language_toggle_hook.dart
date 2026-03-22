import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../../core/plugin/ui_hooks/hook_priority.dart';
import '../../../../core/services/i18n.dart';

/// 语言切换 Hook
///
/// 在主工具栏提供语言切换按钮
///
/// 功能：
/// - 显示翻译图标按钮
/// - 打开语言选择对话框
/// - 支持中英文切换
/// - 实时更新界面语言
class LanguageToggleHook extends MainToolbarHookBase {
  /// 构造函数
  LanguageToggleHook();

  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'i18n.language_toggle',
    name: 'Language Toggle',
    version: '1.0.0',
    description: 'Provide language toggle functionality in toolbar',
  );

  @override
  HookPriority get priority => HookPriority.medium;

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;

    // 如果没有 BuildContext，返回空组件
    if (buildContext == null) {
      return const SizedBox.shrink();
    }

    // 使用Consumer监听语言变化
    return Consumer<I18n>(
      builder: (ctx, i18n, child) => IconButton(
          icon: const Icon(Icons.translate, color: Colors.blue),
          tooltip: i18n.t('Language'),
          onPressed: () => _showLanguageDialog(buildContext),
        ),
    );
  }

  /// 显示语言选择对话框
  ///
  /// [context] BuildContext 用于显示对话框
  void _showLanguageDialog(BuildContext context) {
    final i18n = I18n.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.t('Select Language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 英语选项
            ListTile(
              leading: const Text('🇺🇸'),
              title: const Text('English'),
              trailing: i18n.currentLanguage == 'en'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => _switchLanguage(ctx, i18n, 'en'),
            ),
            const Divider(),
            // 中文选项
            ListTile(
              leading: const Text('🇨🇳'),
              title: const Text('简体中文'),
              trailing: i18n.currentLanguage == 'zh'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => _switchLanguage(ctx, i18n, 'zh'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(i18n.t('Close')),
          ),
        ],
      ),
    );
  }

  /// 切换语言
  ///
  /// [context] BuildContext 用于关闭对话框和显示提示
  /// [i18n] I18n 服务实例
  /// [language] 目标语言代码 ('en' 或 'zh')
  void _switchLanguage(BuildContext context, I18n i18n, String language) {
    i18n.switchLanguage(language);
    Navigator.pop(context);

    // 显示切换成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          language == 'zh'
              ? '已切换到简体中文'
              : 'Switched to English',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
