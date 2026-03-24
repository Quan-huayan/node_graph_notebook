# I18n 使用指南

## 📖 概述

I18n（国际化）系统已重构完成，现在使用外部CSV文件管理翻译数据，而不是硬编码在代码中。

### 🎯 重构优势

- ✅ **分离关注点**：翻译数据与代码分离
- ✅ **易于维护**：翻译人员可以直接编辑CSV文件
- ✅ **版本控制友好**：Git diff更清晰
- ✅ **保持性能**：编译时打包，运行时无需加载
- ✅ **动态扩展**：插件仍可动态添加翻译

---

## 🚀 快速开始

### 开发工作流

```bash
# 1. 编辑翻译源文件
# 编辑 assets/i18n/source.csv

# 2. 生成翻译代码
dart tool/generate_i18n.dart

# 或使用脚本
bash scripts/generate_i18n.sh    # Unix/macOS
.\scripts\generate_i18n.bat      # Windows

# 3. 运行应用测试
flutter run
```

---

## 📁 文件结构

```
assets/i18n/
  └── source.csv                 # 翻译源文件（编辑这个）

lib/core/services/
  ├── i18n.dart                  # I18n核心类（不要编辑）
  └── i18n/
      └── translations.dart      # 生成的翻译代码（不要手动编辑）

tool/
  └── generate_i18n.dart         # 代码生成工具

scripts/
  ├── generate_i18n.sh           # 生成脚本（Unix）
  └── generate_i18n.bat          # 生成脚本（Windows）
```

---

## ✏️ 编辑翻译

### CSV 格式

```csv
Key,Zh,En,Category,Notes
Home,主页,Home,通用,
Settings,设置,Settings,通用,
AI Tools,AI 工具,AI Tools,AI模块,
```

### 字段说明

| 字段 | 说明 | 示例 |
|------|------|------|
| Key | 翻译键（英文原文） | `Home` |
| Zh | 中文翻译 | `主页` |
| En | 英文翻译 | `Home` |
| Category | 分类 | `通用`, `AI`, `设置页面` |
| Notes | 备注说明 | 可选 |

### 最佳实践

1. **使用有意义的键名**
   ```csv
   ✅ Good: AI Configuration, API Key, Create Node
   ❌ Bad: ai_config, key1, btn1
   ```

2. **按功能模块组织**
   ```csv
   AI Tools,AI 工具,AI Tools,AI
   AI Assistant,AI 助手,AI Assistant,AI
   Settings,设置,Settings,通用
   Storage Settings,存储设置,Storage Settings,设置页面
   ```

3. **处理特殊字符**
   - CSV中用双引号包裹包含逗号的字段
   ```csv
   "Ctrl+N: Create new node","Ctrl+N：创建新节点","Ctrl+N: Create new node",快捷键,
   ```

---

## 🔧 代码生成工具

### 基本用法

```bash
# 使用默认路径
dart tool/generate_i18n.dart

# 指定输入输出路径
dart tool/generate_i18n.dart --input=custom.csv --output=output.dart

# 显示详细信息
dart tool/generate_i18n.dart --verbose

# 查看帮助
dart tool/generate_i18n.dart --help
```

### 工具特性

- ✅ 自动处理CSV中的特殊字符
- ✅ 按分类组织翻译
- ✅ 生成清晰的代码注释
- ✅ 错误检测和报告
- ✅ 统计信息显示

---

## 💻 在代码中使用

### 基本用法

```dart
// 获取I18n实例
final i18n = I18n.of(context);

// 翻译文本
Text(i18n.t('Settings'))
// 中文: "设置"
// 英文: "Settings"

// 监听语言变化（自动更新UI）
Consumer<I18n>(
  builder: (ctx, i18n, child) {
    return Text(i18n.t('Settings'));
  },
)
```

### 切换语言

```dart
// 切换到中文
await i18n.switchLanguage('zh');

// 切换到英文
await i18n.switchLanguage('en');

// 语言设置会自动保存，重启应用后恢复
```

### 检查语言支持

```dart
if (i18n.supportsLanguage('zh')) {
  // 支持中文
}

final languages = i18n.supportedLanguages;
// ['en', 'zh']
```

---

## 🔌 动态扩展（插件）

### 添加单个翻译

```dart
final i18n = getService<I18n>();
i18n.addTranslation('ja', 'Settings', '設定');
```

### 批量添加翻译

```dart
i18n.addTranslations('ja', {
  'Settings': '設定',
  'Home': 'ホーム',
  'AI Tools': 'AIツール',
});
```

### 创建语言包插件

```dart
class JapanesePlugin extends Plugin {
  @override
  Future<void> onEnable() async {
    final i18n = getService<I18n>();

    i18n.addTranslations('ja', {
      'Settings': '設定',
      'Home': 'ホーム',
      // ... 更多翻译
    });
  }
}
```

### 优先级

动态翻译的优先级高于静态翻译，允许插件覆盖默认翻译：

```dart
// 静态翻译: 'Home' -> '主页'
i18n.addTranslation('zh', 'Home', '主页（自定义）');
// 动态翻译会覆盖: 'Home' -> '主页（自定义）'
```

---

## 🏗️ 构建集成

I18n代码生成已集成到构建流程中：

```bash
# 完整构建（自动生成i18n代码）
bash scripts/build.sh      # Unix/macOS
.\scripts\build.bat        # Windows
```

构建脚本会自动：
1. 安装依赖
2. **生成i18n翻译代码**
3. 生成JSON序列化代码
4. 分析代码
5. 运行测试
6. 构建应用

---

## 📊 统计信息

查看翻译统计：

```dart
final stats = i18n.getTranslationStats();
print(stats);
// {en: 308, zh: 308}
```

---

## ⚠️ 注意事项

### 不要手动编辑生成的文件

```dart
// ❌ 不要编辑这个文件
lib/core/services/i18n/translations.dart

// ✅ 应该编辑这个文件
assets/i18n/source.csv
```

### 重新生成翻译代码

每次修改CSV后，必须重新生成代码：

```bash
dart tool/generate_i18n.dart
```

### 特殊字符处理

CSV中的特殊字符需要用双引号包裹：

```csv
"Text with, comma",带逗号的文本,Text with, comma,
"Text with ""quotes""",带引号的文本,Text with "quotes",
```

---

## 🐛 常见问题

### Q: 修改CSV后翻译没有更新？

A: 确保重新运行了代码生成工具：
```bash
dart tool/generate_i18n.dart
```

### Q: 如何添加新语言？

1. 在CSV中添加新列（如`Ja`）
2. 更新表头：`Key,Zh,En,Ja,Category,Notes`
3. 填充翻译数据
4. 重新生成代码

### Q: 动态翻译不生效？

A: 确保在添加翻译后调用了`notifyListeners()`：
```dart
i18n.addTranslation('zh', 'Key', '翻译');
i18n.notifyListeners(); // 如果需要立即更新UI
```

### Q: 如何调试翻译问题？

使用详细模式运行生成工具：
```bash
dart tool/generate_i18n.dart --verbose
```

---

## 📚 相关文档

- [I18n实现原理详解](./i18n_implementation_guide.md)
- [I18n插件分析](./i18n_plugin_analysis.md)
- [I18n存储机制](./i18n_storage_explanation.md)
- [插件开发指南](./plugin_development.md)

---

## 🎉 重构完成

I18n重构已完成！现在享受更简洁、更易维护的翻译管理体验吧！

**生成时间**: 2026-03-24
**翻译条目**: 308条 × 2语言
**分类**: 25个功能模块
