# I18n 模块 Bug 报告

## Bug #1: LanguageToggleHook._switchLanguage() 使用错误的 BuildContext

**文件位置**: [language_toggle_hook.dart:107](file:///d:/Projects/node_graph_notebook/lib/plugins/i18n/hooks/language_toggle_hook.dart#L107)

**严重程度**: 高

**问题描述**:
`_switchLanguage` 方法中使用 `ScaffoldMessenger.of(context)` 显示 SnackBar，但传入的 `context` 是 AlertDialog 的 BuildContext，而非原始页面的 BuildContext。AlertDialog 的 context 中不存在 ScaffoldMessenger，这会导致运行时抛出异常。

**问题代码**:
```dart
void _showLanguageDialog(BuildContext context) {
  final i18n = I18n.of(context);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      // ...
      ListTile(
        onTap: () => _switchLanguage(ctx, i18n, 'en'),  // ctx 是 AlertDialog 的 context
      ),
      // ...
    ),
  );
}

void _switchLanguage(BuildContext context, I18n i18n, String language) {
  i18n.switchLanguage(language);
  Navigator.pop(context);

  // BUG: context 是 AlertDialog 的 context，不包含 ScaffoldMessenger
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
```

**影响**:
- 用户切换语言后，应用会抛出运行时异常
- SnackBar 无法正常显示
- 用户体验受损，语言切换功能无法正常完成

**建议修复**:
在 `_showLanguageDialog` 中保存原始 BuildContext，并在 `_switchLanguage` 中使用原始 context 来显示 SnackBar：

```dart
void _showLanguageDialog(BuildContext context) {
  final i18n = I18n.of(context);
  final scaffoldContext = context;  // 保存原始 context

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      // ...
      ListTile(
        onTap: () => _switchLanguage(ctx, scaffoldContext, i18n, 'en'),
      ),
      // ...
    ),
  );
}

void _switchLanguage(
  BuildContext dialogContext,
  BuildContext scaffoldContext,
  I18n i18n,
  String language,
) {
  i18n.switchLanguage(language);
  Navigator.pop(dialogContext);

  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
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
```
