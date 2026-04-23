# UtilWidgets 模块 Bug 报告

**审查日期**: 2026-04-21
**审查范围**: `lib/ui/utilwidgets` 文件夹

---

## Bug 1: HighlightText 中 RegExp 注入导致应用崩溃

### 位置
- [highlight_text.dart:23](file:///d:/Projects/node_graph_notebook/lib/ui/utilwidgets/highlight_text.dart#L23)

### 严重程度
**高**

### 问题描述
`HighlightText` 组件将用户输入的 `query` 字符串直接作为 `RegExp` 的正则表达式模式使用，未对特殊字符进行转义。当用户在搜索框中输入包含正则表达式特殊字符的文本时，会导致 `FormatException` 异常，从而使应用崩溃。

### 问题代码
```dart
final matches = RegExp(query!, caseSensitive: false).allMatches(text);
```

### 触发场景
以下输入均会导致崩溃或异常行为：

| 输入内容 | 结果 |
|----------|------|
| `[` | `FormatException: Unterminated character class` |
| `(` | `FormatException: Unterminated group` |
| `*` | `FormatException: Nothing to repeat` |
| `+` | `FormatException: Nothing to repeat` |
| `?` | `FormatException: Nothing to repeat` |
| `{3}` | `FormatException: Nothing to repeat` |
| `\` | `FormatException: Unterminated escape sequence` |
| `.*` | 不会崩溃，但会匹配所有字符（非预期行为） |
| `a\|b` | 不会崩溃，但会匹配 "a" 或 "b"（非预期行为） |

### 影响范围
该组件被搜索功能使用，`query` 直接来源于用户搜索输入：
- [searched_node_item.dart:49](file:///d:/Projects/node_graph_notebook/lib/plugins/search/ui/searched_node_item.dart#L49) — 节点标题高亮
- [searched_node_item.dart:51](file:///d:/Projects/node_graph_notebook/lib/plugins/search/ui/searched_node_item.dart#L51) — 节点内容高亮

用户在搜索框中输入任何正则特殊字符都会导致搜索页面崩溃。

### 修复建议
在构建 `RegExp` 之前对 `query` 中的特殊字符进行转义：

```dart
String _escapeRegExp(String input) {
  return input.replaceAllMapped(
    RegExp(r'[.*+?^${}()|[\]\\]'),
    (match) => '\\${match[0]}',
  );
}

// 在 build 方法中使用：
final matches = RegExp(_escapeRegExp(query!), caseSensitive: false).allMatches(text);
```

---

## Bug 2: RichText 溢出时省略号继承高亮样式

### 位置
- [highlight_text.dart:54-61](file:///d:/Projects/node_graph_notebook/lib/ui/utilwidgets/highlight_text.dart#L54-L61)

### 严重程度
**低**

### 问题描述
当 `maxLines` 限制生效且文本溢出时，`RichText` 的 `TextOverflow.ellipsis` 会在最后一个可见 `TextSpan` 之后添加省略号（`...`）。如果最后一个可见的 `TextSpan` 恰好是高亮样式（黄色背景 + 粗体），则省略号也会继承该高亮样式，导致省略号显示为黄色背景和粗体，与普通文本的省略号外观不一致。

### 问题代码
```dart
spans.add(
  TextSpan(
    text: text.substring(match.start, match.end),
    style: TextStyle(
      backgroundColor: Colors.yellow.shade200,
      fontWeight: FontWeight.bold,
    ),
  ),
);

// ...

return RichText(
  text: TextSpan(
    style: DefaultTextStyle.of(context).style,
    children: spans,
  ),
  maxLines: maxLines,
  overflow: TextOverflow.ellipsis,
);
```

### 触发场景
1. 设置 `maxLines` 为较小值（如 1 或 2）
2. 文本内容足够长以触发溢出
3. 搜索关键词恰好出现在截断位置附近，使得最后一个可见的 `TextSpan` 是高亮样式

### 影响
- 省略号显示为黄色背景 + 粗体，视觉上不一致
- 仅在特定文本长度和关键词位置组合下出现，属于偶发性 UI 问题

### 修复建议
在最后一个 `TextSpan` 之后追加一个空的普通样式 `TextSpan`，确保省略号使用默认样式：

```dart
if (lastIndex < text.length) {
  spans.add(TextSpan(text: text.substring(lastIndex)));
}

// 确保省略号使用默认样式
if (maxLines != null) {
  spans.add(const TextSpan(text: ''));
}
```

或者使用 `RichText` 的 `strutStyle` 参数来统一省略号的样式。

---

## 总结

| Bug ID | 严重程度 | 文件 | 问题类型 |
|--------|----------|------|----------|
| Bug 1 | 高 | highlight_text.dart | RegExp 注入导致崩溃 |
| Bug 2 | 低 | highlight_text.dart | 省略号样式继承错误 |

### 优先级建议
1. **Bug 1** 应立即修复，用户输入正则特殊字符即可触发崩溃，属于安全性 + 稳定性问题
2. **Bug 2** 可在后续迭代中修复，仅影响特定场景下的视觉表现
