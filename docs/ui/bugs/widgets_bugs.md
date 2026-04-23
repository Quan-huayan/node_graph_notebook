# UI Widgets 模块 Bug 报告

**审查日期**: 2026-04-21
**审查范围**: `lib/ui/widgets` 文件夹

---

## Bug 1: 翻译键不匹配，中文模式下 Version 和 Author 始终显示英文

### 位置
- [plugin_item.dart:63](file:///d:/Projects/node_graph_notebook/lib/ui/widgets/plugin_item.dart#L63)
- [plugin_item.dart:69](file:///d:/Projects/node_graph_notebook/lib/ui/widgets/plugin_item.dart#L69)

### 严重程度
**严重**

### 问题描述
代码中使用 `i18n.t('Version:')` 和 `i18n.t('Author:')` 作为翻译键（带冒号），但翻译数据 [translations.dart](file:///d:/Projects/node_graph_notebook/lib/core/services/i18n/translations.dart) 中只存在 `'Version'` 和 `'Author'`（不带冒号）。`I18n.t()` 方法执行精确键匹配，找不到 `'Version:'` 和 `'Author:'` 时会直接返回键本身作为降级结果，导致中文模式下这些标签始终显示英文原文。

### 问题代码
```dart
Text(
  '${i18n.t('Version:')} $version',  // 键为 'Version:'，翻译数据中不存在
  style: const TextStyle(fontSize: 12, color: Colors.grey),
),
Text(
  '${i18n.t('Author:')} $author',    // 键为 'Author:'，翻译数据中不存在
  style: const TextStyle(fontSize: 12, color: Colors.grey),
),
```

### 翻译数据对比
| 代码中使用的键 | 翻译数据中的键 | 中文翻译 | 实际显示 |
|---------------|---------------|---------|---------|
| `'Version:'` | `'Version'` | `版本` | `Version:` (降级返回键本身) |
| `'Author:'` | `'Author'` | `作者` | `Author:` (降级返回键本身) |

### 触发场景
1. 将应用语言切换为中文
2. 打开插件市场页面
3. 观察插件卡片中的版本和作者标签，显示为 "Version: 1.0.0" 和 "Author: xxx" 而非 "版本: 1.0.0" 和 "作者: xxx"

### 影响
- 中文用户看到英文标签，国际化功能失效
- 同一页面中其他翻译（如 "安装" 按钮）正常显示，造成视觉不一致
- 同样的 Bug 也存在于 [plugin_market_page.dart:118-125](file:///d:/Projects/node_graph_notebook/lib/ui/pages/plugin_market_page.dart#L118-L125)

### 修复建议
将冒号从翻译键中移出，使用不带冒号的键进行翻译，然后手动拼接冒号：

```dart
Text(
  '${i18n.t('Version')}: $version',
  style: const TextStyle(fontSize: 12, color: Colors.grey),
),
Text(
  '${i18n.t('Author')}: $author',
  style: const TextStyle(fontSize: 12, color: Colors.grey),
),
```

或者在翻译数据中添加带冒号的键（但会增加维护成本，不推荐）。

---

## Bug 2: I18n.of(context) 使用 listen: false，语言切换后组件不会重建

### 位置
- [plugin_item.dart:37](file:///d:/Projects/node_graph_notebook/lib/ui/widgets/plugin_item.dart#L37)

### 严重程度
**高**

### 问题描述
`PluginItem` 在 `build()` 方法中使用 `I18n.of(context)` 获取国际化实例。`I18n.of(context)` 内部调用 `Provider.of<I18n>(context, listen: false)`，这意味着该组件**不会订阅 I18n 的变化通知**。当用户切换语言时，`I18n` 会调用 `notifyListeners()`，但 `PluginItem` 不会收到通知，因此不会重建，界面上的翻译文本将保持旧语言不变。

### 问题代码
```dart
@override
Widget build(BuildContext context) {
  final i18n = I18n.of(context);  // listen: false，不订阅变化
  // ...
}
```

### 对比正确实现
项目中需要响应语言切换的常驻 UI 组件使用了 `Consumer<I18n>` 模式。例如 [language_toggle_hook.dart](file:///d:/Projects/node_graph_notebook/lib/plugins/i18n/hooks/language_toggle_hook.dart) 中的工具栏语言切换按钮：

```dart
return Consumer<I18n>(
  builder: (ctx, i18n, child) => IconButton(
    icon: const Icon(Icons.translate),
    tooltip: i18n.t('Language'),  // 响应式更新
    onPressed: () => _showLanguageDialog(buildContext),
  ),
);
```

### 触发场景
1. 打开插件市场页面
2. 通过工具栏切换语言（如从英文切换到中文）
3. 插件卡片中的所有翻译文本不会更新，仍显示英文

### 影响
- `PluginItem` 作为 `PluginMarketPage` 中的列表项，是常驻 UI 组件，语言切换后必须更新
- 与项目中其他使用 `Consumer<I18n>` 的组件行为不一致
- 用户体验受损：切换语言后部分界面更新，部分不更新

### 修复建议
使用 `Consumer<I18n>` 包裹组件内容，确保语言切换时自动重建：

```dart
@override
Widget build(BuildContext context) {
  return Consumer<I18n>(
    builder: (context, i18n, child) {
      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ... 原有子组件
            ],
          ),
        ),
      );
    },
  );
}
```

---

## Bug 3: Text 组件缺少 maxLines 和 overflow，长文本可能导致布局溢出

### 位置
- [plugin_item.dart:55-60](file:///d:/Projects/node_graph_notebook/lib/ui/widgets/plugin_item.dart#L55-L60) — 插件名称
- [plugin_item.dart:86](file:///d:/Projects/node_graph_notebook/lib/ui/widgets/plugin_item.dart#L86) — 插件描述

### 严重程度
**中等**

### 问题描述
`name` 和 `description` 的 `Text` 组件均未设置 `maxLines` 和 `overflow` 属性。当文本过长时：
- `name` 位于 `Row` 中的 `Expanded` 内，虽然 `Expanded` 会限制水平空间，但文本会无限换行，挤压下方版本和作者信息
- `description` 位于 `Column` 底部，长文本会使 Card 无限增高

### 问题代码
```dart
Text(
  name,
  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
),
// ...
Text(description, style: const TextStyle(fontSize: 14)),
```

### 触发场景
1. 插件名称非常长（如 "Super Advanced Markdown Enhancement Suite Pro Edition"）
2. 插件描述包含多段文字
3. 在窄屏设备上显示

### 影响
- 名称过长时挤压版本/作者信息，布局变形
- 描述过长时 Card 高度过大，影响列表滚动体验
- 窄屏设备上可能出现布局溢出

### 修复建议
为 `name` 添加单行限制，为 `description` 添加行数限制：

```dart
Text(
  name,
  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
// ...
Text(
  description,
  style: const TextStyle(fontSize: 14),
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
),
```

---

## Bug 4: Theme.of(context).primaryColor 已弃用

### 位置
- [plugin_item.dart:49](file:///d:/Projects/node_graph_notebook/lib/ui/widgets/plugin_item.dart#L49)

### 严重程度
**中等**

### 问题描述
代码使用 `Theme.of(context).primaryColor` 获取主题色。在 Flutter 3.16+ 中，`ThemeData.primaryColor` 已被标记为弃用（deprecated），官方推荐使用 `ColorScheme` 中的颜色。本项目 SDK 约束为 `>=3.8.0 <4.0.0`，对应 Flutter 3.x 版本，此 API 已弃用。

### 问题代码
```dart
Icon(icon, size: 48, color: Theme.of(context).primaryColor),
```

### 影响
- 编译时产生弃用警告
- `primaryColor` 在使用 `ColorScheme` 的主题中可能返回不正确的颜色
- 未来 Flutter 版本可能移除此 API，导致编译失败

### 修复建议
使用 `ColorScheme.primary` 替代：

```dart
Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
```

---

## Bug 5: Colors.grey 硬编码，不适配深色模式

### 位置
- [plugin_item.dart:65](file:///d:/Projects/node_graph_notebook/lib/ui/widgets/plugin_item.dart#L65)
- [plugin_item.dart:72](file:///d:/Projects/node_graph_notebook/lib/ui/widgets/plugin_item.dart#L72)

### 严重程度
**低**

### 问题描述
版本和作者文本的颜色使用硬编码的 `Colors.grey`，未通过主题系统获取。在深色模式下，`Colors.grey`（默认 `Colors.grey.shade400`，约 `#9E9E9E`）与深色背景的对比度可能不足，影响可读性。同时，硬编码颜色无法随主题切换而自适应。

### 问题代码
```dart
Text(
  '${i18n.t('Version:')} $version',
  style: const TextStyle(fontSize: 12, color: Colors.grey),
),
Text(
  '${i18n.t('Author:')} $author',
  style: const TextStyle(fontSize: 12, color: Colors.grey),
),
```

### 影响
- 深色模式下灰色文本可读性差
- 与主题系统脱耦，无法通过自定义主题调整颜色

### 修复建议
使用主题的 `ColorScheme` 颜色：

```dart
Text(
  '${i18n.t('Version')}: $version',
  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
),
Text(
  '${i18n.t('Author')}: $author',
  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
),
```

---

## Bug 6: 外层 Column 缺少 mainAxisSize: MainAxisSize.min

### 位置
- [plugin_item.dart:44](file:///d:/Projects/node_graph_notebook/lib/ui/widgets/plugin_item.dart#L44)

### 严重程度
**低**

### 问题描述
外层 `Column` 未设置 `mainAxisSize: MainAxisSize.min`，默认行为为 `MainAxisSize.max`，即 Column 会尝试占据父组件提供的全部垂直空间。在 `Card` + `Padding` 的布局中，如果父组件提供了无限的垂直空间（如 `ListView`），Column 会正确收缩；但如果父组件提供了有限垂直空间，Card 会被拉伸到不必要的最大高度。

### 问题代码
```dart
child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // ...
  ],
),
```

### 影响
- 在特定父布局中，Card 可能比实际内容需要的高度更大
- 不影响当前 `PluginMarketPage` 中的使用（因为 `ListView` 提供无限垂直空间），但降低了组件的复用性

### 修复建议
添加 `mainAxisSize: MainAxisSize.min`：

```dart
child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisSize: MainAxisSize.min,
  children: [
    // ...
  ],
),
```

---

## 总结

| Bug ID | 严重程度 | 文件 | 问题类型 |
|--------|----------|------|----------|
| Bug 1 | 严重 | plugin_item.dart | 翻译键不匹配，中文显示英文 |
| Bug 2 | 高 | plugin_item.dart | I18n 非响应式，语言切换不更新 |
| Bug 3 | 中等 | plugin_item.dart | 长文本缺少 maxLines/overflow |
| Bug 4 | 中等 | plugin_item.dart | primaryColor 已弃用 |
| Bug 5 | 低 | plugin_item.dart | Colors.grey 不适配深色模式 |
| Bug 6 | 低 | plugin_item.dart | Column 缺少 mainAxisSize.min |

### 优先级建议
1. **Bug 1** 应最优先修复，翻译键不匹配导致国际化功能直接失效，用户可见的明显问题
2. **Bug 2** 应尽快修复，语言切换后组件不更新是功能性缺陷，影响用户体验
3. **Bug 3 & 4** 建议在下一个迭代中修复，前者影响布局稳定性，后者是弃用 API
4. **Bug 5 & 6** 可作为技术债务在后续版本中处理
