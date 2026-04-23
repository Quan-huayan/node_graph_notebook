# 对话框模块 Bug 报告

**审查日期**: 2026-04-21
**审查范围**: `lib/ui/dialogs` 文件夹（settings_dialog.dart、shortcut_help_dialog.dart）

---

## Bug 1: 字体选择器无法选择"System Default"（null 值被过滤）

### 位置
- [settings_dialog.dart:601-607](file:///d:/Projects/node_graph_notebook/lib/ui/dialogs/settings_dialog.dart#L601-L607)

### 严重程度
**严重**

### 问题描述
`_showFontSelector` 方法中，`RadioGroup<String?>` 的 `onChanged` 回调检查 `if (value != null)`，当用户选择"System Default"选项（对应 `value` 为 `null`）时，条件不满足，选择被静默忽略。用户无法将字体恢复为系统默认。

### 问题代码
```dart
RadioGroup<String?>(
  groupValue: currentFont,
  onChanged: (value) async {
    if (value != null) {           // <-- null 被过滤，无法选择 System Default
      await themeService.updateCustomTheme(fontFamily: value);
      if (ctx.mounted) {
        Navigator.pop(ctx);
      }
    }
  },
  child: ListView.builder(
    itemCount: fonts.length,
    itemBuilder: (context, index) {
      final font = fonts[index];   // fonts[0] 为 null，即 System Default
      // ...
      return RadioListTile<String?>(
        // ...
        value: font,               // value 可以为 null
      );
    },
  ),
),
```

### 触发场景
1. 打开设置对话框
2. 点击"Font"进入字体选择器
3. 当前字体为非系统默认字体（如"Microsoft YaHei"）
4. 点击"System Default"选项 → 无任何反应，选择被忽略

### 影响
- 用户一旦选择了自定义字体，就无法恢复为系统默认字体
- "System Default"选项在 UI 中存在但完全无效，造成用户困惑
- 与颜色选择器中类似的 null 处理 Bug（见 menus_bugs.md Bug 5）属于同一类问题

### 修复建议
移除 `if (value != null)` 条件，允许 null 值通过。`updateCustomTheme` 应能接受 null 表示恢复默认：

```dart
RadioGroup<String?>(
  groupValue: currentFont,
  onChanged: (value) async {
    await themeService.updateCustomTheme(fontFamily: value);
    if (ctx.mounted) {
      Navigator.pop(ctx);
    }
  },
  // ...
),
```

如果 `updateCustomTheme` 不接受 null，则需要在调用前做转换：

```dart
onChanged: (value) async {
  if (value == null) {
    await themeService.resetFontFamily();
  } else {
    await themeService.updateCustomTheme(fontFamily: value);
  }
  if (ctx.mounted) {
    Navigator.pop(ctx);
  }
},
```

---

## Bug 2: "Restart" 按钮无任何功能实现

### 位置
- [settings_dialog.dart:451-455](file:///d:/Projects/node_graph_notebook/lib/ui/dialogs/settings_dialog.dart#L451-L455)

### 严重程度
**中等**

### 问题描述
`_showStoragePathSelector` 方法中，当用户选择新的存储位置后，SnackBar 显示一个"Restart"操作按钮，但该按钮的 `onPressed` 回调为空（仅有一行注释），点击后无任何效果。

### 问题代码
```dart
SnackBar(
  content: Text('${i18n.t('Storage location changed to:')} $newPath'),
  duration: const Duration(seconds: 3),
  action: SnackBarAction(
    label: i18n.t('Restart'),
    onPressed: () {
      // 提示用户需要重启应用
    },
  ),
),
```

### 触发场景
1. 打开设置对话框
2. 点击"Storage Location"
3. 点击"Choose New Location"并选择新路径
4. SnackBar 弹出，显示"Restart"按钮
5. 点击"Restart"按钮 → 无任何反应

### 影响
- 用户期望点击"Restart"能重启应用，但按钮完全无效
- 误导性 UI：按钮存在暗示有重启功能，但实际未实现
- 用户可能不知道如何手动重启应用来使存储路径更改生效

### 修复建议
方案一：实现应用重启功能（推荐）：

```dart
action: SnackBarAction(
  label: i18n.t('Restart'),
  onPressed: () {
    // 使用 Application.restart() 或进程重启
    SystemNavigator.restart();
  },
),
```

方案二：如果无法实现重启，移除按钮，改为在 SnackBar 文案中提示用户手动重启：

```dart
SnackBar(
  content: Text(i18n.t('Storage location changed. Please restart the app manually.')),
  duration: const Duration(seconds: 5),
),
```

---

## Bug 3: FutureBuilder 在每次重建时重新创建 Future，导致闪烁和性能浪费

### 位置
- [settings_dialog.dart:57-76](file:///d:/Projects/node_graph_notebook/lib/ui/dialogs/settings_dialog.dart#L57-L76)

### 严重程度
**中等**

### 问题描述
`build()` 方法中，`settingsService.getStorageUsage()` 直接作为 `FutureBuilder` 的 `future` 参数传入。由于 `build()` 方法通过 `context.watch<UIBloc>()`、`context.watch<SettingsService>()` 和 `context.watch<ThemeService>()` 订阅了多个状态变化，任何状态改变都会触发重建，每次重建都会创建一个新的 Future，导致 `FutureBuilder` 重新执行异步计算。

### 问题代码
```dart
@override
Widget build(BuildContext context) {
  final uiBloc = context.watch<UIBloc>();        // 订阅 UIBloc
  final settingsService = context.watch<SettingsService>();  // 订阅 SettingsService
  final theme = context.watch<ThemeService>().themeData;     // 订阅 ThemeService
  // ...
  FutureBuilder<StorageUsage>(
    future: settingsService.getStorageUsage(),  // 每次重建都创建新 Future
    builder: (context, snapshot) {
      // ...
    },
  ),
}
```

### 触发场景
1. 打开设置对话框，存储用量正常显示
2. 切换主题 → UIBloc/ThemeService 状态变化 → build() 重建 → FutureBuilder 重新执行
3. 切换侧边栏开关 → UIBloc 状态变化 → build() 重建 → FutureBuilder 重新执行
4. 每次重建时，存储用量显示会短暂回到 "calculating..." 状态再恢复

### 影响
- 频繁的异步调用浪费系统资源
- UI 闪烁：每次重建时，存储用量信息短暂消失后重新出现
- 用户体验差：看起来像是数据丢失后又恢复

### 修复建议
将 Future 缓存为 State 字段，仅在初始化时创建一次：

```dart
class _SettingsDialogState extends State<SettingsDialog> {
  Future<StorageUsage>? _storageUsageFuture;

  @override
  void initState() {
    super.initState();
    _storageUsageFuture = context.read<SettingsService>().getStorageUsage();
  }

  @override
  Widget build(BuildContext context) {
    // ...
    FutureBuilder<StorageUsage>(
      future: _storageUsageFuture,  // 使用缓存的 Future
      builder: (context, snapshot) {
        // ...
      },
    ),
  }
}
```

如果需要在存储路径变更后刷新，可在路径变更后重新赋值：

```dart
setState(() {
  _storageUsageFuture = settingsService.getStorageUsage();
});
```

---

## Bug 4: ShortcutsDialog 未设置自定义主题背景色，主题不一致

### 位置
- [shortcut_help_dialog.dart:13](file:///d:/Projects/node_graph_notebook/lib/ui/dialogs/shortcut_help_dialog.dart#L13)

### 严重程度
**中等**

### 问题描述
`ShortcutsDialog` 的 `AlertDialog` 没有设置 `backgroundColor` 属性，也没有引入 `ThemeService`。而 `SettingsDialog` 中所有对话框都设置了 `backgroundColor: theme.backgrounds.primary`。当应用使用自定义主题（非默认 Material 主题）时，`ShortcutsDialog` 会使用 Flutter 默认的对话框背景色，与应用主题产生视觉不一致。

### 问题代码
```dart
return AlertDialog(
  title: Text(i18n.t('Keyboard Shortcuts')),  // 无 backgroundColor 设置
  content: SizedBox(
    // ...
  ),
  // ...
);
```

对比 `SettingsDialog` 中的正确实现：
```dart
return AlertDialog(
  backgroundColor: theme.backgrounds.primary,  // 使用自定义主题色
  title: Text(i18n.t('Settings')),
  // ...
);
```

### 触发场景
1. 应用使用深色自定义主题
2. 打开快捷键帮助对话框 → 对话框背景为 Material 默认色（浅色），与应用深色主题不协调
3. 打开设置对话框 → 对话框背景正确使用自定义主题色
4. 两个对话框的视觉风格不一致

### 影响
- 自定义主题下对话框背景色与应用主题不匹配
- 与 SettingsDialog 的主题处理方式不一致，违反 UI 一致性原则
- 深色模式下可能出现白色对话框弹出的刺眼效果

### 修复建议
引入 `ThemeService` 并设置 `backgroundColor`：

```dart
import '../../core/services/services.dart';

class ShortcutsDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final theme = context.watch<ThemeService>().themeData;

    return AlertDialog(
      backgroundColor: theme.backgrounds.primary,
      title: Text(i18n.t('Keyboard Shortcuts')),
      // ...
    );
  }
}
```

---

## Bug 5: `_showStoragePathSelector` 中 await 后使用 context 未检查 mounted

### 位置
- [settings_dialog.dart:355-359](file:///d:/Projects/node_graph_notebook/lib/ui/dialogs/settings_dialog.dart#L355-L359)

### 严重程度
**低**

### 问题描述
`_showStoragePathSelector` 方法标记为 `async`，在 `await settingsService.getStoragePath()` 之后直接使用 `context` 调用 `showDialog`，未检查 `mounted` 属性。如果 `getStoragePath()` 执行期间 widget 被销毁（如用户快速关闭对话框），使用已失效的 `context` 会导致运行时异常。

### 问题代码
```dart
void _showStoragePathSelector(
  BuildContext context,
  SettingsService settingsService,
) async {
  final i18n = I18n.of(context);
  final currentPath = await settingsService.getStoragePath();  // 异步等待

  showDialog(                     // await 后直接使用 context，未检查 mounted
    context: context,
    builder: (ctx) {
      // ...
    },
  );
}
```

### 触发场景
1. 打开设置对话框
2. 点击"Storage Location"
3. `getStoragePath()` 开始异步执行
4. 在异步操作完成前，用户关闭设置对话框（widget 被销毁）
5. `getStoragePath()` 返回后，`context` 已失效，`showDialog` 可能抛出异常

### 影响
- 潜在的运行时异常："Looking up a deactivated widget's ancestor is unsafe"
- 虽然触发概率较低（`getStoragePath()` 通常很快完成），但在慢速存储设备上可能出现

### 修复建议
在 `await` 之后添加 `mounted` 检查：

```dart
void _showStoragePathSelector(
  BuildContext context,
  SettingsService settingsService,
) async {
  final i18n = I18n.of(context);
  final currentPath = await settingsService.getStoragePath();

  if (!mounted) return;  // 添加 mounted 检查

  showDialog(
    context: context,
    builder: (ctx) {
      // ...
    },
  );
}
```

---

## Bug 6: `_showStoragePathSelector` 中嵌套对话框变量名遮蔽（shadowing）

### 位置
- [settings_dialog.dart:405](file:///d:/Projects/node_graph_notebook/lib/ui/dialogs/settings_dialog.dart#L405)

### 严重程度
**低**

### 问题描述
`_showStoragePathSelector` 方法中，外层对话框的 builder 参数名为 `ctx`（第 361 行），而"Reset to Default"确认对话框的 builder 参数名也是 `ctx`（第 405 行），形成变量遮蔽。虽然由于 Dart 的作用域规则，代码功能上是正确的（内层 `ctx` 仅在内层 builder 作用域内有效，外层 `ctx` 在 `showDialog` 返回后恢复可见），但这种命名方式极易引起混淆，增加维护风险。

### 问题代码
```dart
showDialog(
  context: context,
  builder: (ctx) {                    // 外层 ctx
    return AlertDialog(
      actions: [
        TextButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) {          // 内层 ctx，遮蔽外层 ctx
                return AlertDialog(
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),  // 内层 ctx
                      // ...
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),   // 内层 ctx
                      // ...
                    ),
                  ],
                );
              },
            );

            if ((confirmed ?? false) && context.mounted) {
              await settingsService.setCustomStoragePath(null);
              Navigator.pop(ctx);       // 外层 ctx（此处正确，但易混淆）
              // ...
            }
          },
          // ...
        ),
      ],
    );
  },
);
```

### 影响
- 代码可读性差，需要仔细分辨 `ctx` 的作用域
- 容易在修改时误用错误的 context
- 与 menus_bugs.md Bug 3 属于同一类问题

### 修复建议
使用不同的变量名避免遮蔽：

```dart
showDialog(
  context: context,
  builder: (outerCtx) {                // 重命名为 outerCtx
    return AlertDialog(
      actions: [
        TextButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogCtx) {    // 重命名为 dialogCtx
                return AlertDialog(
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      // ...
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, true),
                      // ...
                    ),
                  ],
                );
              },
            );

            if ((confirmed ?? false) && context.mounted) {
              await settingsService.setCustomStoragePath(null);
              Navigator.pop(outerCtx);  // 清晰：使用外层 context
              // ...
            }
          },
          // ...
        ),
      ],
    );
  },
);
```

---

## 总结

| Bug ID | 严重程度 | 文件 | 问题类型 |
|--------|----------|------|----------|
| Bug 1 | 严重 | settings_dialog.dart | 功能缺陷：无法选择 System Default 字体 |
| Bug 2 | 中等 | settings_dialog.dart | 功能缺失：Restart 按钮无实现 |
| Bug 3 | 中等 | settings_dialog.dart | 性能/体验：FutureBuilder 重复创建 Future |
| Bug 4 | 中等 | shortcut_help_dialog.dart | 主题不一致：缺少自定义背景色 |
| Bug 5 | 低 | settings_dialog.dart | 潜在异常：await 后未检查 mounted |
| Bug 6 | 低 | settings_dialog.dart | 代码质量：变量名遮蔽 |

### 优先级建议
1. **Bug 1** 应最优先修复——字体选择器中"System Default"选项完全无效，是用户可直接感知的功能缺陷，且与项目中颜色选择器的同类 Bug（menus_bugs.md Bug 5）属于同一模式
2. **Bug 2** 应尽快修复——Restart 按钮存在但无功能，属于误导性 UI
3. **Bug 3 & Bug 4** 建议在下一个迭代中修复——前者影响性能和用户体验，后者导致主题不一致
4. **Bug 5 & Bug 6** 可作为技术债务在后续版本中处理
