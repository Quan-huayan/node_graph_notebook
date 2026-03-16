import 'package:flutter/material.dart';

import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/ui_hook.dart';
import '../../../core/services/i18n.dart';

/// 国际化插件
///
/// 提供多语言支持和语言切换功能
class I18nPlugin extends MainToolbarHook {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'i18n',
        name: '国际化',
        version: '1.0.0',
        description: '提供多语言支持和界面汉化',
        author: 'Node Graph Notebook',
        enabledByDefault: true,
      );

  @override
  int get priority => 30;

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;

    if (buildContext == null) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.translate, color: Colors.blue),
      tooltip: I18n.of(buildContext).t('Language'),
      onPressed: () => _showLanguageDialog(context, buildContext),
    );
  }

  /// 显示语言选择对话框
  void _showLanguageDialog(
    MainToolbarHookContext context,
    BuildContext buildContext,
  ) {
    final i18n = I18n.of(buildContext);

    showDialog(
      context: buildContext,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.t('Select Language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇺🇸'),
              title: const Text('English'),
              trailing: i18n.currentLanguage == 'en'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                _switchLanguage(ctx, i18n, 'en');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Text('🇨🇳'),
              title: const Text('简体中文'),
              trailing: i18n.currentLanguage == 'zh'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                _switchLanguage(ctx, i18n, 'zh');
              },
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
  void _switchLanguage(BuildContext context, I18n i18n, String language) {
    i18n.switchLanguage(language);
    Navigator.pop(context);

    // 显示切换成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Language switched to ${language == 'zh' ? '简体中文' : 'English'}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Future<void> onInit() async {}

  @override
  Future<void> onDispose() async {}

  @override
  Future<void> onLoad(PluginContext context) async {
    context.info('I18n plugin loaded');
  }

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onUnload() async {}
}
