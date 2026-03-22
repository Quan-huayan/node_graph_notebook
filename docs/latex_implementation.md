# LaTeX 公式渲染功能实现文档

## 概述

本文档记录了使用 flutter_markdown_plus_latex 实现 LaTeX 数学公式渲染功能。

## 技术方案

### 选择的包

- **flutter_markdown_plus** (v1.0.7)：flutter_markdown 的官方替代品
- **flutter_markdown_plus_latex** (v1.0.5)：官方 LaTeX 渲染扩展

### 优势

- 纯 Flutter 实现，使用 flutter_math_fork，无 WebView 开销
- 无需平台配置（无需修改 AndroidManifest.xml、Info.plist 等）
- 官方维护（Foresight Mobile 接管 flutter_markdown 的维护）
- 持续更新和 bug 修复

### 背景

**为什么迁移：**

1. **flutter_markdown 已废弃**：Google 在 2025 年停止维护 flutter_markdown，该项目已被标记为 discontinued
2. **flutter_tex 性能问题**：使用 WebView 渲染 LaTeX，每个公式创建独立的 WebView 实例，导致：
   - 渲染速度慢
   - 内存占用高
   - 需要 iOS/Android 平台特定配置
3. **复杂的自定义实现**：需要手动解析 markdown、提取公式、占位符替换等复杂逻辑

## 使用方法

### 基本用法

```dart
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
import 'package:markdown/markdown.dart' as md;

MarkdownBody(
  data: 'latex: $c = \\pm\\sqrt{a^2 + b^2}$',
  selectable: true,
  builders: {
    'latex': LatexElementBuilder(),
  },
  extensionSet: md.ExtensionSet(
    [LatexBlockSyntax()],
    [LatexInlineSyntax()],
  ),
)
```

### 自定义样式

```dart
LatexElementBuilder(
  textStyle: TextStyle(color: Colors.blue),
  textScaleFactor: 1.2,
)
```

### 在编辑器中集成

在 MarkdownEditorPage 和 MarkdownPreviewWidget 中：

```dart
// 条件渲染：如果启用 LaTeX
if (enableLatex) {
  MarkdownBody(
    data: markdown,
    selectable: true,
    builders: {
      'latex': LatexElementBuilder(),
    },
    extensionSet: md.ExtensionSet(
      [LatexBlockSyntax()],
      [LatexInlineSyntax()],
    ),
  );
} else {
  // 普通 Markdown 渲染
  MarkdownBody(
    data: markdown,
    selectable: true,
  );
}
```

## 支持的语法

flutter_markdown_plus_latex 使用 KaTeX 引擎，支持以下语法：

### 行内公式

```markdown
这是行内公式 $E = mc^2$ 的示例。
```

### 块级公式

```markdown
$$
\sum_{i=1}^{n} x_i = \frac{n(n+1)}{2}
$$
```

### displayMode 行内公式

```markdown
$$...$$（在文本中）
```

### LaTeX 方括号语法

```markdown
\[
\int_{a}^{b} f(x) dx = F(b) - F(a)
\]
```

## 编辑器集成

### 工具栏按钮

在 `MarkdownEditorPage` 中提供了两个公式按钮：

1. **行内公式按钮**（Icons.functions）
   - 快捷插入 `$...$`
   - 用于插入行内数学公式

2. **块级公式按钮**（Icons.calculate）
   - 插入带示例的块级公式模板
   - 示例：`\sum_{i=1}^{n} x_i`

### 预览模式

- 自动使用 `MarkdownBody` + LaTeX 扩展渲染
- 实时预览公式效果
- 支持公式和普通 Markdown 混合

## 支持的 LaTeX 语法

基于 KaTeX 引擎，支持大部分数学符号和命令。

### 基础符号

- 上标：`x^2`
- 下标：`x_i`
- 分数：`\frac{a}{b}`
- 根号：`\sqrt{x}`

### 希腊字母

- `\alpha`, `\beta`, `\gamma`, `\delta`, `\epsilon`, etc.
- `\Gamma`, `\Delta`, `\Sigma`, `\Omega`, etc.

### 运算符

- 求和：`\sum_{i=1}^{n}`
- 积分：`\int_{a}^{b}`
- 极限：`\lim_{x \to \infty}`

### 矩阵

```latex
$$
\begin{pmatrix}
a & b \\
c & d
\end{pmatrix}
$$
```

### 方程组

```latex
$$
\begin{cases}
x + y = 1 \\
x - y = 0
\end{cases}
$$
```

更多语法参考：[KaTeX 文档](https://katex.org/docs/supported.html)

## 依赖配置

### pubspec.yaml

```yaml
dependencies:
  flutter_markdown_plus: ^1.0.7
  flutter_markdown_plus_latex: ^1.0.5
  markdown: ^7.1.1
  charcode: ^1.3.1
```

### 平台配置

**无需平台配置！**

与 flutter_tex 不同，flutter_markdown_plus_latex 是纯 Flutter 实现，无需修改：
- AndroidManifest.xml
- Info.plist
- web/index.html

## 性能优势

### 与旧实现对比

| 特性 | flutter_tex | flutter_markdown_plus_latex |
|------|-------------|----------------------------|
| 渲染引擎 | WebView | flutter_math_fork (纯 Flutter) |
| 性能 | 慢（每个公式创建 WebView） | 快（原生渲染） |
| 内存占用 | 高 | 低 |
| 平台配置 | 需要 | 不需要 |
| 维护状态 | 社区维护 | 官方维护 |

### 性能改进

1. **更快的渲染速度**：纯 Flutter 实现，无 WebView 开销
2. **更低的内存占用**：不需要为每个公式创建 WebView 实例
3. **更流畅的滚动**：优化的渲染管道

## 示例

### 微积分基本定理

```markdown
# 微积分基本定理

$$
\int_{a}^{b} f(x) dx = F(b) - F(a)
$$

其中 $F'(x) = f(x)$。
```

### 矩阵运算

```markdown
矩阵乘法：

$$
\begin{pmatrix}
a & b \\
c & d
\end{pmatrix}
\begin{pmatrix}
x \\
y
\end{pmatrix}
=
\begin{pmatrix}
ax + by \\
cx + dy
\end{pmatrix}
$$
```

### 复杂公式

```markdown
欧拉公式：

$$
e^{i\pi} + 1 = 0
$$

泰勒级数：

$$
f(x) = \sum_{n=0}^{\infty} \frac{f^{(n)}(a)}{n!} (x-a)^n
$$
```

## 参考资料

### 官方文档

- [flutter_markdown_plus_latex GitHub](https://github.com/foresightmobile/flutter_markdown_plus_latex)
- [flutter_markdown_plus_latex Pub.dev](https://pub.dev/packages/flutter_markdown_plus_latex)
- [flutter_markdown_plus GitHub](https://github.com/foresightmobile/flutter_markdown_plus)
- [flutter_markdown_plus Pub.dev](https://pub.dev/packages/flutter_markdown_plus)
- [Foresight Mobile 博客：flutter_markdown_plus 交接说明](https://foresightmobile.com/blog/flutter-markdown-plus-google-handover)

### LaTeX 语法参考

- [KaTeX 支持的语法](https://katex.org/docs/supported.html)
- [LaTeX 数学公式教程](https://www.overleaf.com/learn/latex/Mathematical_expressions)

## 贡献者

- 实施日期：2026-03-22
- 技术方案：flutter_markdown_plus + flutter_markdown_plus_latex
- 迁移原因：flutter_markdown 废弃、flutter_tex 性能问题

---

**文档版本：** 2.0.0
**最后更新：** 2026-03-22
