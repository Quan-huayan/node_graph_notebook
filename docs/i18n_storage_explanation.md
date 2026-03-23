# I18n 翻译数据存储详解

## 当前存储方式

### 位置
**文件路径**: `lib/core/services/i18n.dart`
**文件大小**: 503 行代码
**翻译条目**: 约 400+ 条

### 存储结构

```dart
class I18n extends ChangeNotifier {
  /// 翻译数据（硬编码在类中）
  final Map<String, Map<String, String>> _translations = {
    'en': {}, // 英文（默认，空映射）
    'zh': {
      // === 通用 ===
      'Node Graph Notebook': 'Node Graph Notebook',
      'Home': '主页',
      'Settings': '设置',
      'About': '关于',
      // ... 400+ 翻译条目
    },
  };
}
```

### 数据格式

```dart
// 外层 Map: 语言代码 → 翻译表
{
  'en': Map<String, String>,  // 英文 → 英文映射（空）
  'zh': Map<String, String>,  // 英文 → 中文映射
}

// 内层 Map: 原文 → 译文
{
  'Home': '主页',
  'Settings': '设置',
  'AI Tools': 'AI 工具',
  // ...
}
```

---

## 为什么选择这种方式？

### 优点

1. **简单直接**
   - 无需额外文件
   - 无需配置加载逻辑
   - 代码即文档

2. **编译时确定**
   - 翻译在编译时打包到应用中
   - 运行时无需加载
   - 启动速度快

3. **类型安全**
   - Dart Map 类型检查
   - 编译时发现错误
   - IDE 自动补全

4. **性能优秀**
   - 内存中的 Map，访问速度极快
   - 无需 I/O 操作
   - 无需解析

5. **易于扩展**
   - 支持动态添加翻译
   - 插件可以注册新的翻译
   - 运行时更新

### 缺点

1. **硬编码**
   - 修改翻译需要重新编译
   - 无法独立管理翻译
   - 代码文件体积大

2. **不利于协作**
   - 翻译人员需要修改代码
   - 无法使用专业翻译工具
   - 难以追踪翻译进度

3. **版本控制**
   - 代码变更和翻译变更混在一起
   - Git diff 不易查看翻译变化
   - 难以回滚特定翻译

4. **不支持热更新**
   - 无法动态下载新翻译
   - 无法在线更新翻译
   - 必须发版更新

---

## 数据结构详解

### 翻译分类

```dart
'zh': {
  // === 通用 (50+ 条) ===
  'Home': '主页',
  'Settings': '设置',
  'About': '关于',
  'Delete': '删除',

  // === 设置页面 (30+ 条) ===
  'Storage Settings': '存储设置',
  'Theme Settings': '主题设置',
  'View Settings': '视图设置',

  // === AI 相关 (40+ 条) ===
  'AI Tools': 'AI 工具',
  'AI Assistant': 'AI 助手',
  'AI Configuration': 'AI 配置',

  // === 编辑器 (30+ 条) ===
  'Markdown Editor': 'Markdown 编辑器',
  'Bold': '粗体',
  'Italic': '斜体',

  // === 节点操作 (100+ 条) ===
  'Create Node': '创建节点',
  'Delete Node': '删除节点',
  'Edit Metadata': '编辑元数据',

  // === 布局 (10+ 条) ===
  'Force Directed': '力导向布局',
  'Hierarchical': '层次布局',

  // === 其他 (150+ 条) ===
  // ...
}
```

### 内存占用

```dart
// 估算
// 英文: 0 条（空 Map）
// 中文: 400 条 × 平均 20 字符 = 8,000 字符
// 总计: 约 16 KB 内存（包含 Map 开销）
```

---

## 其他存储方案对比

### 方案 1: JSON 文件（Flutter Intl 方式）

**文件结构**:
```
assets/i18n/
  ├── en.json
  └── zh.json
```

**en.json**:
```json
{
  "Home": "Home",
  "Settings": "Settings",
  "AI Tools": "AI Tools"
}
```

**zh.json**:
```json
{
  "Home": "主页",
  "Settings": "设置",
  "AI Tools": "AI 工具"
}
```

**加载方式**:
```dart
final translations = await rootBundle.loadString('assets/i18n/zh.json');
final data = jsonDecode(translations);
```

**优点**:
- ✅ 翻译独立于代码
- ✅ 翻译人员可直接编辑
- ✅ 支持热更新
- ✅ 易于版本控制

**缺点**:
- ❌ 需要异步加载
- ❌ 需要解析 JSON
- ❌ 启动时间稍长
- ❌ 配置复杂

### 方案 2: ARB 文件（官方推荐）

**文件结构**:
```
assets/l10n/
  ├── app_en.arb
  └── app_zh.arb
```

**app_en.arb**:
```json
{
  "@@locale": "en",
  "home": "Home",
  "settings": "Settings",
  "aiTools": "AI Tools"
}
```

**app_zh.arb**:
```json
{
  "@@locale": "zh",
  "home": "主页",
  "settings": "设置",
  "aiTools": "AI 工具"
}
```

**优点**:
- ✅ Flutter 官方推荐
- ✅ 支持复数、日期等
- ✅ 代码生成工具
- ✅ 类型安全

**缺点**:
- ❌ 配置复杂
- ❌ 需要代码生成
- ❌ 学习曲线陡峭

### 方案 3: 数据库存储

**表结构**:
```sql
CREATE TABLE translations (
  id INTEGER PRIMARY KEY,
  language TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  UNIQUE(language, key)
);
```

**优点**:
- ✅ 支持热更新
- ✅ 可以在线管理
- ✅ 支持翻译版本控制

**缺点**:
- ❌ 需要 SQLite
- ❌ 异步查询
- ❌ 性能较差

### 方案 4: 云端存储

**流程**:
```
应用启动
    ↓
检查更新
    ↓
下载最新翻译
    ↓
缓存到本地
    ↓
使用翻译
```

**优点**:
- ✅ 实时更新
- ✅ 无需发版
- ✅ 集中管理

**缺点**:
- ❌ 需要网络
- ❌ 依赖服务端
- ❌ 离线不可用

---

## 当前方案适用场景

### ✅ 适合当前方案的场景

1. **小型项目**
   - 翻译条目 < 500
   - 语言数量 < 5
   - 更新频率低

2. **快速原型**
   - 无需复杂配置
   - 快速实现功能
   - 便于测试

3. **独立应用**
   - 无需在线更新
   - 无需专业翻译团队
   - 开发者自己维护

4. **插件化架构**
   - 支持动态扩展
   - 插件可添加翻译
   - 灵活性高

### ❌ 不适合当前方案的场景

1. **大型项目**
   - 翻译条目 > 1000
   - 语言数量 > 10
   - 需要专业翻译工具

2. **频繁更新**
   - 翻译经常变化
   - 需要热更新
   - 多团队协作

3. **国际化要求高**
   - 需要复数、日期等
   - 需要 RTL 支持
   - 需要地区差异

---

## 改进建议

### 短期优化（保持当前方案）

#### 1. 提取翻译到单独文件

```dart
// lib/core/services/i18n/translations.dart
class Translations {
  static const Map<String, Map<String, String>> data = {
    'en': {},
    'zh': {
      'Home': '主页',
      'Settings': '设置',
      // ...
    },
  };
}

// lib/core/services/i18n.dart
class I18n extends ChangeNotifier {
  final Map<String, Map<String, String>> _translations = Translations.data;
}
```

**优点**:
- ✅ 代码更清晰
- ✅ 便于维护
- ✅ 不改变现有架构

#### 2. 使用代码生成

```dart
// 工具脚本: tool/generate_translations.dart
void main() {
  final translations = {
    'zh': {
      'Home': '主页',
      'Settings': '设置',
    },
  };

  final output = StringBuffer();
  output.writeln("final Map<String, Map<String, String>> _translations = {");
  translations.forEach((lang, data) {
    output.writeln("  '$lang': {");
    data.forEach((key, value) {
      output.writeln("    '$key': '$value',");
    });
    output.writeln("  },");
  });
  output.writeln("};");

  File('lib/core/services/i18n_data.dart').writeAsStringSync(output.toString());
}
```

**优点**:
- ✅ 可以从 JSON/CSV 生成
- ✅ 易于自动化
- ✅ 保持硬编码优势

### 中期优化（混合方案）

#### 1. 内置 + 动态加载

```dart
class I18n extends ChangeNotifier {
  final Map<String, Map<String, String>> _translations = {
    'en': {},  // 内置基础翻译
    'zh': {
      'Home': '主页',
      'Settings': '设置',
      // 只内置核心翻译（100条）
    },
  };

  /// 从远程加载完整翻译
  Future<void> loadRemoteTranslations(String language) async {
    try {
      final response = await http.get(
        Uri.parse('https://example.com/i18n/$language.json')
      );

      final data = jsonDecode(response.body);
      _translations[language] = Map<String, String>.from(data);
      notifyListeners();
    } catch (e) {
      debugPrint('加载远程翻译失败: $e');
      // 使用内置翻译
    }
  }
}
```

**优点**:
- ✅ 核心功能离线可用
- ✅ 完整翻译在线加载
- ✅ 支持热更新

#### 2. 分模块翻译

```dart
// lib/core/services/i18n/modules/
//   ├── core_translations.dart    // 核心翻译（200条）
//   ├── ai_translations.dart      // AI 模块（50条）
//   ├── editor_translations.dart  // 编辑器模块（30条）
//   └── layout_translations.dart  // 布局模块（20条）

class I18n extends ChangeNotifier {
  final Map<String, Map<String, String>> _translations = {
    'zh': {
      ...CoreTranslations.zh,
      ...AITranslations.zh,
      ...EditorTranslations.zh,
      ...LayoutTranslations.zh,
    },
  };
}
```

**优点**:
- ✅ 模块化管理
- ✅ 减少单文件体积
- ✅ 便于维护

### 长期优化（完全外部化）

#### 1. 完整的 JSON 文件方案

```
assets/i18n/
  ├── core/
  │   ├── core_zh.json
  │   └── core_en.json
  ├── ai/
  │   ├── ai_zh.json
  │   └── ai_en.json
  └── editor/
      ├── editor_zh.json
      └── editor_en.json
```

**实现**:
```dart
class I18n extends ChangeNotifier {
  Future<void> loadTranslations() async {
    // 加载核心翻译
    final coreZh = await _loadJson('assets/i18n/core/core_zh.json');
    final coreEn = await _loadJson('assets/i18n/core/core_en.json');

    // 加载模块翻译
    final aiZh = await _loadJson('assets/i18n/ai/ai_zh.json');

    // 合并翻译
    _translations = {
      'zh': {
        ...coreZh,
        ...aiZh,
      },
      'en': {
        ...coreEn,
      },
    };

    notifyListeners();
  }

  Future<Map<String, String>> _loadJson(String path) async {
    final jsonString = await rootBundle.loadString(path);
    final data = await jsonDecode(jsonString);
    return Map<String, String>.from(data);
  }
}
```

**优点**:
- ✅ 完全独立于代码
- ✅ 翻译人员可直接编辑
- ✅ 支持热更新
- ✅ 易于版本控制

#### 2. 翻译管理系统

```
┌──────────────┐
│  翻译管理平台  │
│  (Web UI)    │
└──────┬───────┘
       │
       ↓ API
┌──────────────┐
│  翻译数据库   │
└──────┬───────┘
       │
       ↓ 下载
┌──────────────┐
│  应用缓存    │
└──────┬───────┘
       │
       ↓ 加载
┌──────────────┐
│   I18n       │
└──────────────┘
```

**功能**:
- ✅ 在线翻译编辑
- ✅ 翻译进度追踪
- ✅ 版本管理
- ✅ 协作翻译
- ✅ 自动更新

---

## 当前项目推荐方案

### 推荐方案：**提取 + 代码生成**

#### 第一步：提取翻译到单独文件

```dart
// lib/core/services/i18n/translations.dart
class I18nTranslations {
  static const Map<String, Map<String, String>> data = {
    'en': {},
    'zh': _zhTranslations,
  };

  static const Map<String, String> _zhTranslations = {
    // === 通用 ===
    'Home': '主页',
    'Settings': '设置',
    'About': '关于',

    // === 设置 ===
    'Storage Settings': '存储设置',
    'Theme Settings': '主题设置',

    // ... 按模块组织
  };
}
```

#### 第二步：创建代码生成工具

```dart
// tool/generate_i18n.dart
import 'dart:convert';
import 'dart:io';

void main() {
  // 从 CSV 生成
  generateFromCsv('assets/i18n/source.csv');

  // 或从 JSON 生成
  generateFromJson('assets/i18n/zh.json');
}

void generateFromCsv(String path) {
  final file = File(path);
  final lines = file.readAsLinesSync();

  final zhTranslations = <String, String>{};

  for (final line in lines.skip(1)) {  // 跳过表头
    final parts = line.split(',');
    if (parts.length >= 3) {
      final key = parts[0].trim();
      final zh = parts[1].trim();
      zhTranslations[key] = zh;
    }
  }

  final output = generateDartCode(zhTranslations);
  File('lib/core/services/i18n/translations.dart')
    .writeAsStringSync(output);
}

String generateDartCode(Map<String, String> translations) {
  final buffer = StringBuffer();
  buffer.writeln('class I18nTranslations {');
  buffer.writeln('  static const Map<String, Map<String, String>> data = {');
  buffer.writeln("    'en': {},");
  buffer.writeln("    'zh': {");

  translations.forEach((key, value) {
    buffer.writeln("      '$key': '$value',");
  });

  buffer.writeln('    },');
  buffer.writeln('  };');
  buffer.writeln('}');

  return buffer.toString();
}
```

#### 第三步：CSV 源文件

```csv
// assets/i18n/source.csv
Key,Zh,Notes
Home,主页,通用
Settings,设置,通用
About,关于,通用
Storage Settings,存储设置,设置页面
Theme Settings,主题设置,设置页面
AI Tools,AI 工具,AI 模块
```

**优点**:
- ✅ 翻译人员编辑 CSV
- ✅ 运行工具生成代码
- ✅ 保持硬编码优势
- ✅ 易于版本控制

---

## 总结

### 当前存储方式

**位置**: `lib/core/services/i18n.dart`
**方式**: 硬编码嵌套 Map
**规模**: 503 行，400+ 翻译条目
**内存**: 约 16 KB

### 适用场景

✅ 小型项目（< 500 翻译）
✅ 快速开发
✅ 插件化架构
✅ 独立维护

### 改进建议

**短期**: 提取到单独文件
**中期**: 代码生成工具
**长期**: 外部文件 + 远程加载

### 不建议

❌ 当前项目不需要完整的外部化方案
❌ 不需要 ARB 文件（过于复杂）
❌ 不需要数据库存储（过度设计）

**当前方案已经足够好！** 👍

---

**相关文档**:
- [I18n 实现原理详解](./i18n_implementation_guide.md)
- [I18n 可视化指南](./i18n_visual_guide.md)
