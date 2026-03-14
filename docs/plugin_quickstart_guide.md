# 插件开发快速入门指南

本文档提供了 Node Graph Notebook 插件开发的快速入门指南，帮助你快速上手插件开发。

## 前置条件

- Flutter SDK >= 3.16.0
- Dart SDK >= 3.2.0
- 熟悉 Dart 异步编程
- 了解 Node Graph Notebook 基本架构（阅读 `CLAUDE.md`）

## 第一步：了解插件类型

Node Graph Notebook 支持以下类型的插件：

### 1. 服务插件（ServicePlugin）

**用途**: 替换或扩展核心服务
**示例**:
- 自定义布局算法
- 新的 AI 提供商
- 自定义数据转换器

### 2. UI 插件（UIPlugin）

**用途**: 添加用户界面组件
**示例**:
- 侧边栏小工具
- 自定义菜单项
- 设置页面扩展

### 3. 数据插件（DataPlugin）

**用途**: 提供数据源或存储后端
**示例**:
- 云存储同步
- 数据库持久化
- 外部 API 集成

## 第二步：创建插件项目

### 方法 1: 使用插件模板（推荐）

```bash
# 1. 克隆插件模板
git clone https://github.com/your-repo/plugin_template.git my_plugin

# 2. 进入插件目录
cd my_plugin

# 3. 修改 pubspec.yaml
# 4. 编辑 plugin.yaml
# 5. 实现插件逻辑
```

### 方法 2: 手动创建

```bash
# 1. 创建项目目录
mkdir my_plugin && cd my_plugin

# 2. 初始化 Flutter 包
flutter create --template=package .

# 3. 创建插件元数据文件
touch lib/plugin.yaml

# 4. 创建插件入口文件
touch lib/my_plugin.dart
```

## 第三步：定义插件元数据

创建 `plugin.yaml` 文件：

```yaml
id: com.example.my_plugin
name: My Plugin
version: 1.0.0
description: A brief description of what this plugin does
author: Your Name <email@example.com>

# 插件类型（可多选）
types:
  - service    # 服务插件
  - ui         # UI 插件
  - data       # 数据插件
  - converter  # 转换器插件
  - aiProvider # AI 提供商插件

# 依赖的其他插件（可选）
dependencies:
  - pluginId: com.example.other_plugin
    version: ">=1.0.0"
    required: true

# 需要的核心服务（可选）
requiredServices:
  - NodeService
  - GraphService

# 提供的服务（可选）
providedServices:
  - MyCustomService

# 提供的 UI 扩展（仅 UI 插件）
uiExtensions:
  - point: homeSidebarTop      # 扩展点位置
    priority: 100              # 优先级（越大越靠前）
  - point: nodeContextMenu
    priority: 50

# 兼容的核心版本
coreVersion: ">=2.0.0"

# 插件配置 Schema（可选）
configSchema:
  type: object
  properties:
    apiKey:
      type: string
      title: API Key
    enabled:
      type: boolean
      title: Enable Plugin
      default: true
```

## 第四步：实现插件

### 示例 1: 简单的 UI 插件

```dart
// lib/my_plugin.dart
import 'package:flutter/material.dart';
import 'package:node_graph_notebook/plugins/plugins.dart';

class MyPlugin extends UIPlugin {
  @override
  PluginDescriptor get descriptor => PluginDescriptor(
    id: 'com.example.my_plugin',
    name: 'My Plugin',
    version: '1.0.0',
    description: 'A simple UI plugin',
    author: 'Your Name',
    types: [PluginType.ui],
    dependencies: [],
    requiredServices: {},
    providedServices: {},
    uiExtensions: [
      UIExtensionPoint(
        point: ExtensionPoint.homeSidebarTop,
        widget: _MyWidget.builder,
        priority: 100,
      ),
    ],
    dataProviders: [],
    entrypoint: MyPlugin.new,
    coreVersion: Version.parse('2.0.0'),
  );

  late PluginContext _context;

  @override
  Future<void> initialize(PluginContext context) async {
    _context = context;
    debugPrint('MyPlugin initialized!');
  }

  @override
  List<UIExtension> get extensions => [
    MenuItemExtension(
      point: ExtensionPoint.toolbar,
      label: 'My Action',
      icon: 'star',
      onPressed: () => _handleAction(),
      priority: 100,
    ),
  ];

  void _handleAction() {
    debugPrint('Action triggered!');
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<dynamic> handleHook(String hookName, Map<String, dynamic> params) async {}
}

// 自定义 Widget
class _MyWidget extends StatelessWidget {
  const _MyWidget({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const _MyWidget();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.star),
        title: const Text('My Plugin'),
        subtitle: const Text('Hello from plugin!'),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plugin clicked!')),
          );
        },
      ),
    );
  }
}
```

### 示例 2: 服务插件

```dart
// lib/my_service_plugin.dart
import 'package:node_graph_notebook/plugins/plugins.dart';
import 'package:node_graph_notebook/core/services/node_service.dart';

class MyServicePlugin extends ServicePlugin {
  @override
  PluginDescriptor get descriptor => PluginDescriptor(
    id: 'com.example.my_service',
    name: 'My Service Plugin',
    version: '1.0.0',
    description: 'Provides custom service',
    author: 'Your Name',
    types: [PluginType.service],
    dependencies: [],
    requiredServices: {'NodeService'},
    providedServices: {'MyCustomService'},
    uiExtensions: [],
    dataProviders: [],
    entrypoint: MyServicePlugin.new,
    coreVersion: Version.parse('2.0.0'),
  );

  late PluginContext _context;
  late MyCustomService _service;

  @override
  Future<void> initialize(PluginContext context) async {
    _context = context;

    // 获取依赖的服务
    final nodeService = context.getService<NodeService>();

    // 创建并注册自定义服务
    _service = MyCustomService(nodeService);
  }

  @override
  Map<Type, dynamic> get services => {
    MyCustomService: _service,
  };

  @override
  int get priority => 100; // 高优先级，可以替换默认实现

  @override
  Future<void> start() async {
    await _service.initialize();
  }

  @override
  Future<void> stop() async {
    await _service.dispose();
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<dynamic> handleHook(String hookName, Map<String, dynamic> params) async {
    switch (hookName) {
      case 'customAction':
        return _service.doSomething();
      default:
        throw UnimplementedError('Unknown hook: $hookName');
    }
  }
}

// 自定义服务实现
class MyCustomService {
  final NodeService _nodeService;

  MyCustomService(this._nodeService);

  Future<void> initialize() async {
    // 初始化逻辑
  }

  Future<void> doSomething() async {
    // 自定义逻辑
    final nodes = await _nodeService.getAllNodes();
    // 处理节点...
  }

  Future<void> dispose() async {
    // 清理资源
  }
}
```

## 第五步：测试插件

### 创建测试文件

```dart
// test/my_plugin_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/plugins/plugins.dart';
import 'package:my_plugin/my_plugin.dart';

void main() {
  group('MyPlugin', () {
    late MyPlugin plugin;

    setUp(() {
      plugin = MyPlugin();
    });

    test('should have valid descriptor', () {
      expect(plugin.descriptor.id, isNotEmpty);
      expect(plugin.descriptor.version, isNotEmpty);
    });

    test('should initialize successfully', () async {
      final mockContext = _createMockContext();
      await plugin.initialize(mockContext);
      expect(plugin, isNotNull);
    });

    // 更多测试...
  });
}

PluginContext _createMockContext() {
  // 创建 Mock 上下文
  // TODO: 实现 Mock
  throw UnimplementedError();
}
```

### 运行测试

```bash
flutter test
```

## 第六步：本地测试插件

### 方法 1: 符号链接（开发时推荐）

```bash
# 1. 在应用的 plugins 目录创建符号链接
cd path/to/node_graph_notebook/plugins/local
ln -s path/to/my_plugin .

# 2. 重启应用，插件会自动加载
```

### 方法 2: 复制到插件目录

```bash
# 1. 复制插件到应用的 plugins 目录
cp -r path/to/my_plugin path/to/node_graph_notebook/plugins/local/

# 2. 重启应用
```

### 方法 3: 使用应用内的插件管理页面

1. 启动应用
2. 进入设置 → 插件管理
3. 点击"安装本地插件"
4. 选择插件目录

## 第七步：调试插件

### 启用插件调试日志

在应用设置中启用"插件调试模式"，查看详细的插件加载日志。

### 常见问题排查

#### 问题：插件无法加载

**可能原因**:
1. `plugin.yaml` 格式错误
2. 插件依赖未满足
3. 核心版本不兼容

**解决方法**:
```dart
// 检查插件描述符
void debugPluginDescriptor(PluginDescriptor descriptor) {
  debugPrint('Plugin ID: ${descriptor.id}');
  debugPrint('Version: ${descriptor.version}');
  debugPrint('Core Version: ${descriptor.coreVersion}');
  debugPrint('Dependencies: ${descriptor.dependencies}');
  debugPrint('Required Services: ${descriptor.requiredServices}');
}
```

#### 问题：服务注入失败

**可能原因**:
1. 服务未注册
2. 服务类型不匹配

**解决方法**:
```dart
// 安全地获取服务
try {
  final service = context.getService<NodeService>();
  // 使用服务...
} catch (e) {
  debugPrint('Failed to get NodeService: $e');
}
```

## 第八步：发布插件

### 准备发布清单

- [ ] 代码已通过所有测试
- [ ] 文档完整（README、API 文档）
- [ ] `pubspec.yaml` 包含所有元数据
- [ ] `plugin.yaml` 格式正确
- [ ] 添加了示例和截图
- [ ] 许可证文件

### 发布到插件仓库

```bash
# 1. 提交到 GitHub
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# 2. 提交到官方插件仓库（如果有）
# 按照仓库指南提交 PR
```

## 扩展点参考

### 可用的 UI 扩展点

| 扩展点 | 说明 | Widget 类型 |
|--------|------|-------------|
| `homeSidebarTop` | 主页侧边栏顶部 | `Widget` |
| `homeSidebarBottom` | 主页侧边栏底部 | `Widget` |
| `nodeContextMenu` | 节点右键菜单 | `MenuItem` |
| `graphContextMenu` | 图形右键菜单 | `MenuItem` |
| `toolbar` | 主工具栏 | `IconButton` 或 `TextButton` |
| `settings` | 设置页面 | `Widget` |
| `exportMenu` | 导出菜单 | `MenuItem` |
| `importMenu` | 导入菜单 | `MenuItem` |
| `aiMenu` | AI 菜单 | `MenuItem` |

### 可用的服务

| 服务 | 用途 | 主要方法 |
|------|------|----------|
| `NodeService` | 节点 CRUD | `createNode`, `updateNode`, `deleteNode`, `getNode` |
| `GraphService` | 图形管理 | `createGraph`, `addNodeToGraph`, `removeNodeFromGraph` |
| `LayoutService` | 布局算法 | `applyLayout`, `calculateLayout` |
| `ConverterService` | 格式转换 | `convertTo`, `convertFrom` |
| `ImportExportService` | 导入导出 | `importData`, `exportData` |
| `AIService` | AI 功能 | `generateContent`, `analyzeNodes` |
| `SettingsService` | 应用设置 | `get`, `set`, `watch` |
| `ThemeService` | 主题管理 | `registerTheme`, `getTheme` |

### 可用的钩子（Hooks）

| 钩子名 | 触发时机 | 参数 | 返回值 |
|--------|----------|------|--------|
| `node.created` | 节点创建后 | `{'node': Node}` | `void` |
| `node.updated` | 节点更新后 | `{'node': Node, 'oldNode': Node}` | `void` |
| `node.deleted` | 节点删除前 | `{'nodeId': String}` | `bool` (返回 false 取消删除) |
| `graph.loaded` | 图形加载后 | `{'graph': Graph}` | `void` |
| `export.start` | 导出开始前 | `{'format': String, 'nodes': List<Node>}` | `bool` (返回 false 取消导出) |
| `import.complete` | 导入完成后 | `{'nodes': List<Node>}` | `void` |

## 进阶主题

### 1. 插件间通信

```dart
// 方法 1: 通过事件总线（推荐）
void sendMessage() {
  _context.publishEvent(MyCustomEvent(data: 'hello'));
}

// 方法 2: 直接访问其他插件
void callOtherPlugin() {
  final otherPlugin = _context.getPlugin('com.example.other_plugin');
  if (otherPlugin != null) {
    otherPlugin.handleHook('doSomething', {'param': 'value'});
  }
}
```

### 2. 插件配置

```dart
// 读取配置
final config = await _context.getConfig();
final apiKey = config['apiKey'];

// 更新配置
await _context.updateConfig({'apiKey': 'new_key'});
```

### 3. 插件国际化

```dart
// 访问国际化资源
final localizations = _context.resources.localizations;
final title = localizations.myPluginTitle;

// 或者提供自己的国际化文件
// lib/l10n/my_plugin_en.arb
// lib/l10n/my_plugin_zh.arb
```

### 4. 异步初始化

```dart
@override
Future<void> initialize(PluginContext context) async {
  _context = context;

  // 执行异步初始化
  await _loadConfiguration();
  await _connectToExternalService();
  await _registerExtensions();
}
```

## 最佳实践

### ✅ DO（推荐做法）

1. **明确声明依赖**: 在 `plugin.yaml` 中声明所有依赖
2. **错误处理**: 所有异步操作都应包含错误处理
3. **资源清理**: 在 `dispose()` 中释放所有资源
4. **日志记录**: 使用 `debugPrint` 记录重要操作
5. **版本控制**: 遵循语义化版本规范
6. **文档**: 为公共 API 提供完整的文档注释

### ❌ DON'T（不推荐做法）

1. **阻塞主线程**: 避免在插件中进行同步 I/O 操作
2. **直接修改核心数据**: 通过服务接口修改数据
3. **硬编码路径**: 使用插件上下文获取应用路径
4. **假设服务可用**: 始终检查服务是否存在
5. **忽略版本兼容**: 明确声明兼容的核心版本

## 资源链接

- [完整架构文档](./plugin_architecture_proposal.md)
- [API 参考手册](./plugin_api_reference.md)（待创建）
- [示例插件仓库](https://github.com/your-repo/example-plugins)
- [插件开发论坛](https://github.com/your-repo/discussions)

## 获取帮助

- 💬 **GitHub Discussions**: [提问和讨论](https://github.com/your-repo/discussions)
- 🐛 **Bug 报告**: [提交 Issue](https://github.com/your-repo/issues)
- 📧 **邮件**: support@example.com

---

祝你开发愉快！🎉
