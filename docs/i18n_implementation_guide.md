# I18n 插件实现原理详解

## 目录
1. [整体架构](#整体架构)
2. [核心组件](#核心组件)
3. [实现原理](#实现原理)
4. [使用方式](#使用方式)
5. [扩展机制](#扩展机制)
6. [最佳实践](#最佳实践)

---

## 整体架构

### 架构图

```
┌──────────────────────────────────────────────────────────────┐
│                        应用层                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  UI Widgets  │  │   Dialogs    │  │   Pages      │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │               │
│         └──────────────────┴──────────────────┘               │
│                            │                                  │
└────────────────────────────┼──────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────┐
│                      I18n 服务层                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │           I18n (ChangeNotifier)                       │  │
│  │  - t(String key)                                      │  │
│  │  - switchLanguage(String language)                    │  │
│  │  - currentLanguage                                     │  │
│  │  - _translations (Map<String, Map<String, String>>)   │  │
│  └───────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────┐
│                    插件系统层                                 │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              I18nPlugin                                │  │
│  │  - registerServices() → I18nServiceBinding            │  │
│  │  - registerHooks() → LanguageToggleHook               │  │
│  └───────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────┐
│                    依赖注入层                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │         ChangeNotifierProvider<I18n>                  │  │
│  │  提供全局单例 I18n 服务给整个应用树                    │  │
│  └───────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────┐
│                   持久化存储层                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              SharedPreferences                         │  │
│  │  Key: 'i18n_language'                                 │  │
│  │  Value: 'en' | 'zh'                                   │  │
│  └───────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### 设计模式

1. **单例模式 (Singleton)**
   - I18n 服务作为全局单例
   - 通过 Provider 注入到应用树

2. **观察者模式 (Observer)**
   - 继承 ChangeNotifier
   - 语言变化时通知所有监听者

3. **策略模式 (Strategy)**
   - 不同语言有不同的翻译策略
   - 可通过插件动态扩展

4. **外观模式 (Facade)**
   - I18nServiceBinding 统一管理服务创建和注册

---

## 核心组件

### 1. I18n 服务类

**文件位置**: `lib/core/services/i18n.dart`

```dart
class I18n extends ChangeNotifier {
  // 当前语言
  String _currentLanguage = 'en';

  // 翻译数据
  final Map<String, Map<String, String>> _translations = {
    'en': {},  // 英文（默认）
    'zh': {   // 中文
      'Settings': '设置',
      'Home': '主页',
      // ... 更多翻译
    },
  };

  // 翻译方法
  String t(String key) {
    final langMap = _translations[_currentLanguage];
    return langMap?[key] ?? key;  // 找不到翻译返回原文本
  }

  // 切换语言
  Future<void> switchLanguage(String language) async {
    _currentLanguage = language;
    notifyListeners();  // 通知所有监听者

    // 持久化
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('i18n_language', language);
  }
}
```

**关键特性**:
- ✅ 继承 `ChangeNotifier`，支持响应式更新
- ✅ 翻译数据嵌套 Map 结构
- ✅ 找不到翻译时优雅降级（返回原文本）
- ✅ 自动持久化语言选择

### 2. I18nPlugin 插件类

**文件位置**: `lib/plugins/i18n/i18n_plugin.dart`

```dart
class I18nPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'i18n',
    name: '国际化',
    version: '1.0.0',
    description: '提供多语言支持和界面汉化',
    enabledByDefault: true,  // 默认启用
  );

  @override
  List<ServiceBinding> registerServices() => [
    I18nServiceBinding()  // 注册 I18n 服务
  ];

  @override
  List<HookFactory> registerHooks() => [
    LanguageToggleHook.new  // 注册语言切换按钮
  ];
}
```

**关键特性**:
- ✅ 默认启用（国际化是基础功能）
- ✅ 注册服务和 UI Hook
- ✅ 无需额外依赖

### 3. I18nServiceBinding 服务绑定

**文件位置**: `lib/plugins/i18n/service/i18n_service_binding.dart`

```dart
class I18nServiceBinding extends ServiceBinding<I18n> {
  @override
  I18n createService(ServiceResolver resolver) {
    final i18n = I18n();

    // 异步初始化（不阻塞服务创建）
    i18n.initialize().catchError((error) {
      debugPrint('[I18n] Failed to initialize: $error');
    });

    return i18n;
  }

  @override
  bool get isSingleton => true;  // 单例服务

  @override
  bool get isLazy => false;  // 非懒加载（立即创建）

  @override
  SingleChildWidget createProvider(I18n instance) =>
    ChangeNotifierProvider<I18n>.value(value: instance);
}
```

**关键特性**:
- ✅ 单例模式（全局唯一）
- ✅ 非懒加载（应用启动时创建）
- ✅ 使用 `ChangeNotifierProvider`（因为 I18n 继承 ChangeNotifier）
- ✅ 异步初始化不阻塞服务创建

### 4. LanguageToggleHook UI Hook

**文件位置**: `lib/plugins/i18n/hooks/language_toggle_hook.dart`

```dart
class LanguageToggleHook extends MainToolbarHookBase {
  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    return Consumer<I18n>(
      builder: (ctx, i18n, child) {
        return IconButton(
          icon: const Icon(Icons.translate),
          tooltip: i18n.t('Language'),
          onPressed: () => _showLanguageDialog(ctx),
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final i18n = I18n.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.t('Select Language')),
        content: Column(
          children: [
            ListTile(
              title: const Text('English'),
              trailing: i18n.currentLanguage == 'en'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => _switchLanguage(ctx, i18n, 'en'),
            ),
            ListTile(
              title: const Text('简体中文'),
              trailing: i18n.currentLanguage == 'zh'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => _switchLanguage(ctx, i18n, 'zh'),
            ),
          ],
        ),
      ),
    );
  }
}
```

**关键特性**:
- ✅ 挂载到主工具栏
- ✅ 使用 `Consumer<I18n>` 监听语言变化
- ✅ 显示语言选择对话框
- ✅ 切换后实时更新 UI

---

## 实现原理

### 1. 服务注册流程

```
应用启动
    ↓
PluginManager 加载插件
    ↓
I18nPlugin.registerServices()
    ↓
I18nServiceBinding.createService()
    ↓
创建 I18n 实例
    ↓
I18nServiceBinding.createProvider()
    ↓
ChangeNotifierProvider<I18n>
    ↓
注入到应用 Provider 树
    ↓
I18n.initialize() (异步)
    ↓
从 SharedPreferences 加载语言
    ↓
应用就绪，可以翻译文本
```

### 2. 翻译流程

```dart
// 用户代码
final i18n = I18n.of(context);
Text(i18n.t('Settings'))

// 内部实现
String t(String key) {
  // 1. 获取当前语言的翻译表
  final langMap = _translations[_currentLanguage];

  // 2. 查找翻译
  if (langMap == null) return key;  // 语言不支持
  return langMap[key] ?? key;      // 翻译不存在，返回原文本
}
```

### 3. 语言切换流程

```dart
// 用户点击切换按钮
onTap: () => _switchLanguage(ctx, i18n, 'zh')

// 内部实现
Future<void> switchLanguage(String language) async {
  // 1. 更新当前语言
  _currentLanguage = language;

  // 2. 通知所有监听者
  notifyListeners();

  // 3. 持久化到 SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('i18n_language', language);
}
```

### 4. 响应式更新机制

```
语言切换
    ↓
I18n.switchLanguage('zh')
    ↓
notifyListeners() 调用
    ↓
Provider 检测到变化
    ↓
所有 Consumer<I18n> 重建
    ↓
所有 i18n.t() 重新执行
    ↓
UI 显示新语言文本
```

---

## 使用方式

### 方式 1: 在 Widget 中使用

```dart
class SettingsDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 1. 获取 I18n 实例
    final i18n = I18n.of(context);

    return AlertDialog(
      // 2. 使用翻译
      title: Text(i18n.t('Settings')),
      content: Column(
        children: [
          Text(i18n.t('Storage Settings')),
          Text(i18n.t('Theme Settings')),
        ],
      ),
    );
  }
}
```

### 方式 2: 使用 Consumer 监听变化

```dart
@override
Widget build(BuildContext context) {
  return Consumer<I18n>(
    builder: (ctx, i18n, child) {
      // 语言变化时自动重建
      return Text(i18n.t('Settings'));
    },
  );
}
```

### 方式 3: 使用 watch（Flutter 2.8+）

```dart
@override
Widget build(BuildContext context) {
  final i18n = context.watch<I18n>();  // 自动监听变化

  return Text(i18n.t('Settings'));
}
```

---

## 扩展机制

### 1. 添加新语言

```dart
// 在 I18n 类中添加新的翻译
final Map<String, Map<String, String>> _translations = {
  'en': {},
  'zh': {},
  'ja': {  // 添加日语
    'Settings': '設定',
    'Home': 'ホーム',
  },
};
```

### 2. 动态更新翻译

```dart
// 插件可以动态添加翻译
final i18n = I18n.of(context);

// 添加单个翻译
i18n.addTranslation('ja', 'Settings', '設定');

// 批量添加翻译
i18n.addTranslations('ja', {
  'Settings': '設定',
  'Home': 'ホーム',
});

// 更新整个翻译表
i18n.updateTranslations({
  'ja': {
    'Settings': '設定',
    'Home': 'ホーム',
  },
});
```

### 3. 创建语言包插件

```dart
class JapaneseLanguagePlugin extends Plugin {
  @override
  Future<void> onEnable() async {
    // 获取 I18n 服务
    final i18n = getService<I18n>();

    // 添加日语翻译
    i18n.addTranslations('ja', {
      'Settings': '設定',
      'Home': 'ホーム',
      // ... 更多翻译
    });
  }
}
```

---

## 最佳实践

### 1. 翻译键命名规范

```dart
// ✅ 好的做法：使用英文原文作为键
i18n.t('Settings')
i18n.t('Storage Location')
i18n.t('AI Configuration')

// ❌ 不好的做法：使用缩写或代码
i18n.t('settings')
i18n.t('storage_loc')
i18n.t('ai_config')
```

### 2. 翻译组织

```dart
// 按功能模块组织翻译
'zh': {
  // === 通用 ===
  'Settings': '设置',
  'Home': '主页',

  // === AI 相关 ===
  'AI Tools': 'AI 工具',
  'AI Assistant': 'AI 助手',

  // === 设置页面 ===
  'Storage Settings': '存储设置',
  'Theme Settings': '主题设置',
}
```

### 3. 缺失翻译处理

```dart
// I18n 已内置优雅降级
String t(String key) {
  final langMap = _translations[_currentLanguage];
  if (langMap == null) return key;  // 语言不支持
  return langMap[key] ?? key;      // 翻译不存在，返回原文本
}

// 使用示例
i18n.t('Some untranslated text')
// 英文: "Some untranslated text"
// 中文: "Some untranslated text" (返回原文)
```

### 4. 性能优化

```dart
// ✅ 好的做法：缓存 I18n 实例
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);  // 只获取一次

    return Column(
      children: [
        Text(i18n.t('Title')),
        Text(i18n.t('Content')),
        Text(i18n.t('Footer')),
      ],
    );
  }
}

// ❌ 不好的做法：多次获取
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(I18n.of(context).t('Title')),      // 重复获取
        Text(I18n.of(context).t('Content')),    // 重复获取
        Text(I18n.of(context).t('Footer')),     // 重复获取
      ],
    );
  }
}
```

### 5. 复杂文本处理

```dart
// ✅ 好的做法：参数化文本
// 定义
'Welcome {name}': '欢迎 {name}',
'Found {count} nodes': '找到 {count} 个节点',

// 使用
String t(String key, {Map<String, String>? params}) {
  var text = _translations[_currentLanguage]?[key] ?? key;

  if (params != null) {
    params.forEach((key, value) {
      text = text.replaceAll('{$key}', value);
    });
  }

  return text;
}

// 调用
i18n.t('Welcome {name}', params: {'name': 'Alice'});
i18n.t('Found {count} nodes', params: {'count': '100'});
```

---

## 技术亮点

### 1. 插件化架构

- ✅ I18n 作为插件实现
- ✅ 可动态加载/卸载
- ✅ 不影响核心代码

### 2. 响应式设计

- ✅ 继承 ChangeNotifier
- ✅ 语言切换自动更新 UI
- ✅ 无需手动刷新

### 3. 持久化存储

- ✅ SharedPreferences 保存语言选择
- ✅ 应用重启后自动恢复
- ✅ 异步初始化不阻塞启动

### 4. 优雅降级

- ✅ 找不到翻译返回原文本
- ✅ 语言不支持返回原文本
- ✅ 永不显示空白或错误

### 5. 扩展性强

- ✅ 支持动态添加语言
- ✅ 支持插件更新翻译
- ✅ 支持创建语言包插件

---

## 与传统方案对比

### Flutter Intl 方案

```yaml
# pubspec.yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any

dev_dependencies:
  flutter_localizations:
    sdk: flutter
  intl_translation: any
```

**优点**:
- ✅ 官方方案
- ✅ 支持复数、日期等
- ✅ 代码生成

**缺点**:
- ❌ 需要代码生成
- ❌ 配置复杂
- ❌ 难以动态扩展

### 本项目方案

**优点**:
- ✅ 无需代码生成
- ✅ 配置简单
- ✅ 易于扩展
- ✅ 插件化架构
- ✅ 动态更新翻译

**缺点**:
- ❌ 不支持复数、日期等高级特性
- ❌ 需要手动管理翻译键

---

## 实际应用示例

### 示例 1: 设置对话框

```dart
class SettingsDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.settings),
          const SizedBox(width: 8),
          Text(i18n.t('Settings')),  // "设置" or "Settings"
        ],
      ),
      content: Column(
        children: [
          // 存储设置
          _buildSectionHeader(i18n.t('Storage Settings')),
          ListTile(
            title: Text(i18n.t('Storage Location')),
            subtitle: Text(i18n.t('Default Location')),
          ),

          // 主题设置
          _buildSectionHeader(i18n.t('Theme Settings')),
          ListTile(
            title: Text(i18n.t('Color Theme')),
          ),
        ],
      ),
    );
  }
}
```

### 示例 2: 响应式语言切换

```dart
class LanguageSwitchButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<I18n>(
      builder: (ctx, i18n, child) {
        return IconButton(
          icon: const Icon(Icons.translate),
          tooltip: i18n.t('Language'),  // 自动更新
          onPressed: () => _showLanguageDialog(ctx),
        );
      },
    );
  }
}
```

---

## 总结

I18n 插件的实现是一个**简洁而优雅的国际化解决方案**：

### 核心特点

1. **插件化架构**: 作为插件实现，可独立开发和维护
2. **响应式设计**: 继承 ChangeNotifier，语言切换自动更新 UI
3. **持久化存储**: SharedPreferences 保存用户选择
4. **优雅降级**: 找不到翻译时返回原文本
5. **易于扩展**: 支持动态添加语言和翻译

### 技术栈

- **Flutter Provider**: 状态管理和依赖注入
- **SharedPreferences**: 持久化存储
- **插件系统**: 动态加载和扩展

### 适用场景

- ✅ 中小型应用的国际化需求
- ✅ 需要动态扩展翻译的场景
- ✅ 插件化架构的应用
- ✅ 不需要复杂特性的简单翻译

这个实现充分体现了 Flutter/Dart 在状态管理和插件化架构方面的优势！

---

**相关文档**:
- [插件开发指南](./plugin_development.md)
- [UI Hook 系统](./ui_hook_system.md)
- [服务绑定机制](../core/plugin/service_binding.dart)
